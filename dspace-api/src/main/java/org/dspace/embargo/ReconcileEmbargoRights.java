package org.dspace.embargo;

import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Formatter;
import java.util.Locale;
import java.util.TimeZone;

import org.dspace.content.Item;
import org.dspace.content.Collection;
import org.dspace.content.ItemIterator;
import org.dspace.core.ConfigurationManager;
import org.dspace.core.Context;

/**
 * Command-line service to identify and fix items where the
 * dc.description.embargo field doesn't match the actual access restrictions
 */
public class ReconcileEmbargoRights {
   // Context is needed in too many places to not globalize it
    private static Context context = null;
    private static String baseURL;

    public static void main(String argv[]) throws Exception {
        EmbargoChecker.initTerms();
        getConfig();

        try {
            context = new Context();
        }
        catch (SQLException e) {
            System.err.println("Error getting DSpace context: " + e);
            throw e;
        }
        context.setIgnoreAuthorization(true);

        findOutOfSyncItems();

        try {
            context.complete();
        }
        catch (SQLException e) {
            System.err.println("Error completing DSpace context: " + e);
            throw e;
        }
    }

    private static void findOutOfSyncItems() throws SQLException {
        ItemIterator ii;

        try {
            ii = Item.findAll(context);
        }
        catch (Exception e) {
            System.err.println("ERROR trying to collect all DSpace items: " + e);
            return;
        }

        while (ii.hasNext()) {
            Item i;
            try {
                i = ii.next();
            }
            catch (Exception e) {
                System.err.println("ERROR trying to get next DSpace item: " + e);
                throw e;
            }
            EmbargoChecker ec = new EmbargoChecker(context, i);
            Date metadataEmbargoDate = ec.getEmbargoDate();
            Date publicAccessDate;

            try {
                publicAccessDate = ec.getItemAccessDate();
            }
            catch (Exception e) {
                System.err.printf("ERROR: Item %s has out-of-sync public access dates: %s\n", i.getHandle(), e);
                continue;
            }

            if (!ec.datesClose(metadataEmbargoDate, publicAccessDate)) {
                // If the metadata field is empty, we just update it
                if (metadataEmbargoDate == null) {
                    SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-dd");
                    df.setTimeZone(TimeZone.getTimeZone("UTC"));
                    String dtString = df.format(publicAccessDate);

                    i.clearMetadata(ec.termsSchema, ec.termsElement, ec.termsQualifier, Item.ANY);
                    i.addMetadata(ec.termsSchema, ec.termsElement, ec.termsQualifier, "", dtString);
                    try {
                        i.update();
                        System.out.printf("Item %s had null metadata embargo; " +
                            "it has been updated to %s to match the public " +
                            "access date\n", i.getHandle(), dtString);
                    }
                    catch (Exception e) {
                        System.err.printf("ERROR: Item %s won't update: %s\n", i.getHandle(), e);
                        continue;
                    }
                }
                else {
                    System.out.printf("WARN: Item %s has metadata embargo of %s but public access of %s\n",
                        i.getHandle(), metadataEmbargoDate, publicAccessDate);
                }
            }
        }
    }

    // Get configuration for URL generation
    public static void getConfig() throws IllegalStateException {
        String prop = "dspace.url";
        baseURL = ConfigurationManager.getProperty(prop);
        if (baseURL == null) {
            throw new IllegalStateException("Missing required configuration property '" + prop + "'.");
        }
    }
}
