package org.dspace.embargo;

import java.sql.SQLException;
import java.io.IOException;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Calendar;
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
    private Date embargoDate = null;
    private Date now = null;
    private Date available = null;

    public List<String> warnings, errors, infos;

    public EmbargoChecker(Context c, Item i) {
        item = i;
        context = c;
        warnings = new ArrayList<String>();
        errors = new ArrayList<String>();
        infos = new ArrayList<String>();

        embargoDate = metadataEmbargoDate();
        available = itemAvailableDate();
        now = new Date();
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
     *   when we had more loose requirements)
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
        // public pieces will be hidden
        if (!isPublic(item)) {
            isValid = false;
            reportNotPublic(item);
        }

        // Ingest date should be valid or else we don't know how to do
        // public-date-validity checking
        if (available == null) {
            isValid = false;
            reportNullAvailabilityDate();
        }
        else if (available.after(now)) {
            isValid = false;
            reportAvailabilityDateAfterNow();
            available = null;
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
                for (Bitstream bs : bn.getBitstreams()) {
                    if (!isProtected(bs)) {
                        isValid = false;
                        reportNotProtected(bs);
                    }
                }
            }

            // Bundle and bitstreams should be publicly available eventually
            if (!isPublicAccessDateValid(bn)) {
                isValid = false;
                reportPublicAccessDateInvalid(bn);
            }
            for (Bitstream bs : bn.getBitstreams()) {
                if (!isPublicAccessDateValid(bs)) {
                    isValid = false;
                    reportPublicAccessDateInvalid(bs);
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
    // the policy must start now or prior and never end.  Lack of policies does
    // *not* default to public access.
    private boolean isPublic(DSpaceObject o) throws SQLException {
        ResourcePolicy rp = getPublicReadPolicy(o);
        if (rp != null && rp.isDateValid() && rp.getEndDate() == null) {
            return true;
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

    // Returns the dc.date.available value as a Date object
    private Date itemAvailableDate() {
        Metadatum terms[] = item.getMetadata("dc", "date", "available", Item.ANY);
        if (terms == null || terms.length == 0) {
            terms = item.getMetadata("dc", "date", "accessioned", Item.ANY);
        }
        if (terms == null || terms.length == 0) {
            return null;
        }
        return new DCDate(terms[0].value).toDate();
    }

    // Grandfathered items are those ingested during a specific time period
    // when we allowed "forever" embargoes
    private boolean isIngestWithinGrandfatheredEmbargoTime() {
        Calendar c = Calendar.getInstance();

        // If it's prior to 2014, it's not grandfathered
        c.set(2014, 1, 1);
        if (available.before(c.getTime())) {
            return false;
        }

        // If it's after September 2016, it's not grandfathered
        c.set(2016, 9, 1);
        if (available.after(c.getTime())) {
            return false;
        }

        infos.add("item is grandfathered");
        return true;
    }

    // Find the read permissions for any groups which include anonymous,
    // returning the first.  If multiple groups include anonymous and have been
    // set to have conflicting read permission, this function will be all kinds
    // of wrong.
    private ResourcePolicy getPublicReadPolicy(DSpaceObject o) throws SQLException {
        for (ResourcePolicy rp : getReadPolicies(o)) {
            if (groupHasAnonymous(rp.getGroup())) {
                return rp;
            }
        }
        return null;
    }

    // Public access date being valid means that the object will be visible
    // within a set maximum date range of the item's creation unless the item
    // was ingested during the period we allowed "forever" embargoes"
    private boolean isPublicAccessDateValid(DSpaceObject o) throws SQLException {
        if (isIngestWithinGrandfatheredEmbargoTime()) {
            return true;
        }

        ResourcePolicy rp = getPublicReadPolicy(o);
        if (rp == null) {
            return false;
        }

        infos.add(String.format("%s (%s) public read policy from %s to %s",
            o.getName(), o.getTypeText(), rp.getStartDate(), rp.getEndDate()));

        // Items must not publicly "expire"
        if (rp.getEndDate() != null) {
            return false;
        }

        // Items must not be embargoed longer than 2 years
        Calendar c = Calendar.getInstance();
        c.setTime(available);
        c.add(Calendar.YEAR, 2);
        if (rp.getStartDate() != null && rp.getStartDate().before(c.getTime())) {
            return false;
        }

        return true;
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

    private void reportNullAvailabilityDate() {
        warnings.add("Availability / accession date is empty or invalid");
    }

    private void reportAvailabilityDateAfterNow() {
        warnings.add(String.format("Availability / accession date (%s) is after today", available));
    }

    private void reportPublicAccessDateInvalid(DSpaceObject o) throws SQLException {
        warnings.add(String.format("%s (%s) has public access too far beyond today",
            o.getName(), o.getTypeText()));
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
