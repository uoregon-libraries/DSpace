package org.dspace.embargo;

import java.sql.SQLException;
import java.io.IOException;
import java.io.PrintStream;
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
import org.dspace.core.Constants;
import org.dspace.core.Context;
import org.dspace.license.CreativeCommons;

/**
 * Embargo-checking class
 */
public class EmbargoChecker {
    private Item item;
    private Context context;
    private PrintStream out;

    public EmbargoChecker(Context c, Item i, PrintStream o) {
        item = i;
        context = c;
        out = o;
    }

    /**
     * Check that embargo is properly set on our Item.  All of the following
     * conditions must be true:
     *
     * - Item is unprotected
     * - Public elements are unprotected
     * - All elements are available on campus
     * - All protected elements share the same start date for their policy
     *
     * Some terms and definitions that are probably confusing:
     *
     * - "Element" refers to either a bundle or a bitstream.
     * - "Public" elements are bundles or bitstreams we want exposed at all
     *   times, such as the license, text files, thumbnails, etc.
     * - "Unprotected" means one of the following is true:
     *   - No access restrictions
     *   - ANONYMOUS READ access in the past
     *   - ANONYMOUS READ access with no start date
     * - "Protected" means there's a policy for ANONYMOUS READ access, and its
     *   start date is in the future
     * - Being "available on campus" means the element is unprotected or the
     *   "UO only" group has READ permissions with no start date or a date in
     *   the past
     *
     * @param context the DSpace context
     */
    public void checkEmbargo()
        throws SQLException, AuthorizeException, IOException {
        for (Bundle bn : item.getBundles()) {
            // If it's a public bundle, the bundle and all its bitstreams must
            // be unprotected
            if (bundleIsExpectedToBePublic(bn)) {
                if (!isPublic(bn)) {
                    reportNotPublic(bn);
                }
                for (Bitstream bs : bn.getBitstreams()) {
                    if (!isPublic(bs)) {
                        reportNotPublic(bs);
                    }
                }
                continue;
            }

            // If it's a "visible" bundle, the bundle should be unprotected,
            // but the bitstreams should be protected
        }
    }

    /**
     * Check a name against bundle names which are meant to be 100% public.
     * Public bundles are those which we expect to be unprotected, and which we
     * expect bitstreams inside to also be unprotected.  For us, this means
     * licenses and metadata.
     *
     * @return true if the Bundle's name is in the list of 100% public bundle
     * names.
     */
    private boolean bundleIsExpectedToBePublic(Bundle bn) {
        String name = bn.getName();
        return name.equals(Constants.LICENSE_BUNDLE_NAME) ||
            name.equals(Constants.METADATA_BUNDLE_NAME) ||
            name.equals(CreativeCommons.CC_BUNDLE_NAME);
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
    // the policy must start now or prior
    private boolean isPublic(DSpaceObject o) {
        return false;
    }

    // Shorter and clearer way to get at the read-policy list for an object
    private List<ResourcePolicy> getReadPolicies(DSpaceObject o) throws SQLException {
        return AuthorizeManager.getPoliciesActionFilter(context, o, Constants.READ);
    }

    private void reportNotPublic(DSpaceObject o) throws SQLException {
        out.printf("WARNING: %s %s isn't public, and can only be read by:", item.getHandle(), o.getName());
        reportReaders(o);
    }

    private void reportReaders(DSpaceObject o) throws SQLException {
        for (ResourcePolicy rp : getReadPolicies(o)) {
            out.printf("FOO!"+rp);
        }
    }
}
