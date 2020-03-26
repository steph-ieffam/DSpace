package org.dspace.app.cris.unpaywall;

import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.net.URISyntaxException;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.http.HttpException;
import org.apache.http.HttpResponse;
import org.apache.http.HttpStatus;
import org.apache.http.StatusLine;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.utils.URIBuilder;
import org.apache.http.config.SocketConfig;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.apache.http.impl.client.HttpClients;
import org.apache.log4j.Logger;
import org.dspace.app.cris.unpaywall.model.Unpaywall;
import org.dspace.app.cris.unpaywall.services.UnpaywallPersistenceService;
import org.dspace.core.ConfigurationManager;
import org.dspace.utils.DSpace;

import it.cilea.osd.common.core.SingleTimeStampInfo;

public class UnpaywallService 
{
    private CloseableHttpClient client = null;

    private UnpaywallPersistenceService unpaywallPersistenceService;
    
    private int timeout;

    /** log4j category */
    private static final Logger log = Logger.getLogger(UnpaywallService.class);

    public UnpaywallService()
    {
        HttpClientBuilder custom = HttpClients.custom();
        client = custom.disableAutomaticRetries().setMaxConnTotal(5)
                .setDefaultSocketConfig(
                        SocketConfig.custom().setSoTimeout(timeout).build())
                .build();
    }

    private String unpaywallCall(String doi) throws HttpException
    {
        String endpoint = ConfigurationManager.getProperty("unpaywall", "url");
        String apiKey = ConfigurationManager.getProperty("unpaywall", "apikey");

        String source = null;

        HttpGet method = null;

        try {
            endpoint = endpoint + doi;
            URIBuilder uriBuilder = new URIBuilder(endpoint);
            uriBuilder.addParameter("email", apiKey);
            method = new HttpGet(uriBuilder.build());
            
            HttpResponse response = client.execute(method);
            StatusLine statusLine = response.getStatusLine();
            int statusCode = response.getStatusLine().getStatusCode();
            if (statusCode != HttpStatus.SC_OK)
            {
                throw new RuntimeException("Http call failed: " + statusLine);
            }

            InputStream is = response.getEntity().getContent();
            StringWriter writer = new StringWriter();
            IOUtils.copy(is, writer, "UTF-8");
            source = writer.toString();
             
            method.releaseConnection();
//            getUnpaywallPersistenceService().saveOrUpdate(Unpaywall.class, unpaywall);
        } catch (IOException | URISyntaxException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
        finally
        {
            if (method != null)
            {
                method.releaseConnection();
            }
        }
        return source;
    }

    /**
     * Execute a call to Unpaywall with local cache
     * @param doi The DOI
     * @throws HttpException
     */
    public Unpaywall searchByDOI(String doi) throws HttpException
    {
    	return searchByDOI(doi, true);
    }
    
    /**
     * Execute a call to Unpaywall
     * @param doi The DOI
     * @param useCache Whether to use the local cache
     * @throws HttpException
     */
    public Unpaywall searchByDOI(String doi, Boolean useCache) throws HttpException
    {
        Long cacheTime = ConfigurationManager.getLongProperty("unpaywall",
                "cachetime") * 1000;

        Unpaywall unpaywall = null;

        if (StringUtils.isBlank(doi))
        {
            log.warn("trying to call unpaywall service with blank or null DOI");
            return null;
        }
        
        unpaywall = getUnpaywallPersistenceService().uniqueByDOI(doi);

        if (!useCache && unpaywall != null) {
        	return callAndUpdate(unpaywall);
        }
        
        // If nothing is found locally call the service and exit
        if (unpaywall == null)
        {
            return makeCall(doi);
        }
        
        
        Long currentDate = System.currentTimeMillis();
        SingleTimeStampInfo lastModified = unpaywall.getTimeStampInfo().getTimestampLastModified();
        Long lastCall;
        if(lastModified == null)
        {
        	lastCall = unpaywall.getTimeStampInfo().getTimestampCreated().getTimestamp().getTime();
        }else {
			lastCall = unpaywall.getTimeStampInfo().getTimestampLastModified().getTimestamp().getTime(); 
		}
        
        long diffTime = currentDate - lastCall;
        if ( diffTime <= cacheTime)
        {
            return unpaywall;
        }
        else
        {
            return callAndUpdate(unpaywall);
        }
    }
    
    private Unpaywall callAndUpdate(Unpaywall unpaywall) throws HttpException {
    	unpaywall.setUnpaywallJsonString(
    				unpaywallCall(
    							unpaywall.getDOI()));
    	
    	getUnpaywallPersistenceService().saveOrUpdate(Unpaywall.class, unpaywall);
    	
    	return unpaywall;
	}
    
    private Unpaywall makeCall(String doi) throws HttpException {
    	
    	String jsonString = unpaywallCall(doi);
    	Unpaywall unpaywall = UnpaywallUtils.makeUnpaywall(jsonString);
    	
        getUnpaywallPersistenceService().saveOrUpdate(Unpaywall.class, unpaywall);
        return unpaywall;
	}

    public void setTimeout(int timeout)
    {
        this.timeout = timeout;
    }

	public UnpaywallPersistenceService getUnpaywallPersistenceService() {
		if(unpaywallPersistenceService == null)
		{
			unpaywallPersistenceService = new DSpace().getSingletonService(UnpaywallPersistenceService.class);
		}
		return unpaywallPersistenceService;
	}

	public void setUnpaywallPersistenceService(UnpaywallPersistenceService unpaywallPersistenceService) {
		this.unpaywallPersistenceService = unpaywallPersistenceService;
	}

}
