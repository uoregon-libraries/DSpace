package org.dspace.workflow;

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
import org.dspace.handle.HandleManager;

/**
 * Audit command-line tool for checking for workflow problems.  We define
 * workflow problems narrowly at the moment: situations where an inactive user
 * is the only one in charge of review or approval on a collection or
 * community.
 **/
public class OrphanedWorkflowAuditor {
    // Context is needed in too many places to not globalize it
    private static Context context = null;
    private static boolean verbose = false;

    /**
     * Command-line service to scan every community and collection, verifying
     * we don't have inactive users as the only ones in review/approve roles.
     */
    public static void main(String argv[]) {
        parseCLI(argv);
        getContext();
        audit();
        releaseContext();
    }

    private static void parseCLI(String argv[]) {
        Options options = new Options();
        options.addOption("h", "help", false, "help");
        options.addOption("v", "verbose", false, "Show extra information");

        CommandLine line = null;
        try {
            line = new PosixParser().parse(options, argv);
        }
        catch(ParseException e) {
            System.err.println("Command error: " + e.getMessage());
            new HelpFormatter().printHelp(OrphanedWorkflowAuditor.class.getName(), options);
            System.exit(1);
        }

        if (line.hasOption('h')) {
            new HelpFormatter().printHelp(OrphanedWorkflowAuditor.class.getName(), options);
            System.exit(0);
        }

        verbose = line.hasOption('v');
    }

    private static void getContext() {
        try {
            context = new Context();
        }
        catch (SQLException e) {
            System.err.println("Error getting DSpace context: " + e);
            System.exit(1);
        }
        context.setIgnoreAuthorization(true);
    }

    private static void audit() {
    }

    private static void releaseContext() {
        try {
            context.complete();
        }
        catch (SQLException e) {
            System.err.println("Error completing DSpace context: " + e);
            System.exit(1);
        }
    }
}
