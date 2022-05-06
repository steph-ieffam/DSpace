package edu.harvard.huit.lts.dash.nrs;

import static org.apache.commons.lang3.StringUtils.isNotBlank;

import java.io.IOException;
import java.sql.SQLException;

import org.dspace.content.DSpaceObject;
import org.dspace.content.Item;
import org.dspace.content.factory.ContentServiceFactory;
import org.dspace.core.Context;
import org.dspace.handle.service.HandleService;
import org.dspace.identifier.Identifier;
import org.dspace.identifier.VersionedHandleIdentifierProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;

public class HarvardNrsIdentifierProvider extends VersionedHandleIdentifierProvider implements InitializingBean {

    private static Logger log = LoggerFactory.getLogger(HarvardNrsIdentifierProvider.class);

    private String apath;

    private String nid;

    @Autowired(required = true)
    private HandleService handleService;

    @Override
    public void afterPropertiesSet() throws Exception {
        apath = configurationService.getProperty("dash.nrs.authority");
        nid = configurationService.getProperty("dash.nrs.namespace");
    }

    protected boolean hasValidConfiguration() {
        return isNotBlank(apath) && isNotBlank(nid);
    }

    @Override
    public boolean supports(Class<? extends Identifier> identifier) {

        if (!hasValidConfiguration()) {
            return super.supports(identifier);
        }

        return HarvardNrsIdentifier.class.isAssignableFrom(identifier);
    }

    @Override
    public String register(Context context, DSpaceObject dso) {

        if (!hasValidConfiguration()) {
            return super.register(context, dso);
        }

        String result = super.register(context, dso);
        log.debug("Identifier {}", result);
        try {
            ContentServiceFactory.getInstance().getDSpaceObjectService(dso)
                    .setMetadataSingleValue(
                            context,
                            dso,
                            "dc",
                            "identifier",
                            "uri",
                            Item.ANY,
                            getNrsCanonicalForm(result));
        } catch (SQLException e) {
            e.printStackTrace();
        }

        return result;
    }

    protected String getNrsCanonicalForm(String identifier) {
        // Let the admin define a new prefix, if not then we'll use the
        // CNRI default. This allows the admin to use "hdl:" if they want too or
        // use a locally branded prefix handle.myuni.edu.
        String handlePrefix = configurationService.getProperty("handle.canonical.prefix");
        if (handlePrefix == null || handlePrefix.length() == 0) {
            handlePrefix = "http://hdl.handle.net/";
        }

        // hack for DASH: Strip off handle-system prefix from internal Handle
        // since we are generating an NRS URL, and NRS won't have it..
        String handlePrefixNumber = configurationService.getProperty("handle.prefix");
        if (identifier.startsWith(handlePrefixNumber + "/")) {
            identifier = identifier.substring(handlePrefixNumber.length() + 1);
        }

        StringBuilder result = new StringBuilder(handlePrefix);
        result.append(nid).append(":").append(apath).append(":").append(identifier);

        return result.toString();
    }

    @Override
    protected String createNewIdentifier(Context context, DSpaceObject dso, String handleId) throws SQLException {
        log.debug("Handle ID: {}", handleId);
        if (!hasValidConfiguration()) {
            return super.createNewIdentifier(context, dso, handleId);
        }

        String handle = handleService.createHandle(context, dso);

        String handlePrefix = configurationService.getProperty("handle.prefix");

        // DASH: mint a fresh NRS name instead. Unfortunately we still have
        // to prepend the DSpace handle prefix to the NSS to use it as a
        // "handle" because too much depends on handles having the "/" syntax.
        // (e.g. every sitemap in XML UI assumes handle includes "/").
        String prefix = configurationService.getProperty("dspace.server.url");
        if (!prefix.endsWith("/")) {
            prefix += "/";
        }
        prefix += "handle/" + handlePrefix + "/";

        handleId = handle.substring(handlePrefix.length() + 1);
        log.info("Created Handle: {}", handle);

        NRSAdmin na = NRSAdmin.getNRSAdmin();
        String result;
        try {
            result = na.createName(handleId);
        } catch (IOException e) {
            // coerce to SQLException to satisfy calling code
            throw new SQLException("Failed when creating NRS URN: " + e.getLocalizedMessage(), e);
        }
        log.info("Created NRS URN: " + result);

        return handle;
    }

}
