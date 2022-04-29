package edu.harvard.huit.lts.dash.nrs;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.security.Key;
import java.util.Base64;
import java.util.Date;
import java.util.Map;

import javax.crypto.spec.SecretKeySpec;

import io.jsonwebtoken.JwsHeader;
import io.jsonwebtoken.JwtBuilder;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.apache.http.impl.conn.PoolingHttpClientConnectionManager;
import org.apache.http.entity.StringEntity;
import org.apache.http.util.EntityUtils;
import org.dspace.services.ConfigurationService;
import org.dspace.services.factory.DSpaceServicesFactory;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Interface to LTS Name Resolution Service (NRS)
 *
 * @author Dave Mayo
 *
 */
public class NRSAdmin {

    private static Logger log = LoggerFactory.getLogger(NRSAdmin.class);

    // JWT auth config values
    private static byte[] token; // Base64'd token
    private static String kid; // key identifier
    private static String agentName; // name of agent creating URN

    // API request config values
    private static String apiBaseUrl; // Base URL for NRS-admin API calls
    private static String resourceCreateUrl; // URL for POSTing to create URNs
    private static String deliveryApp; // Delivery application
    private static String authorityPath; // Authority Path for this DASH instance
    private static String namespace; // Namespace: ALWAYS URN-3

    // Base for construction of returned NRS URL
    private static String deliveryBaseUrl; // Base for URL delivered to users
    private static String deliveryPrefix; // Everything but identifier

    private CloseableHttpClient http;
    private PoolingHttpClientConnectionManager connMgr;
    private HttpClientBuilder httpBuilder;

    private static NRSAdmin instance;

    private NRSAdmin() {
        super();

        // Load values from config
        load_config();
        http = getHttpClient();
    }

    /**
     * Get singleton instance, made of pure, unadulterated singletonium
     * 
     * @return singleton instance of NRSAdmin
     */
    public static NRSAdmin getNRSAdmin() {
        if (instance == null) {
            instance = new NRSAdmin();
        }
        return instance;
    }

    private void load_config() {
        ConfigurationService conf = DSpaceServicesFactory.getInstance().getConfigurationService();
        token = Base64.getDecoder().decode(conf.getProperty("dash.nrs.token"));
        kid = conf.getProperty("dash.nrs.token.kid");
        agentName = conf.getProperty("dash.nrs.token.agent");

        apiBaseUrl = conf.getProperty("dash.nrs.apiBaseUrl");
        resourceCreateUrl = apiBaseUrl + "/resource/v1";
        deliveryApp = conf.getProperty("dash.nrs.deliveryApplication");
        authorityPath = conf.getProperty("dash.nrs.authority");
        namespace = conf.getProperty("dash.nrs.namespace");

        deliveryBaseUrl = conf.getProperty("handle.canonical.prefix");
        deliveryPrefix = deliveryBaseUrl + namespace + ":" + authorityPath + ":";
    }

    /**
     * Get the HTTP client
     * 
     * Not static itself, but there should only ever be one,
     * held by the singleton NRSAdmin instance.
     * 
     * @return the http client instance
     */
    private CloseableHttpClient getHttpClient() {
        connMgr = new PoolingHttpClientConnectionManager();
        httpBuilder = HttpClientBuilder.create();
        httpBuilder.setConnectionManager(connMgr);
        return httpBuilder.build();
    }

    /**
     * Create JSON payload for NRSAdmin-API
     * 
     * @param identifier identifier to create NRS name for
     * @return
     * @throws UnsupportedEncodingException If there are missing or incorrect values
     *                                      in configuration
     */
    private static StringEntity constructPayload(String identifier) throws UnsupportedEncodingException {
        JSONObject payload = new JSONObject();
        JSONObject authpath = new JSONObject();
        JSONObject deliveryApplication = new JSONObject();
        authpath.put("path", authorityPath);
        deliveryApplication.put("name", deliveryApp);
        payload.put("authority", authpath);
        payload.put("deliveryApplication", deliveryApplication);
        payload.put("status", "A");
        payload.put("name", identifier);
        payload.put("appId", identifier);

        StringEntity payloadEntity = new StringEntity(payload.toString());
        return payloadEntity;
    }

    /**
     * Get signing key from properties file to create a Key for signing JWT
     * 
     * @return signing key for JWT
     */
    private static Key getSigningKey() {
        Key key = new SecretKeySpec(token, SignatureAlgorithm.HS512.getJcaName()); // should be ENCRYPT_ALG value
        return key;
    }

    /**
     * Get a JWT for the resource in question.
     * <p>
     * Note that this MUST be called immediately prior to dispatching the request,
     * otherwise IssuedAt time will fall outside the allowable window
     * 
     * @param resource type of resource in API, see NRSAdmin API docs
     * @return string of "Bearer " + compacted JWT, ready for use in Authorization
     *         header
     */
    private static String getJwt(String resource) {
        JwsHeader<?> header = Jwts.jwsHeader();
        header.setKeyId(kid);
        header.put("agent", agentName);

        JwtBuilder builder = Jwts.builder()
                .claim("service", resource)
                .setHeader((Map<String, Object>) header)
                .setIssuedAt(new Date())
                .signWith(SignatureAlgorithm.HS512, getSigningKey());

        return "Bearer " + builder.compact();
    }

    /**
     * Create new name in NRS
     * NRS delivery application should be set up to create a URN
     * with correct URL binding, using identifier as appId
     * 
     * @param identifier DSpace handleID to use as NRS name
     * @return full resolved NRS URL
     * @throws IOException If request is malformed or error happens during request
     */
    public String createName(String identifier) throws IOException {
        HttpPost req = new HttpPost(resourceCreateUrl);
        try {
            req.setEntity(constructPayload(identifier));
            req.addHeader("Content-type", "application/json");
            req.addHeader("Authorization", getJwt("/resource"));
        } catch (UnsupportedEncodingException e) {
            log.error("Exception while constructing NRS URN POST request: " + e.getMessage(), e);
            throw new IOException("NRS URN creation failed while creating post request: " + e.getLocalizedMessage(), e);
        }
        try (CloseableHttpResponse httpResponse = http.execute(req)) {
            int status = httpResponse.getStatusLine().getStatusCode();
            if (status != 200) {
                log.error(EntityUtils.toString(req.getEntity()));
                log.error(EntityUtils.toString(httpResponse.getEntity()));
                throw new IOException("NRS URN creation failed with status code " + String.valueOf(status));
            }
        } catch (IOException e) {
            log.error("Exception during NRS URN creation: " + e.getLocalizedMessage(), e);
        }

        return deliveryPrefix + identifier;
    }

}
