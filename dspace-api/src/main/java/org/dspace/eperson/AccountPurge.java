package org.dspace.eperson;

import java.io.IOException;
import java.sql.SQLException;
import java.text.DateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.TreeMap;
import org.apache.commons.cli.*;
import org.apache.commons.lang.StringUtils;
import org.dspace.authorize.AuthorizeException;
import org.dspace.core.ConfigurationManager;
import org.dspace.core.Context;
import org.dspace.storage.rdbms.DatabaseManager;
import org.dspace.storage.rdbms.TableRow;
import org.dspace.storage.rdbms.TableRowIterator;

/**
 * Tool for purging users with no recent activity
 */
public class AccountPurge {
    private static final DateFormat dateFormat = DateFormat.getDateInstance(DateFormat.SHORT);
    private static final Date now = new Date();
    private static TreeMap<Integer,Date> idToCreateDate;
    private static HashMap<Integer,Long> idToGroupCount;
    private static boolean dryrun = false;

    static public void main(String[] argv) throws IOException, SQLException {
        CommandLine command = parseCLI(argv);
        Date lastActivityThreshold = null;
        try {
            lastActivityThreshold = dateFormat.parse(command.getOptionValue('u'));
        } catch (java.text.ParseException ex) {
            System.err.println(ex.getMessage());
            System.exit(1);
        }

        readUserGroupCountMap();
        dryrun = command.hasOption('n');
        idToCreateDate = AccountCreateLookup.getCreateDates();
        purgeUsersBefore(lastActivityThreshold);
    }

    private static void purgeUsersBefore(Date dt) throws SQLException, IOException {
        if (dt == null) {
            System.err.println("ERROR - purge date is null!");
            return;
        }

        System.err.println("DEBUG - purging accounts last active prior to " + dt);

        Calendar c = Calendar.getInstance();
        c.setTime(dt);
        c.add(Calendar.MONTH, 3);
        if (c.getTime().after(now)) {
            System.err.println("ERROR - Refusing to disable accounts with activity in the past 3 months");
            return;
        }

        Context ctx = new Context();
        String sql = "SELECT eperson_id FROM EPerson";
        final TableRowIterator tri = DatabaseManager.queryTable(ctx, "EPerson", sql);

        ctx.turnOffAuthorisationSystem();
        while (tri.hasNext()) {
            TableRow row = tri.next();
            if (null == row) {
                break;
            }

            EPerson ep = EPerson.find(ctx, row.getIntColumn("eperson_id"));
            if (AccountCreateLookup.lastActiveDate(ep).before(dt)) {
                purge(ep, ctx);
            }
        }

        ctx.restoreAuthSystemState();
        ctx.complete();
    }

    private static void purge(EPerson ep, Context ctx) throws SQLException {
        // This determines if any uber-important things refer to the person
        List<String> dc = ep.getDeleteConstraints();

        // And this takes it a step further to avoid deleting people who are
        // part of any group, as we may want to examine these users manually
        Long groupCount = idToGroupCount.get(ep.getID());
        if (groupCount != null && groupCount > 0) {
            dc.add("epersongroup2eperson");
        }

        if (dc.size() == 0) {
            if (dryrun) {
                System.err.println("DEBUG - [DRY RUN] Deleting " + ep.getEmail());
                return;
            }

            System.err.println("DEBUG - Deleting " + ep.getEmail());
            try {
                ep.delete();
            }
            catch (SQLException | AuthorizeException | EPersonDeletionException e) {
                System.err.println("ERROR - Cannot delete " + ep.getEmail() + " - " + e.getMessage());
            }
            return;
        }

        System.err.println("DEBUG - Not deleting " + ep.getEmail() +
            " (constraints: " + StringUtils.join(dc, ", ") + ")");
        if (dryrun) {
            System.err.println("DEBUG - [DRY RUN] Disabling login for " + ep.getEmail());
            return;
        }

        System.err.println("DEBUG - Disabling login for " + ep.getEmail());
        try {
            ep.setCanLogIn(false);
            ep.update();
        } catch (SQLException | AuthorizeException e) {
            System.err.println("ERROR - " + e.getMessage());
        }
    }

    private static void readUserGroupCountMap() throws SQLException {
        if (idToGroupCount != null && idToGroupCount.size() > 0) {
            return;
        }

        Context ctx = new Context();
        idToGroupCount = new HashMap<Integer,Long>();
        String sql = "SELECT COUNT(*) AS group_count, eperson_id FROM epersongroup2eperson GROUP BY eperson_id";
        final TableRowIterator tri = DatabaseManager.query(ctx, sql);

        ctx.turnOffAuthorisationSystem();
        while (tri.hasNext()) {
            TableRow row = tri.next();
            if (null == row) {
                break;
            }

            // use getIntColumn for Oracle count data
            if (DatabaseManager.isOracle()) {
                idToGroupCount.put(row.getIntColumn("eperson_id"), new Long(row.getIntColumn("group_count")));
            }
            // getLongColumn works for postgres
            else {
                idToGroupCount.put(row.getIntColumn("eperson_id"), row.getLongColumn("group_count"));
            }
        }

        ctx.restoreAuthSystemState();
        ctx.complete();
    }

    private static CommandLine parseCLI(String argv[]) {
        Options options = new Options();
        options.addOption("h", "help", false, "help");
        options.addOption("u", "used-before", true, "date of last use was before this (e.g., " +
            dateFormat.format(now) + ')');
        options.addOption("n", "dry-run", false, "don't make any actual database changes");

        CommandLine line = null;
        try {
            line = new PosixParser().parse(options, argv);
        }
        catch(ParseException e) {
            System.err.println("Command error: " + e.getMessage());
            new HelpFormatter().printHelp(AccountPurge.class.getName(), options);
            System.exit(1);
        }

        if (line.hasOption('h')) {
            new HelpFormatter().printHelp(AccountPurge.class.getName(), options);
            System.exit(0);
        }

        if (!line.hasOption('u')) {
            System.err.println("You must specify a date for -u");
            new HelpFormatter().printHelp(AccountPurge.class.getName(), options);
            System.exit(1);
        }

        return line;
    }
}
