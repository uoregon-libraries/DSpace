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
import org.apache.log4j.Logger;
import org.dspace.authorize.AuthorizeException;
import org.dspace.content.DSpaceObject;
import org.dspace.content.Item;
import org.dspace.content.ItemIterator;
import org.dspace.core.ConfigurationManager;
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
    /** log4j category */
    private static Logger log = Logger.getLogger(EmbargoAuditor.class);

    // Metadata field components for user-supplied embargo terms
    // set from the DSpace configuration by init()
    private static String termsSchema = null;
    private static String termsElement = null;
    private static String termsQualifier = null;

    // Context is needed in too many places to not globalize it
    private static Context context = null;

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
        initTerms();

        try {
            context = new Context();
        }
        catch (SQLException e) {
            System.err.println("Error getting DSpace context: " + e);
            System.exit(1);
        }
        context.setIgnoreAuthorization(true);
        Date now = new Date();

        List<Item> items = getItemList(line);
        EmbargoChecker ec;
        for (Item i : items) {
            ec = new EmbargoChecker(context, i, System.out);
            try {
                ec.checkEmbargo();
            }
            catch (Exception e) {
                System.out.printf("ERROR: Unable to check %s for embargoes: %s", i.getHandle(), e);
            }
        }

        try {
            context.complete();
        }
        catch (SQLException e) {
            System.err.println("Error completing DSpace context: " + e);
            System.exit(1);
        }
    }

    private static CommandLine parseCLI(String argv[]) {
        Options options = new Options();
        options.addOption("h", "help", false, "help");
        options.addOption("i", "identifier", true,
                        "Process ONLY this Handle identifier(s), which must be an Item.  Can be repeated.");

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

    private static List<Item> getItemList(CommandLine line) {
        List<Item> items = new ArrayList<Item>();
        if (line.hasOption('i')) {
            try {
                items = getItemsForIdentifiers(line.getOptionValues('i'));
            }
            catch (Exception e) {
                System.err.println("ERROR parsing one or more identifiers: " + e);
                System.exit(1);
            }
        }
        else {
            try {
                ItemIterator ii = Item.findAll(context);
                while (ii.hasNext()) {
                    items.add(ii.next());
                }
            }
            catch (Exception e) {
                System.err.println("ERROR trying to collect all DSpace items: " + e);
                System.exit(1);
            }
        }

        return items;
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

    // initialize - get MD field setting from config
    private static void initTerms() throws IllegalStateException {
        String terms = ConfigurationManager.getProperty("embargo.field.terms");
        if (terms == null) {
            throw new IllegalStateException("Missing required configuration property 'embargo.field.terms'.");
        }

        String termFields[] = terms.split("\\.", 3);
        if (termFields.length != 3) {
            throw new IllegalStateException("Configuration property 'embargo.field.terms' is invalid.");
        }
        termsSchema = termFields[0];
        termsElement = termFields[1];
        termsQualifier = termFields[2];
    }
}
