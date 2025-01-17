/**
 * The contents of this file are subject to the license and copyright
 * detailed in the LICENSE and NOTICE files at the root of the source
 * tree and available online at
 *
 * http://www.dspace.org/license/
 */
package org.dspace.app.rest;

import static com.jayway.jsonpath.matchers.JsonPathMatchers.hasJsonPath;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.ws.rs.core.MediaType;

import org.dspace.app.rest.model.patch.AddOperation;
import org.dspace.app.rest.model.patch.Operation;
import org.dspace.app.rest.model.patch.RemoveOperation;
import org.dspace.app.rest.test.AbstractControllerIntegrationTest;
import org.dspace.builder.CollectionBuilder;
import org.dspace.builder.CommunityBuilder;
import org.dspace.builder.EPersonBuilder;
import org.dspace.builder.GroupBuilder;
import org.dspace.builder.ItemBuilder;
import org.dspace.content.Collection;
import org.dspace.content.Item;
import org.dspace.content.edit.EditItem;
import org.dspace.content.service.ItemService;
import org.dspace.eperson.EPerson;
import org.dspace.eperson.Group;
import org.hamcrest.Matchers;
import org.junit.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * Test suite for the EditItem endpoint
 * 
 * @author Mykhaylo Boychuk (mykhaylo.boychuk at 4science.it)
 */
public class EditItemRestRepositoryIT extends AbstractControllerIntegrationTest {

    @Autowired
    private ItemService itemService;

    @Test
    public void findOneTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community")
                                          .build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1")
                                           .build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25")
                                .withAuthor("Smith, Maria")
                                .build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        // using "FIRST" mode
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + itemA.getID() + ":FIRST"))
                 .andExpect(status().isOk())
                 .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                         hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25")),
                         hasJsonPath("$['dc.title'][0].value", is("Title item A"))
                         )))
                 .andExpect(jsonPath("$.sections.titleAndIssuedDate['dc.contributor.author']").doesNotExist());

        // using "SECOND" mode for same item
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":SECOND"))
                 .andExpect(status().isOk())
                 .andExpect(jsonPath("$.sections.onlyTitle", Matchers.allOf(
                         hasJsonPath("$['dc.title'][0].value", is("Title item A"))
                         )))
                 .andExpect(jsonPath("$.sections.onlyTitle['dc.date.issued']").doesNotExist())
                 .andExpect(jsonPath("$.sections.onlyTitle['dc.contributor.author']").doesNotExist());

        // using special case "NONE" (not reported in edititem-service.xml configuration) mode for same item
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":none"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$._links.modes.href",
                                     is(REST_SERVER_URL +
                                             "core/edititems/" + editItem.getID() + ":none/modes")))
                             .andExpect(jsonPath("$.sections.onlyTitle['dc.title']").doesNotExist())
                             .andExpect(jsonPath("$.sections.onlyTitle['dc.date.issued']").doesNotExist())
                             .andExpect(jsonPath("$.sections.onlyTitle['dc.contributor.author']").doesNotExist());
    }

    @Test
    public void findOneModeConfigurationNotExistTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community")
                                          .build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1")
                                           .build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25")
                                .withAuthor("Smith, Maria")
                                .build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":NotExist"))
                             .andExpect(status().isNotFound());
    }

    @Test
    public void findOneItemNotExistTest() throws Exception {
        String tokenAdmin = getAuthToken(admin.getEmail(), password);
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + UUID.randomUUID() + ":FIRST"))
                             .andExpect(status().isNotFound());
    }

    @Test
    public void patchAddMetadataTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withSubmissionDefinition("modeA")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withIssueDate("2015-06-25")
                                .withAuthor("Mykhaylo, Boychuk").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        List<Map<String, String>> titelValues = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Title");
        titelValues.add(value);
        operations.add(new AddOperation("/sections/titleAndIssuedDate/dc.title", titelValues));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST")
                            .content(patchBody)
                            .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                            .andExpect(status().isOk())
                            .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                    hasJsonPath("$['dc.title'][0].value", is("New Title")),
                                    hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                    )));

        // verify that the patch changes have been persisted
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("New Title")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchAddMetadataUpdateExistValueTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withSubmissionDefinition("modeA")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title of item A")
                                .withIssueDate("2015-06-25").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> addTitle = new ArrayList<Operation>();
        List<Map<String, String>> values = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Title");
        values.add(value);
        addTitle.add(new AddOperation("/sections/titleAndIssuedDate/dc.title", values));

        String patchBody = getPatchContent(addTitle);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("New Title")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));

        // verify that the patch changes have been persisted
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("New Title")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchAddMultipleMetadataValuesTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withSubmissionDefinition("modeA")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title of item A")
                                .withIssueDate("2015-06-25").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        List<Map<String, String>> values = new ArrayList<Map<String, String>>();
        Map<String, String> value1 = new HashMap<String, String>();
        value1.put("value", "First Title");
        Map<String, String> value2 = new HashMap<String, String>();
        value2.put("value", "Second Title");
        values.add(value1);
        values.add(value2);

        operations.add(new AddOperation("/sections/onlyTitle/dc.title", values));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":SECOND")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.onlyTitle", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("First Title")),
                                     hasJsonPath("$['dc.title'][1].value", is("Second Title"))
                                     )))
                             .andExpect(jsonPath("$.sections.onlyTitle['dc.date.issued']").doesNotExist());

        // verify that the patch changes have been persisted
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":SECOND"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.onlyTitle", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("First Title")),
                                     hasJsonPath("$['dc.title'][1].value", is("Second Title"))
                                     )))
                             .andExpect(jsonPath("$.sections.onlyTitle['dc.date.issued']").doesNotExist());
    }

    @Test
    public void patchAddMetadataOnSectionNotExistentTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title of item A")
                                .withIssueDate("2015-06-25").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> addTitle = new ArrayList<Operation>();
        List<Map<String, String>> values = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Title");
        values.add(value);
        addTitle.add(new AddOperation("/sections/not-existing-section/dc.title", values));

        String patchBody = getPatchContent(addTitle);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isUnprocessableEntity());

        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("Title of item A")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchAddMetadataWrongPathOfMetadataTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> addTitle = new ArrayList<Operation>();
        List<Map<String, String>> values = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Title");
        values.add(value);
        addTitle.add(new AddOperation("/sections/titleAndIssuedDate/dc.not.existing", values));

        String patchBody = getPatchContent(addTitle);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isUnprocessableEntity());

        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("Title item A")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchAddMetadataIssuedDateOnModeSectionThatNotContainMetadataIssuedDateTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title of item A")
                                .withIssueDate("2015-06-25").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> newDate = new ArrayList<Operation>();
        List<Map<String, String>> values = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "2020-03-17");
        values.add(value);
        newDate.add(new AddOperation("/sections/onlyTitle/dc.date.issued", values));

        String patchBody = getPatchContent(newDate);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":SECOND")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isUnprocessableEntity());

        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("Title of item A")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchDeleteMetadataThatNotExistTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        operations.add(new RemoveOperation("/sections/titleAndIssuedDate/dc.not.existing/0"));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isUnprocessableEntity());

        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("Title item A")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchDeleteMetadataIssuedDateOnModeSectionThatNotContainMetadataIssuedDateTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title of item A")
                                .withIssueDate("2015-06-25").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        operations.add(new RemoveOperation("/sections/onlyTitle/dc.date.issued/0"));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":SECOND")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isUnprocessableEntity());

        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("Title of item A")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchDeleteAllMetadataOnModeSectionTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withSubmissionDefinition("modeA")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title of item A")
                                .withIssueDate("2015-06-25").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        operations.add(new RemoveOperation("/sections/onlyTitle"));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":SECOND")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isUnprocessableEntity());

        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":SECOND"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.onlyTitle", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is(itemA.getName()))
                                     )));
    }

    @Test
    public void findOneForbiddenTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community")
                                          .build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1")
                                           .build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25")
                                .withAuthor("Smith, Maria")
                                .build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenEperson = getAuthToken(eperson.getEmail(), password);

        getClient(tokenEperson).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                               .andExpect(status().isForbidden());

    }

    @Test
    public void findOneUnauthorizedTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community")
                                          .build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1")
                                           .build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25")
                                .withAuthor("Smith, Maria")
                                .build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        getClient().perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                   .andExpect(status().isUnauthorized());

    }

    @Test
    public void findOneOwnerOnlyForbiddenTest() throws Exception {
        context.turnOffAuthorisationSystem();

        EPerson userA = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Mykhaylo", "Boychuk")
                                      .withEmail("user.a@example.com")
                                      .withPassword(password).build();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community")
                                          .build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1")
                                           .build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25")
                                .withAuthor("Smith, Maria")
                                .build();

        itemService.addMetadata(context, itemA, "cris", "owner", null, null, userA.getID().toString());

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);
        String tokenEperson = getAuthToken(eperson.getEmail(), password);

        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-OWNER"))
                             .andExpect(status().isForbidden());

        getClient(tokenEperson).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-OWNER"))
                               .andExpect(status().isForbidden());
    }

    @Test
    public void findOneOwnerOnlyUnauthorizedTest() throws Exception {
        context.turnOffAuthorisationSystem();

        EPerson userA = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Mykhaylo", "Boychuk")
                                      .withEmail("user.a@example.com")
                                      .withPassword(password).build();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community")
                                          .build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1")
                                           .build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25")
                                .withAuthor("Smith, Maria")
                                .build();

        itemService.addMetadata(context, itemA, "cris", "owner", null, null, userA.getID().toString());

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        getClient().perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-OWNER"))
                   .andExpect(status().isUnauthorized());
    }

    @Test
    public void findOneOwnerOnlyTest() throws Exception {
        context.turnOffAuthorisationSystem();

        EPerson userA = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Mykhaylo", "Boychuk")
                                      .withEmail("user.a@example.com")
                                      .withPassword(password).build();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community")
                                          .build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1")
                                           .build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25")
                                .withAuthor("Smith, Maria")
                                .build();

        itemService.addMetadata(context, itemA, "cris", "owner", null, null, userA.getID().toString());

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenUserA = getAuthToken(userA.getEmail(), password);

        getClient(tokenUserA).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-OWNER"))
                 .andExpect(status().isOk())
                 .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                         hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25")),
                         hasJsonPath("$['dc.title'][0].value", is("Title item A"))
                         )))
                 .andExpect(jsonPath("$.sections.titleAndIssuedDate['dc.contributor.author']").doesNotExist());
    }

    @Test
    public void findOneCustomSecurityModeTest() throws Exception {
        context.turnOffAuthorisationSystem();

        EPerson userA = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Mykhaylo", "Boychuk")
                                      .withEmail("user.a@example.com")
                                      .withPassword(password).build();

        EPerson userB = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Simone", "Proni")
                                      .withEmail("user.b@example.com")
                                      .withPassword(password).build();

        Group groupA = GroupBuilder.createGroup(context)
                                   .withName("Group A")
                                   .addMember(userB).build();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community")
                                          .build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1")
                                           .build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("Title item A")
                                .withIssueDate("2015-06-25")
                                .withAuthor("Smith, Maria")
                                .build();

        itemService.addMetadata(context, itemA, "cris", "policy", "eperson", null, userA.getFullName(),
                                userA.getID().toString(), 600);
        itemService.addMetadata(context, itemA, "cris", "policy", "group", null, groupA.getName(),
                                groupA.getID().toString(), 600);

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenUserA = getAuthToken(userA.getEmail(), password);
        String tokenUserB = getAuthToken(userB.getEmail(), password);

        getClient(tokenUserA).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-CUSTOM"))
                 .andExpect(status().isOk())
                 .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                         hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25")),
                         hasJsonPath("$['dc.title'][0].value", is("Title item A"))
                         )))
                 .andExpect(jsonPath("$.sections.titleAndIssuedDate['dc.contributor.author']").doesNotExist());

        getClient(tokenUserB).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-CUSTOM"))
                 .andExpect(status().isOk())
                 .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                         hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25")),
                         hasJsonPath("$['dc.title'][0].value", is("Title item A"))
                         )))
                 .andExpect(jsonPath("$.sections.titleAndIssuedDate['dc.contributor.author']").doesNotExist());
    }

    @Test
    public void findOneAuthorCustomSecurityModeTest() throws Exception {

        context.turnOffAuthorisationSystem();

        EPerson firstUser = EPersonBuilder.createEPerson(context)
            .withNameInMetadata("First", "User")
            .withEmail("user1@example.com")
            .withPassword(password)
            .build();

        EPerson secondUser = EPersonBuilder.createEPerson(context)
            .withNameInMetadata("Second", "User")
            .withEmail("user2@example.com")
            .withPassword(password)
            .build();

        EPerson thirdUser = EPersonBuilder.createEPerson(context)
            .withNameInMetadata("Third", "User")
            .withEmail("user3@example.com")
            .withPassword(password)
            .build();

        parentCommunity = CommunityBuilder.createCommunity(context)
            .withName("Parent Community")
            .build();

        Collection collection = CollectionBuilder.createCollection(context, parentCommunity)
            .withEntityType("Publication")
            .withName("Collection 1")
            .build();

        Item author = ItemBuilder.createItem(context, collection)
            .withCrisOwner(firstUser)
            .build();

        Item editor = ItemBuilder.createItem(context, collection)
            .withCrisOwner(secondUser)
            .build();

        Item item = ItemBuilder.createItem(context, collection)
            .withTitle("Item title")
            .withIssueDate("2015-06-25")
            .withAuthor("First user", author.getID().toString())
            .withEditor("Second user", editor.getID().toString())
            .build();

        context.restoreAuthSystemState();

        getClient(getAuthToken(firstUser.getEmail(), password))
            .perform(get("/api/core/edititems/" + item.getID() + ":AUTHOR-CUSTOM"))
            .andExpect(status().isOk());

        getClient(getAuthToken(secondUser.getEmail(), password))
            .perform(get("/api/core/edititems/" + item.getID() + ":AUTHOR-CUSTOM"))
            .andExpect(status().isForbidden());

        getClient(getAuthToken(thirdUser.getEmail(), password))
            .perform(get("/api/core/edititems/" + item.getID() + ":AUTHOR-CUSTOM"))
            .andExpect(status().isForbidden());
    }

    @Test
    public void patchAddMetadataUsingSecurityConfigurationOwnerTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withSubmissionDefinition("modeA")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withIssueDate("2015-06-25")
                                .withAuthor("Mykhaylo, Boychuk").build();

        itemService.addMetadata(context, itemA, "cris", "owner", null, null, eperson.getID().toString());

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenOwner = getAuthToken(eperson.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        List<Map<String, String>> titelValues = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Title");
        titelValues.add(value);
        operations.add(new AddOperation("/sections/titleAndIssuedDate/dc.title", titelValues));

        String patchBody = getPatchContent(operations);
        getClient(tokenOwner).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST-OWNER")
                            .content(patchBody)
                            .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                            .andExpect(status().isOk())
                            .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                    hasJsonPath("$['dc.title'][0].value", is("New Title")),
                                    hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                    )));

        // verify that the patch changes have been persisted
        getClient(tokenOwner).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-OWNER"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("New Title")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchAddMetadataUsingSecurityConfigurationOwnerForbiddenTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withIssueDate("2015-06-25")
                                .withAuthor("Mykhaylo, Boychuk").build();

        itemService.addMetadata(context, itemA, "cris", "owner", null, null, eperson.getID().toString());

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenOwner = getAuthToken(eperson.getEmail(), password);
        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        List<Map<String, String>> titelValues = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Title");
        titelValues.add(value);
        operations.add(new AddOperation("/sections/titleAndIssuedDate/dc.title", titelValues));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST-OWNER")
                            .content(patchBody)
                            .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                            .andExpect(status().isForbidden());

        getClient(tokenOwner).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-OWNER"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )))
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate['dc.title']").doesNotExist());
    }

    @Test
    public void patchAddMetadataUsingSecurityConfigurationCustomTest() throws Exception {
        context.turnOffAuthorisationSystem();

        EPerson userA = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Mykhaylo", "Boychuk")
                                      .withEmail("user.a@example.com")
                                      .withPassword(password).build();

        EPerson userB = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Simone", "Proni")
                                      .withEmail("user.b@example.com")
                                      .withPassword(password).build();

        Group groupA = GroupBuilder.createGroup(context)
                                   .withName("Group A")
                                   .addMember(userB).build();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withSubmissionDefinition("modeA")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withIssueDate("2015-06-25")
                                .withAuthor("Mykhaylo, Boychuk").build();

        itemService.addMetadata(context, itemA, "cris", "policy", "eperson", null, userA.getFullName(),
                                userA.getID().toString(), 600);
        itemService.addMetadata(context, itemA, "cris", "policy", "group", null, groupA.getName(),
                                groupA.getID().toString(), 600);

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenUserA = getAuthToken(userA.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        List<Map<String, String>> titelValues = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Title");
        titelValues.add(value);
        operations.add(new AddOperation("/sections/titleAndIssuedDate/dc.title", titelValues));

        String patchBody = getPatchContent(operations);
        getClient(tokenUserA).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST-CUSTOM")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                    hasJsonPath("$['dc.title'][0].value", is("New Title")),
                                    hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                    )));

        getClient(tokenUserA).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-CUSTOM"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("New Title")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )));
    }

    @Test
    public void patchAddMetadataUsingSecurityConfigurationCustomForbiddenTest() throws Exception {
        context.turnOffAuthorisationSystem();

        EPerson userA = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Mykhaylo", "Boychuk")
                                      .withEmail("user.a@example.com")
                                      .withPassword(password).build();

        EPerson userB = EPersonBuilder.createEPerson(context)
                                      .withNameInMetadata("Simone", "Proni")
                                      .withEmail("user.b@example.com")
                                      .withPassword(password).build();

        Group groupA = GroupBuilder.createGroup(context)
                                   .withName("Group A")
                                   .addMember(userB).build();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withIssueDate("2015-06-25")
                                .withAuthor("Mykhaylo, Boychuk").build();

        itemService.addMetadata(context, itemA, "cris", "policy", "eperson", null, userA.getFullName(),
                                userA.getID().toString(), 600);
        itemService.addMetadata(context, itemA, "cris", "policy", "group", null, groupA.getName(),
                                groupA.getID().toString(), 600);

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenUserA = getAuthToken(userA.getEmail(), password);
        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        List<Map<String, String>> titelValues = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Title");
        titelValues.add(value);
        operations.add(new AddOperation("/sections/titleAndIssuedDate/dc.title", titelValues));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST-CUSTOM")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isForbidden());

        getClient(tokenUserA).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST-CUSTOM"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2015-06-25"))
                                     )))
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate['dc.title']").doesNotExist());
    }

    @Test
    public void patchRemoveMandatoryMetadataTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withSubmissionDefinition("modeA")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("My Title")
                                .withIssueDate("2021-11-11")
                                .withAuthor("Mykhaylo, Boychuk")
                                .build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();
        List<Operation> operations2 = new ArrayList<Operation>();

        List<Map<String, String>> abstractValues = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Abstract");
        abstractValues.add(value);

        operations.add(new RemoveOperation("/sections/titleAndIssuedDate/dc.title/0"));
        operations.add(new AddOperation("/sections/titleAndIssuedDate/dc.description.abstract", abstractValues));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isUnprocessableEntity())
                             .andExpect(jsonPath("$.[0].message", is("error.validation.required")))
                             .andExpect(jsonPath("$.[0].paths[0]", is("/sections/titleAndIssuedDate/dc.title")));

        // verify that the patch changes have not been persisted
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is(itemA.getName())),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2021-11-11"))
                                     )))
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate['dc.description.abstract']")
                             .doesNotExist());

        operations2.add(new AddOperation("/sections/titleAndIssuedDate/dc.description.abstract", abstractValues));
        operations2.add(new RemoveOperation("/sections/titleAndIssuedDate/dc.title/0"));

        String patchBody2 = getPatchContent(operations2);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST")
                             .content(patchBody2)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isUnprocessableEntity())
                             .andExpect(jsonPath("$.[0].message", is("error.validation.required")))
                             .andExpect(jsonPath("$.[0].paths[0]", is("/sections/titleAndIssuedDate/dc.title")));

        // verify that the patch changes have not been persisted
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is(itemA.getName())),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2021-11-11"))
                                     )))
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate['dc.description.abstract']")
                             .doesNotExist());
    }

    @Test
    public void patchRemoveAndAddMandatoryMetadataTest() throws Exception {
        context.turnOffAuthorisationSystem();

        parentCommunity = CommunityBuilder.createCommunity(context)
                                          .withName("Parent Community").build();

        Collection col1 = CollectionBuilder.createCollection(context, parentCommunity)
                                           .withEntityType("Publication")
                                           .withSubmissionDefinition("modeA")
                                           .withName("Collection 1").build();

        Item itemA = ItemBuilder.createItem(context, col1)
                                .withTitle("My Title")
                                .withIssueDate("2021-11-11")
                                .withAuthor("Mykhaylo, Boychuk").build();

        EditItem editItem = new EditItem(context, itemA);

        context.restoreAuthSystemState();

        String tokenAdmin = getAuthToken(admin.getEmail(), password);

        List<Operation> operations = new ArrayList<Operation>();

        List<Map<String, String>> abstractValues = new ArrayList<Map<String, String>>();
        Map<String, String> value = new HashMap<String, String>();
        value.put("value", "New Abstract");
        abstractValues.add(value);

        List<Map<String, String>> titleValues = new ArrayList<Map<String, String>>();
        Map<String, String> titleValue = new HashMap<String, String>();
        titleValue.put("value", "New TITLE");
        titleValues.add(titleValue);

        operations.add(new RemoveOperation("/sections/titleAndIssuedDate/dc.title/0"));
        operations.add(new AddOperation("/sections/titleAndIssuedDate/dc.description.abstract", abstractValues));
        operations.add(new AddOperation("/sections/titleAndIssuedDate/dc.title", titleValues));

        String patchBody = getPatchContent(operations);
        getClient(tokenAdmin).perform(patch("/api/core/edititems/" + editItem.getID() + ":FIRST")
                             .content(patchBody)
                             .contentType(MediaType.APPLICATION_JSON_PATCH_JSON))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("New TITLE")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2021-11-11")),
                                     hasJsonPath("$['dc.description.abstract'][0].value", is("New Abstract"))
                                     )));

        // verify that the patch changes have been persisted
        getClient(tokenAdmin).perform(get("/api/core/edititems/" + editItem.getID() + ":FIRST"))
                             .andExpect(status().isOk())
                             .andExpect(jsonPath("$.sections.titleAndIssuedDate", Matchers.allOf(
                                     hasJsonPath("$['dc.title'][0].value", is("New TITLE")),
                                     hasJsonPath("$['dc.date.issued'][0].value", is("2021-11-11")),
                                     hasJsonPath("$['dc.description.abstract'][0].value", is("New Abstract"))
                                     )));
    }

}
