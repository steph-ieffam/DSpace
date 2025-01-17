/**
 * The contents of this file are subject to the license and copyright
 * detailed in the LICENSE and NOTICE files at the root of the source
 * tree and available online at
 *
 * http://www.dspace.org/license/
 */
package org.dspace.metrics.embeddable.impl;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.google.gson.JsonObject;
import org.dspace.content.Item;
import org.dspace.content.service.ItemService;
import org.dspace.core.Context;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;

/**
 * Unit tests for EmbeddablePlumXMetricProvider.
 *
 * @author Alba Aliu (alba.aliu at atis.al)
 */
@RunWith(MockitoJUnitRunner.class)
public class EmbeddablePlumXMetricProviderTest {
    @Mock
    private ItemService itemService;
    @Mock
    private EmbeddablePlumXMetricProvider provider;
    @Mock
    Context context;
    @Mock
    Item item;

    @Before
    public void setUp() throws Exception {
        when(provider.innerHtml(any(), any())).thenCallRealMethod();
        when(provider.getEntityType(any())).thenCallRealMethod();
        when(provider.hasMetric(any(), any(), any())).thenCallRealMethod();
        when(provider.getItemService()).thenReturn(itemService);
    }

    @Test
    public void hasMetricEmptyEntityType() {
        boolean hasMetric = provider.hasMetric(context, item, null);
        assertFalse(hasMetric);
    }

    @Test
    public void hasMetricPublicationWithoutDoi() {
        when(itemService.getMetadataFirstValue(item, "dspace", "entity", "type", Item.ANY)).thenReturn("Publication");
        when(itemService.getMetadataFirstValue(item, "dc", "identifier", "doi", Item.ANY)).thenReturn(null);
        boolean hasMetric = provider.hasMetric(context, item, null);
        assertFalse(hasMetric);
    }

    @Test
    public void hasMetricPublicationWithDoi() {
        when(itemService.getMetadataFirstValue(item, "dspace",
                "entity", "type", Item.ANY)).thenReturn("Publication");
        when(itemService.getMetadataFirstValue(item, "dc",
                "identifier", "doi", Item.ANY)).thenReturn("10.1016/j.gene.2009.04.019");
        boolean hasMetric = provider.hasMetric(context, item, null);
        assertTrue(hasMetric);
    }

    @Test
    public void hasMetricPublicationWithOrcid() {
        when(itemService.getMetadataFirstValue(item, "dspace",
                "entity", "type", Item.ANY)).thenReturn("Person");
        when(itemService.getMetadataFirstValue(item, "person",
                "identifier", "orcid", Item.ANY)).thenReturn("0000-0002-9029-1854");
        boolean hasMetric = provider.hasMetric(context, item, null);
        assertTrue(hasMetric);
    }

    @Test
    public void hasMetricPublicationWithoutOrcid() {
        when(itemService.getMetadataFirstValue(item, "dspace", "entity", "type", Item.ANY)).thenReturn("Person");
        when(itemService.getMetadataFirstValue(item, "person", "identifier", "orcid", Item.ANY)).thenReturn(null);
        boolean hasMetric = provider.hasMetric(context, item, null);
        assertFalse(hasMetric);
    }

    @Test
    public void innerHtmlForPersonItem() {
        provider.orcid = "0000-0002-9029-1854";
        when(itemService.getMetadataFirstValue(item, "dspace", "entity", "type", Item.ANY)).thenReturn("Person");
        String template = provider.innerHtml(context, item);
        JsonObject verificationJson = new JsonObject();
        assertEquals(template, "{\"type\":\"Person\",\"src\":\"//cdn.plu.mx/widget-person.js\",\"href\":\"https://plu.mx/plum/u/?orcid=" + provider.orcid + "\"}");
    }

    @Test
    public void innerHtmlForPublicationItem() {
        provider.doiIdentifier = "10.1016/j.gene.2009.04.019";
        when(itemService.getMetadataFirstValue(item, "dspace", "entity", "type", Item.ANY)).thenReturn("Publication");
        String template = provider.innerHtml(context, item);
        assertEquals(template, "{\"type\":\"Publication\",\"src\":\"//cdn.plu.mx/widget-popup.js\",\"href\":\"https://plu.mx/plum/a/?doi=" + provider.doiIdentifier + "\"}");
    }
}
