package org.dspace.embargo;

import java.sql.SQLException;
import java.io.IOException;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Date;
import java.util.Properties;

import org.dspace.authorize.AuthorizeException;
import org.dspace.authorize.AuthorizeManager;
import org.dspace.authorize.ResourcePolicy;
import org.dspace.content.Bundle;
import org.dspace.content.Bitstream;
import org.dspace.content.DSpaceObject;
import org.dspace.content.Item;
import org.dspace.core.ConfigurationManager;
import org.dspace.core.Constants;
import org.dspace.core.Context;
import org.dspace.eperson.EPerson;
import org.dspace.eperson.Group;
import org.dspace.license.CreativeCommons;

/**
 * Embargo-checking class
 */
public class EmbargoChecker {
    // Metadata field components for user-supplied embargo terms
    // set from the DSpace configuration by initTerms()
    private static String termsSchema = null;
    private static String termsElement = null;
    private static String termsQualifier = null;

    private Item item;
    private Context context;
    private boolean verbose;

    public List<String> details;

    public EmbargoChecker(Context c, Item i, boolean v) {
        item = i;
        context = c;
        verbose = v;
        details = new ArrayList<String>();
    }

    /**
     * Check that embargo is properly set on our Item.  All of the following
     * conditions must be true:
     *
     * - Item is unprotected
     * - Public objects are unprotected
     * - All objects are available on campus
     * - All protected objects are only protected for 2 years max or
     *   "grandfathered" permanent embargoes (protected forever, but ingested
     *   prior to 2017)
     *
     * Some terms and definitions that are probably confusing:
     *
     * - "Public" objects are bundles or bitstreams we want exposed at all
     *   times, such as the license, text files, thumbnails, etc.
     * - "Unprotected" means one of the following is true:
     *   - ANONYMOUS READ access in the past with no end date
     *   - ANONYMOUS READ access with no start date with no end date
     * - "Protected" means there's a policy for ANONYMOUS READ access, and its
     *   start date is in the future
     * - Being "available on campus" means the object is unprotected or the
     *   "UO only" group has READ permissions with no start date or a date in
     *   the past and no end date
     */
    public boolean checkEmbargo()
        throws SQLException, AuthorizeException, IOException {
        boolean isValid = true;

        // Items should always be public, otherwise the metadata and other
        // public pieces will be hidden.  It's not worth reporting all the
        // other problems when the item is the main problem, unless verbose
        // output was requested.
        if (!isPublic(item)) {
            reportNotPublic(item);
            if (!verbose) {
                return false;
            }
        }

        for (Bundle bn : item.getBundles()) {
            // If it's a public bundle, the bundle and all its bitstreams must
            // be unprotected
            if (bundleIsExpectedToBePublic(bn)) {
                if (!isPublic(bn)) {
                    isValid = false;
                    reportNotPublic(bn);
                }
                for (Bitstream bs : bn.getBitstreams()) {
                    if (!isPublic(bs)) {
                        isValid = false;
                        reportNotPublic(bs);
                    }
                }
                continue;
            }

            // If it's a "visible" bundle, the bundle should be unprotected,
            // but the bitstreams can be protected
            if (bundleIsExpectedToBeVisible(bn)) {
                if (!isPublic(bn)) {
                    isValid = false;
                    reportNotPublic(bn);
                }
            }

            // Every bundle and bitstream should be available on campus
            if (!isAvailableOnCampus(bn)) {
                isValid = false;
                reportNotAvailableOnCampus(bn);
            }
            for (Bitstream bs : bn.getBitstreams()) {
                if (!isAvailableOnCampus(bs)) {
                    isValid = false;
                    reportNotAvailableOnCampus(bs);
                }
            }
        }

        return isValid;
    }

    /**
     * Check a name against bundle names which are meant to be 100% public.
     * Public bundles are those which we expect to be unprotected, and which we
     * expect bitstreams inside to also be unprotected.  For us, this means
     * licenses and metadata.  We include a hard-coded string, "LICENCE", as
     * that's what one of our tools has been importing.
     *
     * @return true if the Bundle's name is in the list of 100% public bundle
     * names.
     */
    private boolean bundleIsExpectedToBePublic(Bundle bn) {
        String name = bn.getName();
        return name.equals(Constants.LICENSE_BUNDLE_NAME) ||
            name.equals(Constants.METADATA_BUNDLE_NAME) ||
            name.equals(CreativeCommons.CC_BUNDLE_NAME) ||
            name.equals("LICENCE");
    }

    /**
     * Check a name against bundle names which are meant to be visible to the
     * public.  These semi-public bundles are ones we expect to be unprotected,
     * but their bitstreams should be protected.
     *
     * @return true if the name is in the list of visible bundle names.
     */
    private boolean bundleIsExpectedToBeVisible(Bundle bn) {
        String name = bn.getName();
        return name.equals("TEXT") || name.equals("THUMBNAIL");
    }

    // A public object must have ANONYMOUS in the list of read policies, and
    // the policy must start now or prior and never end
    private boolean isPublic(DSpaceObject o) throws SQLException {
        for (ResourcePolicy rp : getReadPolicies(o)) {
            if (groupHasAnonymous(rp.getGroup())) {
                if (rp.isDateValid() && rp.getEndDate() == null) {
                    return true;
                }
            }
        }
        return false;
    }

    // Available on campus means either being available publicly (having the
    // anonymous group) or having the "UO only" group in the list of read
    // policies, and the policy starts now or prior, and never ends
    private boolean isAvailableOnCampus(DSpaceObject o) throws SQLException {
        if (isPublic(o)) {
            return true;
        }

        for (ResourcePolicy rp : getReadPolicies(o)) {
            if (groupHasUOOnly(rp.getGroup())) {
                if (rp.isDateValid() && rp.getEndDate() == null) {
                    return true;
                }
            }
        }
        return false;
    }

    // Returns true if the given group is ANONYMOUS or has ANONYMOUS in its
    // subgroups (recursively)
    private boolean groupHasAnonymous(Group g) {
        if (g == null) {
            return false;
        }
        if (g.getID() == Group.ANONYMOUS_ID) {
            return true;
        }
        for (Group sub : g.getMemberGroups()) {
            if (groupHasAnonymous(sub)) {
                return true;
            }
        }

        return false;
    }

    // Returns true if the given group is UO only or has UO only in its
    // subgroups (recursively)
    private boolean groupHasUOOnly(Group g) {
        if (g == null) {
            return false;
        }
        if (g.getName().equals("UO only")) {
            return true;
        }
        for (Group sub : g.getMemberGroups()) {
            if (groupHasUOOnly(sub)) {
                return true;
            }
        }

        return false;
    }

    // Shorter and clearer way to get at the read-policy list for an object
    private List<ResourcePolicy> getReadPolicies(DSpaceObject o) throws SQLException {
        return AuthorizeManager.getPoliciesActionFilter(context, o, Constants.READ);
    }

    private void reportNotPublic(DSpaceObject o) throws SQLException {
        details.add(String.format("%s (%s) should be public", o.getName(), o.getTypeText()));
        if (verbose) {
            reportReaders(o);
        }
    }

    private void reportNotAvailableOnCampus(DSpaceObject o) throws SQLException {
        details.add(String.format("%s (%s) is neither publicly available nor available on campus",
            o.getName(), o.getTypeText()));
        if (verbose) {
            reportReaders(o);
        }
    }

    private void reportReaders(DSpaceObject o) throws SQLException {
        for (ResourcePolicy rp : getReadPolicies(o)) {
            EPerson eperson = rp.getEPerson();
            Group group = rp.getGroup();
            Date startDate = rp.getStartDate();
            Date endDate = rp.getEndDate();

            String groupOrPersonName = "UNKNOWN";
            if (eperson != null) {
                groupOrPersonName = eperson.getName() + " (person)";
                if (group != null) {
                    groupOrPersonName += " AND " + group.getName() + " (group)";
                }
            }
            else if (group != null) {
                groupOrPersonName = group.getName() + " (group)";
            }

            String dateString;
            if (startDate == null) {
                if (endDate == null) {
                    dateString = "forever";
                }
                else {
                    dateString = "until " + endDate.toString();
                }
            }
            else {
                if (endDate == null) {
                    dateString = "starting " + startDate.toString();
                }
                else {
                    dateString = "from " + startDate.toString() + " until " + endDate.toString();
                }
            }
            details.add(String.format("%s has permission to %s %s",
                groupOrPersonName, rp.getActionText(), dateString));
        }
    }

    // initialize - get metadata field setting from config
    public static void initTerms() throws IllegalStateException {
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
