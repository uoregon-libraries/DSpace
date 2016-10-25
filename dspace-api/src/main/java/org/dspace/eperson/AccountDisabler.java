package org.dspace.eperson;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.charset.StandardCharsets;
import java.sql.SQLException;
import java.text.DateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Map;
import java.util.TreeMap;
import org.apache.commons.cli.*;
import org.apache.commons.io.FileUtils;
import org.dspace.authorize.AuthorizeException;
import org.dspace.core.ConfigurationManager;
import org.dspace.core.Context;
import org.dspace.storage.rdbms.DatabaseManager;
import org.dspace.storage.rdbms.TableRow;
import org.dspace.storage.rdbms.TableRowIterator;

/**
 * Tool for handling users without recent activity as well as users who have no
 * activity on record, but need to be deleted / deactivated only after a
 * certain time has passed since account creation.
 */
public class AccountDisabler {
    private static final DateFormat dateFormat = DateFormat.getDateInstance(DateFormat.SHORT);
    private static final Date now = new Date();
    private static TreeMap<Integer,Date> idToCreateDate = new TreeMap<Integer,Date>();

    static public void main(String[] argv) throws IOException, SQLException {
        CommandLine command = parseCLI(argv);
        Date lastActivityThreshold = null;
        if (command.hasOption('u')) {
            try {
                lastActivityThreshold = dateFormat.parse(command.getOptionValue('u'));
            } catch (java.text.ParseException ex) {
                System.err.println(ex.getMessage());
                System.exit(1);
            }
        }

        Date createThreshold = null;
        if (command.hasOption('c')) {
            try {
                createThreshold = dateFormat.parse(command.getOptionValue('c'));
            } catch (java.text.ParseException ex) {
                System.err.println(ex.getMessage());
                System.exit(1);
            }
        }

        recalculateCreateDates();
        disableAccountsActiveBefore(lastActivityThreshold, command.hasOption('n'));
        disableAccountsCreatedBefore(createThreshold, command.hasOption('n'));
    }

    // Reads all accounts with no externally stored creation date, and stores
    // last activity if not null, or today's date.  This isn't going to be
    // completely valid, especially for a first run against older accounts, but
    // at least we'll have something to go by that's at least more accurate
    // than "no idea".
    private static void recalculateCreateDates() throws IOException, SQLException {
        String property = "eperson.createmap.filename";
        String filename = ConfigurationManager.getProperty(property);
        if (filename == null) {
            System.err.println("Missing required configuration property '" + property + "'; exiting");
            System.exit(1);
        }

        BufferedReader r = null;
        try {
            r = Files.newBufferedReader(Paths.get(filename), StandardCharsets.UTF_8);
        }
        catch (java.nio.file.NoSuchFileException e) {
            System.err.println("INFO - createmap file doesn't exist; generating a new one");
        }

        if (r != null) {
            readCreateDatesFromTSV(filename, r);
        }
        readCreateDatesFromDatabase();
        writeCreateDateTSV(filename);
    }

    private static void readCreateDatesFromTSV(String filename, BufferedReader r) throws IOException {
        int lineNo = 0;
        String line;
        while ((line = r.readLine()) != null) {
            lineNo++;
            String[] parts = line.split("\\t", -1);
            if (parts.length != 2) {
                System.err.println("ERROR - Wrong number of TSV elements in '" + filename + "'");
                System.err.println("ERROR -     line number " + lineNo);
                System.err.println("ERROR -     raw text: '" + line + "'");
                System.exit(1);
            }

            Integer id;
            Date dt;
            try {
                id = Integer.valueOf(parts[0]);
                dt = dateFormat.parse(parts[1]);
                idToCreateDate.put(id, dt);
            }
            catch (Exception e) {
                System.err.println("ERROR - Invalid TSV data in '" + filename + "'");
                System.err.println("ERROR -     line number " + lineNo);
                System.err.println("ERROR -     raw text: '" + line + "'");
                System.err.println("ERROR -     exception: " + e);
                System.exit(1);
            }
        }
    }

    // Populates the idToCreateDate lookup from all users in the database,
    // based on their last activity date
    private static void readCreateDatesFromDatabase() throws SQLException {
        Context ctx = new Context();
        String sql = "SELECT eperson_id FROM EPerson";
        final TableRowIterator tri = DatabaseManager.queryTable(ctx, "EPerson", sql);
        while (tri.hasNext()) {
            TableRow row = tri.next();
            if (null == row) {
                return;
            }

            // If there's already a create date in the lookup, skip this record
            int id = row.getIntColumn("eperson_id");
            Integer key = new Integer(id);
            Date createDate = idToCreateDate.get(key);
            if (createDate != null) {
                continue;
            }

            // Figure out a fake create date by using either the user's last
            // activity data or else today's date
            EPerson ep = EPerson.find(ctx, id);
            createDate = ep.getLastActive();
            if (createDate == null) {
                createDate = new Date();
            }

            idToCreateDate.put(key, createDate);
        }
    }

    // Writes out the data in the idToCreateDate map
    private static void writeCreateDateTSV(String filename) {
        Path tempFile = null;
        try {
            tempFile = Files.createTempFile(null, null);
        }
        catch (IOException e) {
            System.err.println("ERROR - unable to create temp file: " + e);
            System.exit(1);
        }

        try {
            BufferedWriter w = Files.newBufferedWriter(tempFile);
            for (Map.Entry<Integer,Date> entry : idToCreateDate.entrySet()) {
                w.write(entry.getKey() + "\t" + dateFormat.format(entry.getValue()) + "\n");
            }
            w.close();
        }
        catch (IOException e) {
            System.err.println("ERROR - unable to write to temp file: " + e);
            System.exit(1);
        }

        File outFile = new File(filename);

        try {
            FileUtils.deleteQuietly(outFile);
            FileUtils.moveFile(tempFile.toFile(), outFile);
        }
        catch (IOException e) {
            System.err.println("ERROR - unable to move temp file to \"" + filename + "\": " + e);
            System.exit(1);
        }
    }

    // Traverses all accounts with activity before the given date and sets them
    // to not be allowed a login
    private static void disableAccountsActiveBefore(Date dt, boolean dryrun) throws SQLException {
        if (dt == null) {
            System.err.println("DEBUG - not disabling based on activity date");
            return;
        }

        System.err.println("DEBUG - disabling accounts last active prior to " + dt);

        Calendar c = Calendar.getInstance();
        c.setTime(dt);
        c.add(Calendar.MONTH, 3);
        if (c.getTime().after(now)) {
            System.err.println("ERROR - Refusing to disable accounts with activity in the past 3 months");
            return;
        }

        Context ctx = new Context();
        String sql = "SELECT eperson_id FROM EPerson WHERE last_active < ?";
        java.sql.Date sqlDate = new java.sql.Date(dt.getTime());
        System.err.println("DEBUG - Finding people via '" + sql + "' (" + sqlDate + ")");
        final TableRowIterator tri = DatabaseManager.queryTable(ctx, "EPerson", sql, sqlDate);

        ctx.turnOffAuthorisationSystem();
        while (tri.hasNext()) {
            TableRow row = tri.next();
            if (null == row) {
                break;
            }

            EPerson ep = EPerson.find(ctx, row.getIntColumn("eperson_id"));
            ep.setCanLogIn(false);
            try {
                if (dryrun) {
                    System.err.println("DEBUG - [DRY RUN] Disabling login for " + ep.getEmail());
                }
                else {
                    System.err.println("DEBUG - Disabling login for " + ep.getEmail());
                    ep.update();
                }
            } catch (SQLException | AuthorizeException e) {
                System.err.println(e.getMessage());
            }
        }

        ctx.restoreAuthSystemState();
        ctx.complete();
    }

    // Reads all external create dates and disables accounts created prior to dt
    private static void disableAccountsCreatedBefore(Date dt, boolean dryrun) throws SQLException {
        // TODO: Implement me!
    }

    private static CommandLine parseCLI(String argv[]) {
        Options options = new Options();
        options.addOption("h", "help", false, "help");
        options.addOption("u", "used-before", true, "date of last login was before this (e.g., " +
            dateFormat.format(now) + ')');
        options.addOption("c", "created-before", true, "creation date was before this");
        options.addOption("n", "dry-run", false, "don't make any actual database changes");

        CommandLine line = null;
        try {
            line = new PosixParser().parse(options, argv);
        }
        catch(ParseException e) {
            System.err.println("Command error: " + e.getMessage());
            new HelpFormatter().printHelp(AccountDisabler.class.getName(), options);
            System.exit(1);
        }

        if (line.hasOption('h')) {
            new HelpFormatter().printHelp(AccountDisabler.class.getName(), options);
            System.exit(0);
        }

        if (!line.hasOption('u') && !line.hasOption('c')) {
            System.err.println("You must specify one or both of -u or -c dates");
            new HelpFormatter().printHelp(AccountDisabler.class.getName(), options);
            System.exit(1);
        }

        return line;
    }
}
