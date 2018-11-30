package org.dspace.workflow;

import java.io.IOException;
import java.sql.SQLException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.dspace.content.Collection;
import org.dspace.core.Context;
import org.dspace.eperson.EPerson;
import org.dspace.eperson.Group;

/**
 * Audit command-line tool for checking for workflow problems.  We define
 * workflow problems narrowly at the moment: situations where an inactive user
 * is the only one in charge of review or approval on a collection.
 **/
public class OrphanedWorkflowAuditor {
    // Context is needed in too many places to not globalize it
    private static Context context = null;
    private static boolean verbose = false;

    /**
     * Command-line service to scan every collection, verifying we don't have
     * inactive users as the only ones in review/approve roles.
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
        Collection[] collList = null;

        try {
            collList = Collection.findAll(context);
        }
        catch (SQLException e) {
            System.err.println("Error getting collections list: " + e);
            System.exit(1);
        }

        for (Collection collection : collList) {
            // From what I can tell, the workflow can be stopped on ANY of
            // these steps if they have a group
            auditCollectionWorkflowGroup(collection, 1, "reviewers");
            auditCollectionWorkflowGroup(collection, 2, "approvers");
            auditCollectionWorkflowGroup(collection, 3, "editors");
        }
    }

    private static void auditCollectionWorkflowGroup(Collection collection, int step, String name) {
        Group g = collection.getWorkflowGroup(step);

        // Empty group means this workflow step isn't restricted.  This is
        // *not* the same as a group with no people!
        if (g == null) {
            return;
        }

        EPerson[] people = null;
        try {
            people = Group.allMembers(context, g);
        }
        catch (SQLException e) {
            System.err.printf("Error getting people from group %s: %s\n", g.getName(), e);
            System.exit(1);
        }

        int activePeople = 0;

        for (EPerson p : people) {
            if (!p.canLogIn()) {
                continue;
            }

            activePeople++;
        }

        String prefix = String.format("%s <%s>, group %s",
            collection.getName(), collection.getHandle(), g.getName());
        if (activePeople == 0) {
            System.out.printf("WARN - %s: no active %s!\n", prefix, name);
        }
        else if (verbose) {
            System.out.printf("INFO - %s: %d active %s\n", prefix, activePeople, name);
        }
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
