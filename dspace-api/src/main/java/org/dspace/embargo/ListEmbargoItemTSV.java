package org.dspace.embargo;

import java.sql.SQLException;
import java.util.Date;
import java.util.Formatter;
import java.util.Locale;

import org.dspace.content.Item;
import org.dspace.content.Collection;
import org.dspace.content.ItemIterator;
import org.dspace.core.Context;

/**
 * Command-line service to scan every Item and print a TSV of item data and embargo information
 */
public class ListEmbargoItemTSV {
    // Context is needed in too many places to not globalize it
    private static Context context = null;

    public static void main(String argv[]) throws Exception {
        EmbargoChecker.initTerms();

        try {
            context = new Context();
        }
        catch (SQLException e) {
            System.err.println("Error getting DSpace context: " + e);
            throw e;
        }
        context.setIgnoreAuthorization(true);

        printTSV();

        try {
            context.complete();
        }
        catch (SQLException e) {
            System.err.println("Error completing DSpace context: " + e);
            throw e;
        }
    }

    private static void printTSV() throws Exception {
        ItemIterator ii;

        try {
            ii = Item.findAll(context);
        }
        catch (Exception e) {
            System.err.println("ERROR trying to collect all DSpace items: " + e);
            throw e;
        }

        try {
            System.out.println("handle\tcollection handle\tembargo metadata date\tis protected");
            while (ii.hasNext()) {
                Item i = ii.next();
                EmbargoChecker ec = new EmbargoChecker(context, i);
                Date dt = ec.getEmbargoDate();
                Collection col = i.getOwningCollection();

                StringBuilder sb = new StringBuilder();
                Formatter formatter = new Formatter(sb, Locale.US);

                formatter.format("%s\t%s\t%s\t%s",
                    i.getHandle(), i.getOwningCollection().getHandle(),
                    dt == null ? "N/A" : dt, ec.isProtected() ? "T" : "F");

                System.out.println(sb.toString());
            }
        }
        catch (Exception e) {
            System.err.println("ERROR trying to get next DSpace item: " + e);
            throw e;
        }
    }
}
