/**
 * The contents of this file are subject to the license and copyright
 * detailed in the LICENSE and NOTICE files at the root of the source
 * tree and available online at
 *
 * http://www.dspace.org/license/
 */
package org.dspace.app.rest.converter;

import java.util.ArrayList;
import java.util.List;

import org.dspace.app.rest.model.BitstreamRest;
import org.dspace.app.rest.model.ItemRest;
import org.dspace.content.Bitstream;
import org.dspace.content.Bundle;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * This is the converter from/to the Item in the DSpace API data model and the
 * REST data model
 * 
 * @author Andrea Bollini (andrea.bollini at 4science.it)
 *
 */
@Component
public class ItemConverter extends DSpaceObjectConverter<org.dspace.content.Item, org.dspace.app.rest.model.ItemRest> {
	@Autowired
	private CollectionConverter collectionConverter;
	@Autowired
	private BitstreamConverter bitstreamConverter;

	@Override
	public ItemRest fromModel(org.dspace.content.Item obj) {
		ItemRest item = super.fromModel(obj);
		item.setInArchive(obj.isArchived());
		item.setDiscoverable(obj.isDiscoverable());
		item.setWithdrawn(obj.isWithdrawn());
		item.setLastModified(obj.getLastModified());
		try {
			//item.setTemplateItemOf(collectionConverter.fromModel(obj.getTemplateItemOf()));
		} catch (Exception e) {
			e.printStackTrace();
		}
		try {
			//item.setOwningCollection(collectionConverter.fromModel(obj.getOwningCollection()));
		} catch (Exception e) {
			e.printStackTrace();
		}
		List<BitstreamRest> bitstreams = new ArrayList<BitstreamRest>();
		for (Bundle bun : obj.getBundles()) {
			for (Bitstream bit : bun.getBitstreams()) {
				BitstreamRest bitrest = bitstreamConverter.fromModel(bit);
				bitstreams.add(bitrest);
			}
		}
		item.setBitstreams(bitstreams);
		return item;
	}

	@Override
	public org.dspace.content.Item toModel(ItemRest obj) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	protected ItemRest newInstance() {
		return new ItemRest();
	}

}
