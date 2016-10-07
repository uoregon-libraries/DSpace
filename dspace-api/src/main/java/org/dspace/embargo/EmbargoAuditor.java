package org.dspace.embargo;

import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Date;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.dspace.authorize.AuthorizeException;
import org.dspace.content.DSpaceObject;
import org.dspace.content.Item;
import org.dspace.content.ItemIterator;
import org.dspace.core.Constants;
import org.dspace.core.Context;
import org.dspace.core.PluginManager;
import org.dspace.embargo.EmbargoChecker;
import org.dspace.handle.HandleManager;

/**
 * Audit command-line tool for checking embargo status.  We've put this in
 * place of the embargo lifter command in launcher.xml since the embargo lifter
 * is no longer meant to be used.
 */
public class EmbargoAuditor {
    // Context is needed in too many places to not globalize it
    private static Context context = null;
    private static boolean verbose = false;
    private static boolean quiet = false;

    /**
     * Command-line service to scan every Item and verify it's either embargoed
     * properly or unrestricted.  This can produce false positives if
     * permissions are custom for an Item.
     * <p>
     * Options:
     * <dl>
     *   <dt>-h,--help</dt>
     *   <dd>         Help.</dd>
     *   <dt>-i,--identifier</dt>
     *   <dd>         Process ONLY this Handle identifier(s), which must be
     *                      an Item.  Can be repeated.</dd>
     * </dl>
     */
    public static void main(String argv[]) {
        CommandLine line = parseCLI(argv);
        verbose = line.hasOption('v');
        quiet = line.hasOption('q');
        EmbargoChecker.initTerms();

        try {
            context = new Context();
        }
        catch (SQLException e) {
            System.err.println("Error getting DSpace context: " + e);
            System.exit(1);
        }
        context.setIgnoreAuthorization(true);

        if (line.hasOption('i')) {
            checkItems(line.getOptionValues('i'));
        }
        else {
            checkAllItems();
        }

        try {
            context.complete();
        }
        catch (SQLException e) {
            System.err.println("Error completing DSpace context: " + e);
            System.exit(1);
        }
    }

    private static void checkItems(String[] ids) {
        try {
            List<Item> items = getItemsForIdentifiers(ids);
            for (Item i : items) {
                checkEmbargoes(i);
            }
        }
        catch (Exception e) {
            System.err.println("ERROR parsing one or more identifiers: " + e);
            System.exit(1);
        }
    }

    private static void checkAllItems() {
        ItemIterator ii = null;
        try {
            ii = Item.findAll(context);
        }
        catch (Exception e) {
            System.err.println("ERROR trying to collect all DSpace items: " + e);
            System.exit(1);
        }

        try {
            while (ii.hasNext()) {
                checkEmbargoes(ii.next());
            }
        }
        catch (Exception e) {
            System.err.println("ERROR trying to get next DSpace item: " + e);
            System.exit(1);
        }
    }

    private static void checkEmbargoes(Item i) throws SQLException {
        EmbargoChecker ec;

        ec = new EmbargoChecker(context, i);
        try {
            if (!ec.checkEmbargo()) {
                if (ec.warnings.size() == 0 && ec.errors.size() == 0) {
                    System.out.printf("ERROR - <%s> - unspecified embargo problem!\n", i.getHandle());
                }
                for (String d : ec.errors) {
                    System.out.printf("ERROR - <%s> - %s\n", i.getHandle(), d);
                    if (quiet) {
                        break;
                    }
                }
                for (String d : ec.warnings) {
                    System.out.printf("WARN - <%s> - %s\n", i.getHandle(), d);
                    if (quiet) {
                        break;
                    }
                }
                if (verbose) {
                    for (String d : ec.infos) {
                        System.out.printf("INFO - <%s> - %s\n", i.getHandle(), d);
                        if (quiet) {
                            break;
                        }
                    }
                }
            }
            else if (verbose) {
                System.out.printf("DEBUG - <%s> - audit success\n", i.getHandle());
            }
        }
        catch (Exception e) {
            System.err.printf("ERROR - Unable to check %s for embargoes: %s\n", i.getHandle(), e);
            e.printStackTrace(System.err);
        }
    }

    private static CommandLine parseCLI(String argv[]) {
        Options options = new Options();
        options.addOption("h", "help", false, "help");
        options.addOption("i", "identifier", true,
                        "Process ONLY this Handle identifier(s), which must be an Item.  Can be repeated.");
        options.addOption("v", "verbose", false, "Show extra information about audit failures");
        options.addOption("q", "quiet", false, "Only show the first error for each item");

        CommandLine line = null;
        try {
            line = new PosixParser().parse(options, argv);
        }
        catch(ParseException e) {
            System.err.println("Command error: " + e.getMessage());
            new HelpFormatter().printHelp(EmbargoManager.class.getName(), options);
            System.exit(1);
        }

        if (line.hasOption('h')) {
            new HelpFormatter().printHelp(EmbargoAuditor.class.getName(), options);
            System.exit(0);
        }

        return line;
    }

    private static List<Item> getItemsForIdentifiers(String identifiers[]) throws IllegalArgumentException, SQLException {
        List<Item> items = new ArrayList<Item>();
        for (String handle : identifiers) {
            DSpaceObject dso = HandleManager.resolveToObject(context, handle);
            if (dso == null) {
                throw new IllegalArgumentException("cannot resolve handle="+handle+" to a DSpace Item");
            }
            else if (dso.getType() != Constants.ITEM) {
                throw new IllegalArgumentException("cannot process handle="+handle+"; this is not a DSpace Item");
            }
            items.add((Item)dso);
        }

        return items;
    }
}
