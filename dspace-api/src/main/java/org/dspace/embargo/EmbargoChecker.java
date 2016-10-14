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
import org.dspace.content.DCDate;
import org.dspace.content.DSpaceObject;
import org.dspace.content.Item;
import org.dspace.content.Metadatum;
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
    private static String termsOpen = null;

    private Item item;
    private Context context;

    public List<String> warnings, errors, infos;

    public EmbargoChecker(Context c, Item i) {
        item = i;
        context = c;
        warnings = new ArrayList<String>();
        errors = new ArrayList<String>();
        infos = new ArrayList<String>();
    }

    /**
     * Check that embargo is properly set on our Item.  All of the following
     * conditions must be true:
     *
     * - Item is unprotected
     * - Public objects are unprotected
     * - All objects are available on campus
     * - All items with a dc.description.embargo value have non-public objects protected
     * - All protected objects are only protected for 2 years max or
     *   "grandfathered" permanent embargoes (protected forever, but ingested
     *   prior to 2017) (TODO)
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
        Date embargoDate = metadataEmbargoDate();
        Date now = new Date();

        // Items should always be public, otherwise the metadata and other
        // public pieces will be hidden
        if (!isPublic(item)) {
            reportNotPublic(item);
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
                // Ignore all further rules for public objects
                continue;
            }

            // Every bundle and bitstream should be available on campus or
            // fully embargoed by explicitly giving read to the admins group
            if (!isAvailableOnCampus(bn) && !isExplicitlyFullyEmbargoed(bn)) {
                isValid = false;
                reportNotAvailableOnCampus(bn);
            }
            for (Bitstream bs : bn.getBitstreams()) {
                if (!isAvailableOnCampus(bs) && !isExplicitlyFullyEmbargoed(bs)) {
                    isValid = false;
                    reportNotAvailableOnCampus(bs);
                }
            }

            // Is item expected to be under embargo?  If so, all bitstreams
            // should be protected.  Public objects won't reach this block, and
            // per our decision around 2016-10-07, we don't care about bundles
            // being protected as long as their bitstreams are protected.
            if (embargoDate != null && now.before(embargoDate)) {
                if (!isProtected(bn)) {
                    isValid = false;
                    reportNotProtected(bn);
                }
                for (Bitstream bs : bn.getBitstreams()) {
                    if (!isProtected(bs)) {
                        isValid = false;
                        reportNotProtected(bs);
                    }
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

    // Right now this is a somewhat "magic" rule.  Being fully embargoed
    // actually just means it's not public or available on campus, but somebody
    // explicitly set the administrator group to have Read access.
    private boolean isExplicitlyFullyEmbargoed(DSpaceObject o) throws SQLException {
        if (isPublic(o) || isAvailableOnCampus(o)) {
            return false;
        }

        for (ResourcePolicy rp : getReadPolicies(o)) {
            if (groupHasAdministrator(rp.getGroup())) {
                if (rp.isDateValid()) {
                    return true;
                }
            }
        }
        return false;
    }

    // Protected just means anonymous doesn't currently have access
    private boolean isProtected(DSpaceObject o) throws SQLException {
        return !isPublic(o);
    }

    // Returns true if group's id is id or has a group with that id in any of
    // its subgroups (recursively)
    private boolean groupIsOrHasGroupID(Group g, int id) {
        if (g == null) {
            return false;
        }
        if (g.getID() == id) {
            return true;
        }
        for (Group sub : g.getMemberGroups()) {
            if (groupIsOrHasGroupID(sub, id)) {
                return true;
            }
        }

        return false;
    }

    // Returns true if the given group is ANONYMOUS or has ANONYMOUS in its
    // subgroups (recursively)
    private boolean groupHasAnonymous(Group g) {
        return groupIsOrHasGroupID(g, Group.ANONYMOUS_ID);
    }

    // Returns true if the given group is administrators or has administrators
    // in its subgroups (recursively)
    private boolean groupHasAdministrator(Group g) {
        return groupIsOrHasGroupID(g, Group.ADMIN_ID);
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
        warnings.add(String.format("%s (%s) expected to be public (anonymous access), but isn't",
            o.getName(), o.getTypeText()));
        reportReaders(o);
    }

    private void reportNotAvailableOnCampus(DSpaceObject o) throws SQLException {
        warnings.add(String.format("%s (%s) is neither publicly available nor available on campus",
            o.getName(), o.getTypeText()));
        reportReaders(o);
    }

    private void reportNotProtected(DSpaceObject o) throws SQLException {
        errors.add(String.format("%s (%s) is expected to be protected (based on the embargo field), but isn't",
            o.getName(), o.getTypeText()));
        reportReaders(o);
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
            infos.add(String.format("%s has permission to %s %s",
                groupOrPersonName, rp.getActionText(), dateString));
        }
    }

    // Return the parsed date in the embargo metadata field, or null if there's
    // no date or the date is before today
    private Date metadataEmbargoDate() {
        Metadatum terms[] = item.getMetadata(termsSchema, termsElement, termsQualifier, Item.ANY);
        if (terms == null || terms.length == 0) {
            return null;
        }
        String md = terms[0].value;
        if (md.equals(termsOpen))
        {
            return EmbargoManager.FOREVER.toDate();
        }
        return new DCDate(md).toDate();
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

        termsOpen = ConfigurationManager.getProperty("embargo.terms.open");
    }
}
