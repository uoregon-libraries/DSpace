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
import java.util.TreeMap;
import org.dspace.core.ConfigurationManager;
import org.dspace.core.Context;
import org.dspace.storage.rdbms.DatabaseManager;
import org.dspace.storage.rdbms.TableRow;
import org.dspace.storage.rdbms.TableRowIterator;

/**
 * AccountCreateLookup guesses at creation dates for accounts.  Reads the
 * current external list, and sets any users not in that list to have been
 * created today.  It is assumed that the file will be updated regularly,
 * otherwise this class has little relevance.
 */
public class AccountCreateLookup {
    private static final DateFormat dateFormat = DateFormat.getDateInstance(DateFormat.SHORT);
    private static final Date now = new Date();
    private static TreeMap<Integer,Date> idToCreateDate = new TreeMap<Integer,Date>();

    /**
     * Returns the TSV file of create dates defined in eperson.creatmap.filename
     */
    public static String TSVFile() throws IllegalStateException {
        String property = "eperson.createmap.filename";
        String filename = ConfigurationManager.getProperty(property);
        if (filename == null) {
            throw new IllegalStateException("Missing required configuration property '" + property + "'");
        }
        return filename;
    }

    /**
     * Returns a map of ids to account creation dates.  Uses the TSV file to
     * read in a map of ids to their create dates, and assumes all users in the
     * database that didn't have an entry in the file were created today.
     */
    public static TreeMap<Integer,Date> getCreateDates() throws IOException, SQLException {
        if (idToCreateDate.size() == 0) {
            readCreateDates();
        }
        return idToCreateDate;
    }

    private static void readCreateDates() throws IOException, SQLException {
        BufferedReader r = null;
        String filename = TSVFile();
        r = Files.newBufferedReader(Paths.get(filename), StandardCharsets.UTF_8);
        readCreateDatesFromTSV(filename, r);
        readCreateDatesFromDatabase();
    }

    // Populates the idToCreateDate lookup for all users in the database who
    // don't already have a date
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

            // Store today's date in the lookup
            idToCreateDate.put(key, now);
        }
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

    /**
     * Gets the person's last activity date or create date, adding a 3 month
     * buffer to whichever date is used.  Create date can be the only usable
     * date in cases where the account is being used via the registration
     * token, which allows account access without requiring a user to actually
     * log in.  The three-month buffer is necessary because the account's "last
     * active" date is really just when a user last logged in, and the create
     * date is just when we discovered an account having been created.  Either
     * token allows a user access for the lifetime of the server, so we
     * arbitrarily chose a window that should be long enough to ensure a server
     * reboot happened or a user was otherwise likely to have needed to log in
     * from a different browser/ip/computer.
     */
    public static Date lastActiveDate(EPerson ep) throws SQLException, IOException {
        getCreateDates();

        Date dt = ep.getLastActive();
        if (dt == null) {
            dt = idToCreateDate.get(ep.getID());
        }

        if (dt == null) {
            dt = new Date();
        }

        Calendar c = Calendar.getInstance();
        c.setTime(dt);
        c.add(Calendar.MONTH, 3);
        return c.getTime();
    }
}
