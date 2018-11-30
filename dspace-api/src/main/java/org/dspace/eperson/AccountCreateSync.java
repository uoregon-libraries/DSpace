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
import org.dspace.core.Context;
import org.dspace.storage.rdbms.DatabaseManager;
import org.dspace.storage.rdbms.TableRow;
import org.dspace.storage.rdbms.TableRowIterator;

/**
 * Updates the external list of account creation dates.  The list, defined in
 * eperson.createmap.filename, is read via AccountCreateLookup data, merged
 * with database accounts not yet in the list (with a create date of today),
 * and written back out.  If this script is run regularly, the approximate user
 * creation dates can be useful for mass user purge operations.
 */
public class AccountCreateSync {
    private static final DateFormat dateFormat = DateFormat.getDateInstance(DateFormat.SHORT);
    private static final Date now = new Date();
    private static TreeMap<Integer,Date> idToCreateDate = new TreeMap<Integer,Date>();

    static public void main(String[] argv) throws IOException, SQLException {
        recalculateCreateDates();
    }

    // Reads all accounts with no externally stored creation date, and stores
    // today's date.  This isn't going to be valid, especially for accounts
    // created before running this, but it should be close enough for anything
    // new after the first run so long as this is run regularly.
    private static void recalculateCreateDates() throws IOException, SQLException {
        idToCreateDate = AccountCreateLookup.getCreateDates();
        writeCreateDateTSV(AccountCreateLookup.TSVFile());
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
            BufferedWriter w = Files.newBufferedWriter(tempFile, StandardCharsets.UTF_8);
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
}
