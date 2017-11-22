<%--

    The contents of this file are subject to the license and copyright
    detailed in the LICENSE and NOTICE files at the root of the source
    tree and available online at

    http://www.dspace.org/license/

--%>
<%--
  - Edit metadata form
  -
  - Attributes to pass in to this page:
  -    submission.info   - the SubmissionInfo object
  -    submission.inputs - the DCInputSet
  -    submission.page   - the step in submission
  --%>
<%@ page contentType="text/html;charset=UTF-8" %>

<%@page import="java.util.UUID"%>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.Iterator" %>
<%@ page import="java.util.List" %>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>

<%@ page import="javax.servlet.jsp.jstl.fmt.LocaleSupport" %>
<%@ page import="javax.servlet.jsp.PageContext" %>

<%@page import="org.dspace.content.MetadataValue"%>
<%@ page import="org.dspace.core.Context" %>
<%@ page import="org.dspace.app.util.DCInput" %>
<%@ page import="org.dspace.app.util.DCInputSet" %>
<%@ page import="org.dspace.app.webui.servlet.SubmissionController" %>
<%@ page import="org.dspace.submit.AbstractProcessingStep" %>
<%@ page import="org.dspace.core.I18nUtil" %>
<%@ page import="org.dspace.app.util.SubmissionInfo" %>
<%@ page import="org.dspace.app.webui.util.UIUtil" %>
<%@ page import="org.dspace.content.authority.Choices" %>
<%@ page import="org.dspace.core.ConfigurationManager" %>
<%@ page import="org.dspace.core.Utils" %>
<%@ page import="org.dspace.workflow.WorkflowItemService"%>
<%@ page import="org.dspace.workflow.WorkflowItem" %>
<%@ page import="java.util.Calendar"%>
<%@ page import="java.util.Locale"%>
<%@ page import="org.apache.commons.lang3.StringUtils"%>
<%@ page import="org.dspace.content.authority.factory.ContentAuthorityServiceFactory" %>
<%@ page import="org.dspace.content.authority.service.ChoiceAuthorityService" %>
<%@ page import="org.dspace.content.authority.service.MetadataAuthorityService" %>
<%@ page import="org.dspace.content.*" %>
<%@ page import="org.dspace.content.factory.ContentServiceFactory" %>
<%@ page import="java.io.IOException" %>
<%@ page import="org.dspace.workflowbasic.service.BasicWorkflowService" %>

<%@ taglib uri="http://www.dspace.org/dspace-tags.tld" prefix="dspace" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c"%>
<%
    request.setAttribute("LanguageSwitch", "hide");

    Map<String,List<DCInput>> parent2child = new HashMap<String,List<DCInput>>();
    
    
%>
<%!// required by Controlled Vocabulary  add-on and authority addon
        String contextPath;

	Locale lcl;
    // An unknown value of confidence for new, empty input fields,
    // so no icon appears yet.
    int unknownConfidence = Choices.CF_UNSET - 100;
    
		

    // This method is resposible for showing a link next to an input box
    // that pops up a window that to display a controlled vocabulary.
    // It should be called from the doOneBox and doTwoBox methods.
    // It must be extended to work with doTextArea.
    String doControlledVocabulary(String fieldName, PageContext pageContext, String vocabulary, boolean readonly)
    {
        String link = "";
        boolean enabled = ConfigurationManager.getBooleanProperty("webui.controlledvocabulary.enable");
        boolean useWithCurrentField = vocabulary != null && ! "".equals(vocabulary);
        
        if (enabled && useWithCurrentField && !readonly)
        {
                        // Deal with the issue of _0 being removed from fieldnames in the configurable submission system
                        if (fieldName.endsWith("_0"))
                        {
                                fieldName = fieldName.substring(0, fieldName.length() - 2);
                        }
                        link = 
                        "<a href='javascript:void(null);' onclick='javascript:popUp(\"" +
                                contextPath + "/controlledvocabulary/controlledvocabulary.jsp?ID=" +
                                fieldName + "&amp;vocabulary=" + vocabulary + "\")'>" +
                                        "<span class='controlledVocabularyLink'>" +
                                                LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.controlledvocabulary") +
                                        "</span>" +
                        "</a>";
                }

                return link;
    }

    boolean hasVocabulary(String vocabulary)
    {
        boolean enabled = ConfigurationManager.getBooleanProperty("webui.controlledvocabulary.enable");
        boolean useWithCurrentField = vocabulary != null && !"".equals(vocabulary);
        boolean has = false;
        
        if (enabled && useWithCurrentField)
        {
                has = true;
        }
        return has;
    }

    // is this field going to be rendered as Choice-driven <select>?
    boolean isSelectable(String fieldKey)
    {
        ChoiceAuthorityService cam = ContentAuthorityServiceFactory.getInstance().getChoiceAuthorityService();
        return (cam.isChoicesConfigured(fieldKey) &&
            "select".equals(cam.getPresentation(fieldKey)));
    }

    // Get the presentation type of the authority if any, null otherwise
    String getAuthorityType(PageContext pageContext, String fieldName, Collection collection)
    {
        MetadataAuthorityService mam = ContentAuthorityServiceFactory.getInstance().getMetadataAuthorityService();
        ChoiceAuthorityService cam = ContentAuthorityServiceFactory.getInstance().getChoiceAuthorityService();
        StringBuffer sb = new StringBuffer();

        if (cam.isChoicesConfigured(fieldName))
        {
        	return cam.getPresentation(fieldName);
        }
        return null;
    }

    
    StringBuffer doChildInput(Item item,DCInput child,int count,int fieldCount, boolean repeatable,boolean readonly, int fieldCountIncr, PageContext pageContext,Collection collection, boolean last, boolean language, List<String> valueLanguageList){
      
      StringBuffer sb = new StringBuffer();
    	
	  String childSchema = child.getSchema();
	  String childElement = child.getElement();
	  String childQualifier = child.getQualifier();
	  List<IMetadataValue> meta = item.getMetadata(childSchema, childElement, childQualifier, Item.ANY);
	  
	  String childFieldName="";
	  if (childQualifier != null && !childQualifier.equals("*"))
           childFieldName = childSchema + "_" + childElement + '_' + childQualifier;
	  else
           childFieldName = childSchema + "_" + childElement;
	  String childAuthorityType = getAuthorityType(pageContext, childFieldName, collection);
	  
	  sb.append("<label class=\"col-md-12"+ (child.isRequired()?" label-required":"") +"\">").append(child.getLabel()).append("</label>");
	  String inputType = child.getInputType();
	  if(StringUtils.equals(inputType, "name")){
			sb.append(doPersonalNameInput(meta, count, childAuthorityType, fieldCount, childFieldName, childSchema, childElement, 
					childQualifier, repeatable, child.isRequired(), readonly, fieldCountIncr, pageContext, collection, true));
	  }
	  else if(StringUtils.equals(inputType, "date")){
		  sb.append(doDateInput(meta, count, fieldCount, childFieldName, childSchema, childElement, 
				  childQualifier, repeatable, child.isRequired(), readonly, fieldCountIncr, pageContext, collection, true));
	  }
	  else if(StringUtils.equals(inputType, "textarea")){
		  sb.append(doTextAreaInput(meta, count, childAuthorityType, fieldCount, childFieldName, childSchema, childElement, 
				  childQualifier, repeatable, child.isRequired(), readonly, fieldCountIncr, pageContext, child.getVocabulary(),
				  child.isClosedVocabulary(), collection, language, valueLanguageList, true));		  
	  }
	  else if(StringUtils.equals(inputType, "number")){
		  sb.append(doNumberInput(meta, count, childAuthorityType, fieldCount, childFieldName, childSchema, childElement, 
				  childQualifier, repeatable, child.isRequired(), readonly, fieldCountIncr, pageContext, collection, true));
	  }	  
	  else{
	  		sb.append(doOneBoxInput(meta, count, childAuthorityType, fieldCount, childFieldName, childSchema, childElement, 
			  childQualifier, repeatable, child.isRequired(), readonly, fieldCountIncr, pageContext, child.getVocabulary(), 
			  child.isClosedVocabulary(), collection, language, valueLanguageList, true));
	  }
	  
      if(last){
          sb.append("<hr class=\"metadata-divider col-md-offset-1 col-md-10\"/>");
      }

	  return sb;
    }
    // Render the choice/authority controlled entry, or, if not indicated,
    // returns the given default inputBlock
    StringBuffer doAuthority(PageContext pageContext, String fieldName,
            int idx, int fieldCount, String fieldInput, String authorityValue,
            int confidenceValue, boolean isName, boolean repeatable,
            List<IMetadataValue> dcvs, StringBuffer inputBlock, Collection collection)
    {
        MetadataAuthorityService mam = ContentAuthorityServiceFactory.getInstance().getMetadataAuthorityService();
        ChoiceAuthorityService cam = ContentAuthorityServiceFactory.getInstance().getChoiceAuthorityService();
        StringBuffer sb = new StringBuffer();

        if (cam.isChoicesConfigured(fieldName))
        {
            boolean authority = mam.isAuthorityControlled(fieldName);
            boolean required = authority && mam.isAuthorityRequired(fieldName);
            boolean isSelect = "select".equals(cam.getPresentation(fieldName)) && !isName;
            boolean isNone = "none".equals(cam.getPresentation(fieldName));

            // if this is not the only or last input, append index to input @names
            String authorityName = fieldName + "_authority";
            String confidenceName = fieldName + "_confidence";
            if (repeatable && !isSelect && idx != fieldCount-1)
            {
                fieldInput += '_'+String.valueOf(idx+1);
                authorityName += '_'+String.valueOf(idx+1);
                confidenceName += '_'+String.valueOf(idx+1);
            }

            String confidenceSymbol = confidenceValue == unknownConfidence ? "blank" : Choices.getConfidenceText(confidenceValue).toLowerCase();
            String confIndID = fieldInput+"_confidence_indicator_id";
            
            if (authority)
            { 
                if (!isSelect && !isNone) {
	            	sb.append(" <img id=\""+confIndID+"\" title=\"")
	                  .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.authority.confidence.description."+confidenceSymbol))
	                  .append("\" class=\"pull-left ds-authority-confidence cf-")                  
	                  // set confidence to cf-blank if authority is empty
	                  .append(authorityValue==null||authorityValue.length()==0 ? "blank" : confidenceSymbol)
	                  .append(" \" src=\"").append(contextPath).append("/image/confidence/invisible.gif\" />");
                }
                   
                sb.append("<input type=\"text\" value=\"").append(authorityValue!=null?authorityValue:"")
                  .append("\" id=\"").append(authorityName)
                  .append("\" name=\"").append(authorityName).append("\" class=\"ds-authority-value form-control\"/>")
                  .append("<input type=\"hidden\" value=\"").append(confidenceSymbol)
                  .append("\" id=\"").append(confidenceName)
                  .append("\" name=\"").append(confidenceName)
                  .append("\" class=\"ds-authority-confidence-input\"/>");
                  
                
            }

            // suggest is not supported for name input type
            if ("suggest".equals(cam.getPresentation(fieldName)) && !isName)
            {
                if (inputBlock != null)
                    sb.insert(0, inputBlock);
                sb.append("<span id=\"").append(fieldInput).append("_indicator\" style=\"display: none;\">")
                  .append("<img src=\"").append(contextPath).append("/image/authority/load-indicator.gif\" alt=\"Loading...\"/>")
                  .append("</span><div id=\"").append(fieldInput).append("_autocomplete\" class=\"autocomplete\" style=\"display: none;\"> </div>");

                sb.append("<script type=\"text/javascript\">")
                  .append("var gigo = DSpaceSetupAutocomplete('edit_metadata',")
                  .append("{ metadataField: '").append(fieldName).append("', isClosed: '").append(required?"true":"false").append("', inputName: '")
                  .append(fieldInput).append("', authorityName: '").append(authorityName).append("', containerID: '")
                  .append(fieldInput).append("_autocomplete', indicatorID: '").append(fieldInput).append("_indicator', ")
                  .append("contextPath: '").append(contextPath)
                  .append("', confidenceName: '").append(confidenceName)
                  .append("', confidenceIndicatorID: '").append(confIndID)
                  .append("', collection: '").append(String.valueOf(collection.getID()))
                        .append("' }); </script>");
            }

            // put up a SELECT element containing all choices
            else if (isSelect)
            {
                sb.append("<select class=\"form-control\" id=\"").append(fieldInput)
                   .append("_id\" name=\"").append(fieldInput)
                   .append("\" size=\"").append(String.valueOf(repeatable ? 6 : 1))
                   .append(repeatable ? "\" multiple>\n" :"\">\n");
                Choices cs = cam.getMatches(fieldName, "", collection, 0, 0, null);
                // prepend unselected empty value when nothing can be selected.
                if (!repeatable && cs.defaultSelected < 0 && dcvs.size() == 0)
                    sb.append("<option value=\"\"><!-- empty --></option>\n");
                for (int i = 0; i < cs.values.length; ++i)
                {
                    boolean selected = false;
                    for (IMetadataValue dcv : dcvs)
                    {
                        if ((dcv.getAuthority() == null && dcv.getValue().equals(StringUtils.trim(cs.values[i].value))) ||
                        		(dcv.getAuthority() != null && dcv.getAuthority().equals(StringUtils.trim(cs.values[i].authority))))
                            selected = true;
                    }
                    sb.append("<option value=\"")
                      .append(cs.values[i].value.replaceAll("\"", "\\\""))
                      .append("\"")
                      .append(selected ? " selected>":">")
                      .append(cs.values[i].label).append("</option>\n");
                }
                sb.append("</select>\n");
            }

              // use lookup for any other presentation style (i.e "select")
            else if (!isNone)
            {
                if (inputBlock != null)
                    sb.insert(0, inputBlock);
                sb.append("<button class=\"btn btn-default\" name=\"").append(fieldInput).append("_lookup\" ")
                  .append("onclick=\"javascript: return DSpaceChoiceLookup('")
                  .append(contextPath).append("/tools/lookup.jsp','")
                  .append(fieldName).append("','edit_metadata','")
                  .append(fieldInput).append("','").append(authorityName).append("','")
                  .append(confIndID).append("',")
                  .append("'"+String.valueOf(collection.getID())+"'").append(",")
                  .append(String.valueOf(isName)).append(",false);\"")
                        .append(" title=\"")
                  .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.tools.lookup.lookup"))
                  .append("\"><span class=\"glyphicon glyphicon-search\"></span></button>");
            }
            
        }
        else if (inputBlock != null)
            sb = inputBlock;
        return sb;
    }

    void doPersonalName(javax.servlet.jsp.JspWriter out, Item item,
      String fieldName, String schema, String element, String qualifier, boolean repeatable, boolean required,
      boolean readonly, int fieldCountIncr, String label, PageContext pageContext, Collection collection, boolean language, List<String> valueLanguageList, List<DCInput> children, boolean hasParent)
      throws java.io.IOException
    {
   	  String authorityType = getAuthorityType(pageContext, fieldName, collection);
    	
      List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema, element, qualifier, Item.ANY);
      int fieldCount = defaults.size() + fieldCountIncr;
      StringBuffer headers = new StringBuffer();
      StringBuffer sb = new StringBuffer();

      
      if (fieldCount == 0)
         fieldCount = 1;

      sb.append("<div class=\"row\">");
      for (int i = 0; i < fieldCount; i++)
      {
          sb.append("<label class=\"col-md-2"+ (required?" label-required":"") +"\">").append(label).append("</label>");
    	  sb.append("<div class=\"col-md-10\">");     

    	  sb.append(doPersonalNameInput(defaults,i,authorityType, fieldCount, fieldName, schema, element, 
    	    		 qualifier, repeatable,  required,  readonly, fieldCountIncr, pageContext,collection,hasParent) );
    	  if(children !=null){
    	      int countChild = 1;
	    	  for(DCInput child: children){
	    		  sb.append(doChildInput(item,child, i, fieldCount, repeatable,readonly,fieldCountIncr, pageContext, collection, children.size()==countChild, language, valueLanguageList));
	    		  countChild++;
	    	  }
    	  }
    	  sb.append("</div>");
      }
      
	  sb.append("</div><br/>");
      out.write(sb.toString());
    }

    StringBuffer doPersonalNameInput( List<IMetadataValue> defaults,int count,String authorityType,int fieldCount, String fieldName, String schema, String element, 
    		String qualifier, boolean repeatable, boolean required, boolean readonly, int fieldCountIncr, PageContext pageContext,Collection collection,boolean hasParent){
        
    	org.dspace.content.DCPersonName dpn;
    	String auth;
        int conf = 0;
        StringBuffer name = new StringBuffer();
        StringBuffer first = new StringBuffer();
        StringBuffer last = new StringBuffer();
        StringBuffer sb = new StringBuffer();

	   	 sb.append("<div class=\"row col-md-12\">");
	   	 if ("lookup".equalsIgnoreCase(authorityType))
	   	 {
	   	 	sb.append("<div class=\"row col-md-10\">");
	   	 }
	        first.setLength(0);
	        first.append(fieldName).append("_first");
	        if (repeatable && count != fieldCount-1)
	           first.append('_').append(count+1);
	
	        last.setLength(0);
	        last.append(fieldName).append("_last");
	        if (repeatable && count != fieldCount-1)
	           last.append('_').append(count+1);
	
	        if (count < defaults.size())
	        {
	           dpn = new org.dspace.content.DCPersonName(defaults.get(count).getValue());
	           auth = defaults.get(count).getAuthority();
	           conf = defaults.get(count).getConfidence();
	        }
	        else
	        {
	           dpn = new org.dspace.content.DCPersonName();
	           auth = "";
	           conf = unknownConfidence;
	        }
	        
	        sb.append("<span class=\"col-md-5\"><input placeholder=\"")
	          .append(Utils.addEntities(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.lastname")))
	          .append("\" class=\"form-control\" type=\"text\" name=\"")
	          .append(last.toString())
	          .append("\" size=\"23\" ");
	        if (readonly)
	        {
	            sb.append("disabled=\"disabled\" ");
	        }
	        sb.append("value=\"")
	          .append(dpn.getLastName().replaceAll("\"", "&quot;")) // Encode "
	                  .append("\"/></span><span class=\"col-md-5\"><input placeholder=\"")
	                  .append(Utils.addEntities(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.firstname")))
	                  .append("\" class=\"form-control\" type=\"text\" name=\"")
	                  .append(first.toString())
	          .append("\" size=\"23\" ");
	        if (readonly)
	        {
	            sb.append("disabled=\"disabled\" ");
	        }
	        sb.append("value=\"")
	          .append(dpn.getFirstNames()).append("\"/></span>");         
	        
	        if ("lookup".equalsIgnoreCase(authorityType))
	   	 {
	            sb.append(doAuthority(pageContext, fieldName, count, fieldCount, fieldName,
	                    auth, conf, true, repeatable, defaults, null, collection));
	            sb.append("</div>");
	   	 }
	        
	
	        if (!hasParent && repeatable && !readonly && count < defaults.size())
	        {
	           name.setLength(0);
	           name.append(Utils.addEntities(dpn.getLastName()))
	               .append(' ')
	               .append(Utils.addEntities(dpn.getFirstNames()));
	           // put a remove button next to filled in values
	           sb.append("<button class=\"btn btn-danger pull-right col-md-2\" name=\"submit_")
	             .append(fieldName)
	             .append("_remove_")
	             .append(count)
	             .append("\" value=\"")
	             .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove"))
	             .append("\"><span class=\"glyphicon glyphicon-trash\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove")+"</button>");
	        }
	        else if (!hasParent && repeatable && !readonly && count == fieldCount - 1)
	        {
	           // put a 'more' button next to the last space
	           sb.append("<button class=\"btn btn-default pull-right col-md-2\" name=\"submit_")
	             .append(fieldName)
	             .append("_add\" value=\"")
	             .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add"))
	             .append("\"><span class=\"glyphicon glyphicon-plus\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add")+"</button>");
	        }         
	        sb.append("</div>");   
     return sb;
    	
    }
    
    void doYear(boolean allowInPrint, javax.servlet.jsp.JspWriter out, Item item,
            String fieldName, String schema, String element, String qualifier, boolean repeatable, boolean required,
            boolean readonly, int fieldCountIncr, String label, PageContext pageContext, List<DCInput> children,boolean hasParent)
			throws java.io.IOException {
    	List<String> valuePair = new ArrayList<String>();
    	// display value
    	valuePair.add(LocaleSupport.getLocalizedMessage(
				pageContext, "jsp.submit.edit-metadata.year.select"));
    	// store value
		valuePair.add("");
		
    	if (allowInPrint) {
	    	// display value
	    	valuePair.add(LocaleSupport.getLocalizedMessage(
					pageContext, "jsp.submit.edit-metadata.year.unpublished"));
	    	// store value
			valuePair.add("9999");
    	}
    	
		int minYear = ConfigurationManager.getIntProperty("submission.date.min-year", 1950);
		
		int maxYear = Calendar.getInstance().get(Calendar.YEAR) 
				+ ConfigurationManager.getIntProperty("submission.date.new-years", 0);
		
    	for (int i=maxYear; i >= minYear; i--)
    	{
    		// display value
    		valuePair.add(String.valueOf(i));
    		// store value
    		valuePair.add(String.valueOf(i));
    	}
    	
    	doDropDown(out, item, fieldName, schema, element, qualifier, repeatable,
	  	      required, readonly, valuePair, label,children,hasParent);
	}
    
    void doDate(javax.servlet.jsp.JspWriter out, Item item,
      String fieldName, String schema, String element, String qualifier, boolean repeatable, boolean required,
      boolean readonly, int fieldCountIncr, String label, PageContext pageContext, Collection collection, boolean language, List<String> valueLanguageList, List<DCInput> children, boolean hasParent)
      throws java.io.IOException
    {

      List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema, element, qualifier, Item.ANY);
      int fieldCount = defaults.size() + fieldCountIncr;
      StringBuffer sb = new StringBuffer();

      if (fieldCount == 0)
         fieldCount = 1;

      sb.append("<div class=\"row\">");
      
      for (int i = 0; i < fieldCount; i++)
      {
    	  sb.append("<label class=\"col-md-2"+ (required?" label-required":"") +"\">")
      .append(label)
      .append("</label><div class=\"col-md-10\">");
    	  sb.append(doDateInput(defaults,i, fieldCount, fieldName,  schema,  element, qualifier, 
			   		 repeatable, required, readonly, fieldCountIncr, pageContext, collection,hasParent));
	    	if(children !=null){
	    	      int countChild = 1;    
		    	  for(DCInput child: children){
		    		  sb.append(doChildInput(item,child, i, fieldCount,repeatable,readonly, fieldCountIncr, pageContext, collection, children.size()==countChild, language, valueLanguageList));
		    		  countChild++;
		    	  }
	    	}
	    	sb.append("</div>");
      }
      sb.append("</div><br/>");
      out.write(sb.toString());
    }

    StringBuffer doDateInput(List<IMetadataValue> defaults,int count,int fieldCount, String fieldName, String schema, String element, 
    		String qualifier, boolean repeatable, boolean required, boolean readonly, int fieldCountIncr, PageContext pageContext,Collection collection,boolean hasParent){

    	StringBuffer sb = new StringBuffer();
    	org.dspace.content.DCDate dateIssued;
    	
        if (count < defaults.size())
           dateIssued = new org.dspace.content.DCDate(defaults.get(count).getValue());
        else
           dateIssued = new org.dspace.content.DCDate("");
   
        sb.append("<div class=\"row col-md-12\"><div class=\"input-group col-md-10\"><div class=\"row\">")
			.append("<span class=\"input-group col-md-6\"><span class=\"input-group-addon\">")
        	.append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.month"))
           .append("</span><select class=\"form-control\" name=\"")
           .append(fieldName)
           .append("_month");
        
        if(repeatable && hasParent && count==0)
        	count=1;
        
        
        if (repeatable && count>0)
        {
           sb.append('_').append(count);
        }
        if (readonly)
        {
            sb.append("\" disabled=\"disabled");
        }
        sb.append("\"><option value=\"-1\"")
           .append((dateIssued.getMonth() == -1 ? " selected=\"selected\"" : ""))
//         .append(">(No month)</option>");
           .append(">")
           .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.no_month"))
           .append("</option>");
           
        for (int j = 1; j < 13; j++)
        {
           sb.append("<option value=\"")
             .append(j)
             .append((dateIssued.getMonth() == j ? "\" selected=\"selected\"" : "\"" ))
             .append(">")
             .append(org.dspace.content.DCDate.getMonthName(j,I18nUtil.getSupportedLocale(lcl)))
             .append("</option>");
        }
   
        sb.append("</select></span>")
	            .append("<span class=\"input-group col-md-2\"><span class=\"input-group-addon\">")
               .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.day"))
               .append("</span><input class=\"form-control\" type=\"text\" name=\"")
           .append(fieldName)
           .append("_day");
        if (repeatable && count>0)
           sb.append("_").append(count);
        if (readonly)
        {
            sb.append("\" disabled=\"disabled");
        }
        sb.append("\" size=\"2\" maxlength=\"2\" value=\"")
           .append((dateIssued.getDay() > 0 ?
                    String.valueOf(dateIssued.getDay()) : "" ))
               .append("\"/></span><span class=\"input-group col-md-4\"><span class=\"input-group-addon\">")
               .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.year"))
               .append("</span><input class=\"form-control\" type=\"text\" name=\"")
           .append(fieldName)
           .append("_year");
        if (repeatable && count>0)
           sb.append("_").append(count);
        if (readonly)
        {
            sb.append("\" disabled=\"disabled");
        }
        sb.append("\" size=\"4\" maxlength=\"4\" value=\"")
           .append((dateIssued.getYear() > 0 ?
                String.valueOf(dateIssued.getYear()) : "" ))
           .append("\"/></span></div></div>\n");
   
        if (!hasParent && repeatable && !readonly && count < defaults.size())
        {
           // put a remove button next to filled in values
           sb.append("<button class=\"btn btn-danger col-md-2\" name=\"submit_")
             .append(fieldName)
             .append("_remove_")
             .append(count)
             .append("\" value=\"")
             .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove"))
             .append("\"><span class=\"glyphicon glyphicon-trash\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove")+"</button>");
        }
        else if (!hasParent && repeatable && !readonly && count == fieldCount - 1)
        {
           // put a 'more' button next to the last space
           sb.append("<button class=\"btn btn-default col-md-2\" name=\"submit_")
             .append(fieldName)
             .append("_add\" value=\"")
             .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add"))
             .append("\"><span class=\"glyphicon glyphicon-plus\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add")+"</button>");
        }
        // put a blank if nothing else
        sb.append("</div>");
     	return sb;
    }
    
    void doSeriesNumber(javax.servlet.jsp.JspWriter out, Item item,
      String fieldName, String schema, String element, String qualifier, boolean repeatable,
      boolean required, boolean readonly, int fieldCountIncr, String label, PageContext pageContext,List<DCInput> children,boolean hasParent)
      throws java.io.IOException
    {

      List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema, element, qualifier, Item.ANY);
      int fieldCount = defaults.size() + fieldCountIncr;
      StringBuffer sb = new StringBuffer();
      org.dspace.content.DCSeriesNumber sn;
      StringBuffer headers = new StringBuffer();

      if (fieldCount == 0)
         fieldCount = 1;

      sb.append("<div class=\"row\"><label class=\"col-md-2"+ (required?" label-required":"") +"\">")
      	.append(label)
      	.append("</label><div class=\"col-md-10\">");
      
      for (int i = 0; i < fieldCount; i++)
      {
         if (i < defaults.size())
           sn = new org.dspace.content.DCSeriesNumber(defaults.get(i).getValue());
         else
           sn = new org.dspace.content.DCSeriesNumber();

         sb.append("<div class=\"row col-md-12\"><span class=\"col-md-5\"><input class=\"form-control\" type=\"text\" name=\"")
           .append(fieldName)
           .append("_series");
         if (repeatable)
           sb.append("_").append(i+1);
         if (readonly)
         {
             sb.append("\" readonly=\"readonly\"");
         }
         sb.append("\" placeholder=\"")
           .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.seriesname").replaceAll("\"", "&quot;"));
         sb.append("\" size=\"23\" value=\"")
           .append(sn.getSeries().replaceAll("\"", "&quot;"))
           .append("\"/></span><span class=\"col-md-5\"><input class=\"form-control\" type=\"text\" name=\"")
           .append(fieldName)
           .append("_number");
         if (repeatable)
           sb.append("_").append(i+1);
         if (readonly)
         {
             sb.append("\" readonly=\"readonly\"");
         }
         sb.append("\" placeholder=\"")
           .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.paperno").replaceAll("\"", "&quot;"));
         sb.append("\" size=\"23\" value=\"")
           .append(sn.getNumber().replaceAll("\"", "&quot;"))
           .append("\"/></span>\n");

         if (repeatable && !readonly && i < fieldCount - 1)
         {
            // put a remove button next to filled in values
            sb.append("<button class=\"btn btn-danger col-md-2\" name=\"submit_")
              .append(fieldName)
              .append("_remove_")
              .append(i)
              .append("\" value=\"")
              .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove"))
              .append("\"><span class=\"glyphicon glyphicon-trash\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove")+"</button>");
         }
         else if (repeatable && !readonly && i == fieldCount - 1)
         {
            // put a 'more' button next to the last space
            sb.append("<button class=\"btn btn-default col-md-2\" name=\"submit_")
              .append(fieldName)
              .append("_add\" value=\"")
              .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add"))
              .append("\"><span class=\"glyphicon glyphicon-plus\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add")+"</button>");
         }

         // put a blank if nothing else
         sb.append("</div>");
      }
      sb.append("</div></div><br/>");
      
      out.write(sb.toString());
    }

    void doTextArea(javax.servlet.jsp.JspWriter out, Item item,
      String fieldName, String schema, String element, String qualifier, boolean repeatable, boolean required, boolean readonly,
      int fieldCountIncr, String label, PageContext pageContext, String vocabulary, boolean closedVocabulary, Collection collection,
      boolean language, List<String> valueLanguageList, List<DCInput> children, boolean hasParent)
      throws java.io.IOException
    {
      String authorityType = getAuthorityType(pageContext, fieldName, collection);
      List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema, element, qualifier, Item.ANY);
      int fieldCount = defaults.size() + fieldCountIncr;
      StringBuffer sb = new StringBuffer();
      String val, auth;
      int conf = unknownConfidence;

      if (fieldCount == 0)
         fieldCount = 1;

      sb.append("<div class=\"row\">");
      
      for (int i = 0; i < fieldCount; i++)
      {
    	  sb.append("<label class=\"col-md-2"+ (required?" label-required":"") +"\">")
        	.append(label)
          	.append("</label><div class=\"col-md-10\">");
			sb.append(doTextAreaInput(defaults,i, authorityType, fieldCount, fieldName,  schema,  element, qualifier, 
			   		 repeatable, required, readonly, fieldCountIncr, pageContext, vocabulary, closedVocabulary,collection, language, valueLanguageList, hasParent));
	    	if(children !=null){
	    	      int countChild = 1;
		    	  for(DCInput child: children){
		    		  sb.append(doChildInput(item,child, i, fieldCount, repeatable,readonly,fieldCountIncr, pageContext, collection, children.size()==countChild, language, valueLanguageList));
		    		  countChild++;
		    	  }
	    	}
	    	sb.append("</div>");
      }
      sb.append("</div><br/>");
      
      out.write(sb.toString());
    }
    
    StringBuffer doTextAreaInput(List<IMetadataValue> defaults,int count,String authorityType,int fieldCount, String fieldName, String schema, String element, 
    		String qualifier, boolean repeatable, boolean required, boolean readonly, int fieldCountIncr, PageContext pageContext,String vocabulary,
    		boolean closedVocabulary,Collection collection, boolean language, List<String> valueLanguageList, boolean hasParent){
        StringBuffer sb = new StringBuffer();
        
        String auth,val;
        String lang = null;
        int conf=0;
    	if (count < defaults.size())
        {
             val = StringUtils.replaceEachRepeatedly(defaults.get(count).getValue(),new String[]{"\"",MetadataValue.PARENT_PLACEHOLDER_VALUE},new String[]{"&quot;",""});
             lang = defaults.get(count).getLanguage();
             auth = defaults.get(count).getAuthority();
             conf = defaults.get(count).getConfidence();
        }
        else
        {
          val = "";
           auth = "";
        }
        sb.append("<div class=\"row col-md-12\">\n");
        String fieldNameIdx = fieldName + ((repeatable && count != fieldCount-1)?"_" + (count+1):"");
        
        if (language) 
        {
            sb.append("<div class=\"col-md-8\">");
        }
        else 
        {
            sb.append("<div class=\"col-md-10\">");
        }
        
        if (authorityType != null)
        {
       	 sb.append("<div class=\"col-md-10\">");
        }
        sb.append("<textarea class=\"form-control\" name=\"").append(fieldNameIdx)
          .append("\" rows=\"4\" cols=\"45\" id=\"")
          .append(fieldNameIdx).append("_id\" ")
          .append((hasVocabulary(vocabulary)&&closedVocabulary)||readonly?" disabled=\"disabled\" ":"")
          .append(">")
          .append(val)
          .append("</textarea>")
          .append(doControlledVocabulary(fieldNameIdx, pageContext, vocabulary, readonly));
        
        if (language) 
        {
            if (null == lang)
            {
                lang = ConfigurationManager.getProperty("default.language");
            }
            sb.append("<div class=\"col-md-2\">");
            sb = doLanguageTag(sb, fieldNameIdx, valueLanguageList, lang);
            sb.append("</div>");
        }
        
        if (authorityType != null)
        {
       	 sb.append("</div><div class=\"col-md-2\">");
	         sb.append(doAuthority(pageContext, fieldName, count, fieldCount, fieldName,
                           auth, conf, false, repeatable,
                           defaults, null, collection));
	         sb.append("</div>");
        }

        sb.append("</div>");
          
        
        if (!hasParent && repeatable && !readonly && count < defaults.size())
        {
           // put a remove button next to filled in values
           sb.append("<button class=\"btn btn-danger col-md-2\" name=\"submit_")
             .append(fieldName)
             .append("_remove_")
             .append(count)
             .append("\" value=\"")
             .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove"))
             .append("\"><span class=\"glyphicon glyphicon-trash\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove")+"</button>");
        }
        else if (!hasParent && repeatable && !readonly && count == fieldCount - 1)
        {
           // put a 'more' button next to the last space
           sb.append("<button class=\"btn btn-default col-md-2\" name=\"submit_")
             .append(fieldName)
             .append("_add\" value=\"")
             .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add"))
             .append("\"><span class=\"glyphicon glyphicon-plus\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add")+"</button>");
        }

        // put a blank if nothing else
        sb.append("</div>");
        return sb;
    }

    void doNumber(javax.servlet.jsp.JspWriter out, Item item,
            String fieldName, String schema, String element, String qualifier, boolean repeatable, boolean required, boolean readonly,
            int fieldCountIncr, String label, PageContext pageContext, Collection collection, boolean language, List<String> valueLanguageList, List<DCInput> children, boolean hasParent)
            throws java.io.IOException
    {
            
        String authorityType = getAuthorityType(pageContext, fieldName, collection);
        List<IMetadataValue> defaults = item.getMetadata(schema, element, qualifier, Item.ANY);
        int fieldCount = defaults.size() + fieldCountIncr;
        StringBuffer sb = new StringBuffer();
        String val, auth;
        int conf= 0;

        if (fieldCount == 0)
           fieldCount = 1;

        sb.append("<div class=\"row\">");  
        for (int i = 0; i < fieldCount; i++)
        {
        	sb.append("<label class=\"col-md-2"+ (required?" label-required":"") +"\">")
            .append(label)
            .append("</label>");
            sb.append("<div class=\"col-md-10\">");
        	sb.append(doNumberInput(defaults, i, authorityType, fieldCount, fieldName, schema, element, qualifier, repeatable, required, 
        			readonly, fieldCountIncr, pageContext, collection, hasParent));
	    	if(children !=null){
	    	      int countChild = 1;
		    	  for(DCInput child: children){
		    		  sb.append(doChildInput(item,child, i, fieldCount, repeatable,readonly,fieldCountIncr, pageContext, collection, children.size()==countChild, language, valueLanguageList));
		    		  countChild++;
		    	  }
	    	}
	    	sb.append("</div>");
        }
        sb.append("</div><br/>");
        out.write(sb.toString());
    }
    
    StringBuffer doNumberInput(List<IMetadataValue> defaults,int count,String authorityType,int fieldCount, String fieldName, String schema, String element, 
    		String qualifier, boolean repeatable, boolean required, boolean readonly, int fieldCountIncr, PageContext pageContext,
    		Collection collection,boolean hasParent){

    	StringBuffer sb = new StringBuffer();
    	String val,auth;
    	int conf =0;
    	
        if (count < defaults.size())
        {
          val = defaults.get(count).getValue().replaceAll("\"", "&quot;");
          auth = defaults.get(count).getAuthority();
          conf = defaults.get(count).getConfidence();
        }
        else
        {
          val = "";
          auth = "";
          conf= unknownConfidence;
        }

        sb.append("<div class=\"row col-md-12\">");
        String fieldNameIdx = fieldName + ((repeatable && count != fieldCount-1)?"_" + (count+1):"");
        
        sb.append("<div class=\"col-md-10\">");
        if (authorityType != null)
        {
     	   sb.append("<div class=\"row col-md-10\">");
        }
        
        sb.append("<div class=\"row col-md-4\">");
        sb.append("<input class=\"form-control\" type=\"number\" step=\"any\"  name=\"")
          .append(fieldNameIdx)
          .append("\" id=\"")
          .append(fieldNameIdx).append("\" value=\"")
          .append(val +"\"")
          .append(readonly?" disabled=\"disabled\" ":"")
          .append("/>")  			              
          .append("</div>").append("</div>");
        
        if (authorityType != null)
        {
     	   sb.append("<div class=\"col-md-2\">");
	           sb.append(doAuthority(pageContext, fieldName, count,  fieldCount,
                           fieldName, auth, conf, false, repeatable,
                           defaults, null, collection));
        	   sb.append("</div></div>");
        }             

       if (!hasParent && repeatable && !readonly && count < defaults.size())
       {
          // put a remove button next to filled in values
          sb.append("<button class=\"btn btn-danger col-md-2\" name=\"submit_")
            .append(fieldName)
            .append("_remove_")
            .append(count)
            .append("\" value=\"")
            .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove"))
            .append("\"><span class=\"glyphicon glyphicon-trash\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove")+"</button>");
       }
       else if (!hasParent && repeatable && !readonly && count == fieldCount - 1)
       {
          // put a 'more' button next to the last space
          sb.append("<button class=\"btn btn-default col-md-2\" name=\"submit_")
            .append(fieldName)
            .append("_add\" value=\"")
            .append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add"))
            .append("\"><span class=\"glyphicon glyphicon-plus\"></span>&nbsp;&nbsp;"+LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add")+"</button>");
       }

       sb.append("</div>");
  	   return sb;       	
    }

    
	void doOneBox(javax.servlet.jsp.JspWriter out, Item item, String fieldName, String schema, String element,
			String qualifier, boolean repeatable, boolean required, boolean readonly, int fieldCountIncr, String label,
			PageContext pageContext, String vocabulary, boolean closedVocabulary, Collection collection,
			boolean language, List<String> valueLanguageList, List<DCInput> children, boolean hasParent)
			throws java.io.IOException {
		String authorityType = getAuthorityType(pageContext, fieldName, collection);
		List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema,
				element, qualifier, Item.ANY);
		int fieldCount = defaults.size() + fieldCountIncr;
		StringBuffer sb = new StringBuffer();
		String val, auth;
		int conf = 0;

		if (fieldCount == 0)
			fieldCount = 1;

		sb.append("<div class=\"row\">");
		for (int i = 0; i < fieldCount; i++) {
			sb.append("<label class=\"col-md-2" + (required ? " label-required" : "") + "\">").append(label)
					.append("</label>");
			sb.append("<div class=\"col-md-10\">");
			sb.append(doOneBoxInput(defaults, i, authorityType, fieldCount, fieldName, schema, element, qualifier,
					repeatable, required, readonly, fieldCountIncr, pageContext, vocabulary, closedVocabulary,
					collection, language, valueLanguageList, hasParent));
			if (children != null) {
				int countChild = 1;
				for (DCInput child : children) {
					sb.append(doChildInput(item, child, i, fieldCount, repeatable, readonly, fieldCountIncr,
							pageContext, collection, children.size() == countChild, language, valueLanguageList));
					countChild++;
				}
			}
			sb.append("</div>");
		}

		sb.append("</div><br/>");

		out.write(sb.toString());
	}

	StringBuffer doOneBoxInput(List<IMetadataValue> defaults, int count, String authorityType, int fieldCount,
			String fieldName, String schema, String element, String qualifier, boolean repeatable, boolean required,
			boolean readonly, int fieldCountIncr, PageContext pageContext, String vocabulary, boolean closedVocabulary,
			Collection collection, boolean language, List<String> valueLanguageList, boolean hasParent) {

		StringBuffer sb = new StringBuffer();
		String val, auth;
		String lang = null;
		
		int conf = 0;

		if (count < defaults.size()) {
			val = StringUtils.replaceEachRepeatedly(defaults.get(count).getValue(),
					new String[] { "\"", MetadataValue.PARENT_PLACEHOLDER_VALUE }, new String[] { "&quot;", "" });
			lang = defaults.get(count).getLanguage();
			auth = defaults.get(count).getAuthority();
			conf = defaults.get(count).getConfidence();
		} else {
			val = "";
			auth = "";
			conf = unknownConfidence;
		}

		sb.append("<div class=\"row col-md-12\">");
		String fieldNameIdx = fieldName + ((repeatable && count != fieldCount - 1) ? "_" + (count + 1) : "");

        if (language)
        {
            sb.append("<div class=\"col-md-8\">");
        }
        else 
        {
            sb.append("<div class=\"col-md-10\">");
        }
        
		if (authorityType != null) {
			sb.append("<div class=\"row col-md-10\">");
		}
		sb.append("<input class=\"form-control\" type=\"text\" name=\"").append(fieldNameIdx).append("\" id=\"")
				.append(fieldNameIdx).append("\" size=\"50\" value=\"").append(val + "\"")
				.append((hasVocabulary(vocabulary) && closedVocabulary) || readonly ? " disabled=\"disabled\" " : "")
				.append("/>").append(doControlledVocabulary(fieldNameIdx, pageContext, vocabulary, readonly))
				.append("</div>");

		if (language) {
			if (null == lang) {
				lang = ConfigurationManager.getProperty("default.language");
			}
			sb.append("<div class=\"col-md-2\">");
			sb = doLanguageTag(sb, fieldNameIdx, valueLanguageList, lang);
			sb.append("</div>");
		}

		if (authorityType != null) {
			sb.append("<div class=\"col-md-2\">");
			sb.append(doAuthority(pageContext, fieldName, count, fieldCount, fieldName, auth, conf, false, repeatable,
					defaults, null, collection));
			sb.append("</div></div>");
		}

		if (!hasParent && repeatable && !readonly && count < fieldCount - 1) {
			// put a remove button next to filled in values
			sb.append("<button class=\"btn btn-danger col-md-2\" name=\"submit_").append(fieldName).append("_remove_")
					.append(count).append("\" value=\"")
					.append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove"))
					.append("\"><span class=\"glyphicon glyphicon-trash\"></span>&nbsp;&nbsp;"
							+ LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove")
							+ "</button>");
		} else if (!hasParent && repeatable && !readonly && count == fieldCount - 1) {
			// put a 'more' button next to the last space
			sb.append("<button class=\"btn btn-default col-md-2\" name=\"submit_").append(fieldName)
					.append("_add\" value=\"")
					.append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add"))
					.append("\"><span class=\"glyphicon glyphicon-plus\"></span>&nbsp;&nbsp;"
							+ LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add")
							+ "</button>");
		}

		sb.append("</div>");
		return sb;

	}

	void doTwoBox(javax.servlet.jsp.JspWriter out, Item item, String fieldName, String schema, String element,
			String qualifier, boolean repeatable, boolean required, boolean readonly, int fieldCountIncr, String label,
			PageContext pageContext, String vocabulary, boolean closedVocabulary, boolean language,
			List<String> valueLanguageList) throws java.io.IOException {
		/*
		<div class="row"><label class="col-md-2">Subject Keywords</label>
		<div class="col-md-10">
		    <div class="row">
		        <div class="col-md-5">
		            <span class="col-md-6"><input type="text" class="form-control" name="dc_subject_1" size="15" value="test"></span>
		            <span class="col-md-4"><select class="form-control" name="dc_subject_other_1[lang]"><option value="">N/A</option><option selected="selected" value="en">English</option><option value="de">German</option></select></span>
		            <button value="Remove" name="submit_dc_subject_remove_0" class="btn btn-danger col-md-2"><span class="glyphicon glyphicon-trash"></span></button>
		        </div>
		        <div class="col-md-5">
		            <span class="col-md-6"><input type="text" class="form-control" name="dc_subject_2" size="15" value="tes2"></span>
		            <span class="col-md-4"><select class="form-control" name="dc_subject_other_1[lang]"><option value="">N/A</option><option selected="selected" value="en">English</option><option value="de">German</option></select></span>
		            <button class="col-md-2 btn btn-danger" name="submit_dc_subject_remove_1" value="Remove"><span class="glyphicon glyphicon-trash"></span></button>
		        </div>
		        <span class="col-md-2"></span>
		    </div>
		    <div class="row">
		      <div class="col-md-5">
		        <span class="col-md-6"><input type="text" class="form-control" name="dc_subject_3" size="15"></span>
		        <span class="col-md-4"><select class="form-control" name="dc_subject_other_1[lang]"><option value="">N/A</option><option selected="selected" value="en">English</option><option value="de">German</option></select></span>
		        <span class="col-md-2"></span>
		      </div>
		      <div class="col-md-5">
		        <span class="col-md-6"><input type="text" class="form-control" name="dc_subject_3" size="15"></span>
		        <span class="col-md-4"><select class="form-control" name="dc_subject_other_1[lang]"><option value="">N/A</option><option selected="selected" value="en">English</option><option value="de">German</option></select></span>
		        <span class="col-md-2"></span>
		      </div>
		      <button class="btn btn-default col-md-2" name="submit_dc_subject_add" value="Add More"><span class="glyphicon glyphicon-plus"></span>&nbsp;&nbsp;Add More</button>
		    </div>
		</div>
		</div>
		*/

		List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema,
				element, qualifier, Item.ANY);
		int fieldCount = defaults.size() + fieldCountIncr;
		StringBuffer sb = new StringBuffer();
		StringBuffer headers = new StringBuffer();

		String fieldParam = "";

		if (fieldCount == 0)
			fieldCount = 1;

		sb.append("<div class=\"row\"><label class=\"col-md-2" + (required ? " label-required" : "") + "\">")
				.append(label).append("</label>");
		sb.append("<div class=\"col-md-10\">");
		for (int i = 0; i < fieldCount; i++) {
			sb.append("<div class=\"row\">\n");
			sb.append("<div class=\"col-md-5\">");

			if (repeatable) {
				//param is field name and index, starting from 1 (e.g. myfield_2)
				fieldParam = fieldName + "_" + (i + 1);
			} else {
				//param is just the field name
				fieldParam = fieldName;
			}

			if (i < defaults.size()) {
				sb.append("<span class=\"col-md-").append(language ? "6" : "10")
						.append("\"><input class=\"form-control\" type=\"text\" name=\"").append(fieldParam)
						.append("\" size=\"15\" value=\"").append(defaults.get(i).getValue().replaceAll("\"", "&quot;"))
						.append("\"").append((hasVocabulary(vocabulary) && closedVocabulary) || readonly
								? " readonly=\"readonly\" " : "")
						.append("/>");

				sb.append(doControlledVocabulary(fieldParam, pageContext, vocabulary, readonly));
				sb.append("</span>");

				if (language) {
					String lang = defaults.get(i).getLanguage();
					if (null == lang) {
						lang = ConfigurationManager.getProperty("default.language");
					}
					sb.append("<span class=\"col-md-4\">");
					sb = doLanguageTag(sb, fieldParam, valueLanguageList, lang);
					sb.append("</span>");
				}

				if (repeatable && !readonly) {
					// put a remove button next to filled in values
					sb.append("<button class=\"btn btn-danger col-md-2\" name=\"submit_").append(fieldName)
							.append("_remove_").append(i).append("\" value=\"")
							.append(LocaleSupport.getLocalizedMessage(pageContext,
									"jsp.submit.edit-metadata.button.remove2"))
							.append("\"><span class=\"glyphicon glyphicon-trash\"></span></button>");
				} else {
					sb.append("<span class=\"col-md-2\">&nbsp;</span>");
				}
			} else {
				sb.append("<span class=\"col-md-").append(language ? "6" : "10")
						.append("\"><input class=\"form-control\" type=\"text\" name=\"").append(fieldParam)
						.append("\" size=\"15\"")
						.append((hasVocabulary(vocabulary) && closedVocabulary) || readonly ? " readonly=\"readonly\" "
								: "")
						.append("/>").append(doControlledVocabulary(fieldParam, pageContext, vocabulary, readonly))
						.append("</span>\n");

				if (language) {
					String lang = ConfigurationManager.getProperty("default.language");
					sb.append("<span class=\"col-md-4\">");
					sb = doLanguageTag(sb, fieldParam, valueLanguageList, lang);
					sb.append("</span>");
				}

				sb.append("<span class=\"col-md-2\">&nbsp;</span>"); // no remove button
			}
			sb.append("</div>\n"); //<div class="col-md-5>

			i++;

			sb.append("<div class=\"col-md-5\">");
			if (repeatable) {
				//param is field name and index, starting from 1 (e.g. myfield_2)
				fieldParam = fieldName + "_" + (i + 1);
			} else {
				//param is just the field name
				fieldParam = fieldName;
			}

			if (i < defaults.size()) {
				sb.append("<span class=\"col-md-").append(language ? 6 : 10)
						.append("\"><input class=\"form-control\" type=\"text\" name=\"").append(fieldParam)
						.append("\" size=\"15\" value=\"").append(defaults.get(i).getValue().replaceAll("\"", "&quot;"))
						.append("\"").append((hasVocabulary(vocabulary) && closedVocabulary) || readonly
								? " readonly=\"readonly\" " : "")
						.append("/>");
				sb.append(doControlledVocabulary(fieldParam, pageContext, vocabulary, readonly));
				sb.append("</span>");

				if (language) {
					String lang = defaults.get(i).getLanguage();
					if (null == lang) {
						lang = ConfigurationManager.getProperty("default.language");
					}
					sb.append("<span class=\"col-md-4\">");
					sb = doLanguageTag(sb, fieldParam, valueLanguageList, lang);
					sb.append("</span>");
				}

				if (repeatable && !readonly) {
					// put a remove button next to filled in values
					sb.append(" <button class=\"btn btn-danger col-md-2\" name=\"submit_").append(fieldName)
							.append("_remove_").append(i).append("\" value=\"")
							.append(LocaleSupport.getLocalizedMessage(pageContext,
									"jsp.submit.edit-metadata.button.remove2"))
							.append("\"><span class=\"glyphicon glyphicon-trash\" /></button>");
				} else {
					sb.append("<span class=\"col-md-2\">&nbsp;</span>");
				}
			} else {
				sb.append("<span class=\"col-md-").append(language ? "6" : "10")
						.append("\"><input class=\"form-control\" type=\"text\" name=\"").append(fieldParam)
						.append("\" size=\"15\"")
						.append((hasVocabulary(vocabulary) && closedVocabulary) || readonly ? " readonly=\"readonly\" "
								: "")
						.append("/>").append(doControlledVocabulary(fieldParam, pageContext, vocabulary, readonly))
						.append("</span>\n");

				if (language) {
					String lang = ConfigurationManager.getProperty("default.language");
					sb.append("<span class=\"col-md-4\">");
					sb = doLanguageTag(sb, fieldParam, valueLanguageList, lang);
					sb.append("</span>");
				}

				sb.append("<span class=\"col-md-2\">&nbsp;</span>"); // no remove button
			}
			sb.append("</div>\n"); //<div class="col-md-5>

			if (repeatable && !readonly && i >= fieldCount - 1) {
				sb.append(" <button class=\"btn btn-default col-md-2\" name=\"submit_").append(fieldName)
						.append("_add\" value=\"")
						.append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add"))
						.append("\"><span class=\"glyphicon glyphicon-plus\"></span>&nbsp;&nbsp;"
								+ LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add")
								+ "</button>\n");
			} else {
				sb.append("<!-- repeatable: " + (repeatable ? "true" : "false") + " readonly "
						+ (readonly ? "true" : "false") + " i " + i + " fieldCount " + fieldCount + " -->");
			}

			sb.append("</div>"); //<div class="row">
		}
		sb.append("</div></div><br/>"); //<div class="row">...<div class="col-md-10">
		out.write(sb.toString());
	}

	void doQualdropValue(JspWriter out, Item item, String fieldName, String schema, String element, DCInputSet inputs,
			boolean repeatable, boolean required, boolean readonly, int fieldCountIncr, List qualMap, String label,
			PageContext pageContext, List<DCInput> children, boolean hasParent) throws IOException {
		List<IMetadataValue> unfiltered = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema,
				element, Item.ANY, Item.ANY);
		// filter out both unqualified and qualified values occurring elsewhere in inputs
		List<IMetadataValue> filtered = new ArrayList<>();
		for (int i = 0; i < unfiltered.size(); i++) {
			String unfilteredFieldName = unfiltered.get(i).getMetadataField().getElement();
			if (unfiltered.get(i).getMetadataField().getQualifier() != null
					&& unfiltered.get(i).getMetadataField().getQualifier().length() > 0)
				unfilteredFieldName += "." + unfiltered.get(i).getMetadataField().getQualifier();

			if (!inputs.isFieldPresent(unfilteredFieldName)) {
				filtered.add(unfiltered.get(i));
			}
		}
		List<IMetadataValue> defaults = filtered;

		int fieldCount = defaults.size() + fieldCountIncr;
		StringBuffer sb = new StringBuffer();
		String q, v, currentQual, currentVal;

		if (fieldCount == 0)
			fieldCount = 1;

		sb.append("<div class=\"row\"><label class=\"col-md-2" + (required ? " label-required" : "") + "\">")
				.append(label).append("</label>");
		sb.append("<div class=\"col-md-10\">");
		for (int j = 0; j < fieldCount; j++) {

			if (j < defaults.size()) {
				currentQual = defaults.get(j).getMetadataField().getQualifier();
				if (currentQual == null)
					currentQual = "";
				currentVal = defaults.get(j).getValue();
			} else {
				currentQual = "";
				currentVal = "";
			}

			// do the dropdown box
			sb.append(
					"<div class=\"row col-md-12\"><span class=\"input-group col-md-10\"><span class=\"input-group-addon\"><select name=\"")
					.append(fieldName).append("_qualifier");
			if (repeatable)
				sb.append("_").append(j + 1);
			if (readonly) {
				sb.append("\" readonly=\"readonly\"");
			}
			sb.append("\">");
			for (int i = 0; i < qualMap.size(); i += 2) {
				q = (String) qualMap.get(i);
				v = (String) qualMap.get(i + 1);
				sb.append("<option").append((v.equals(currentQual) ? " selected=\"selected\" " : ""))
						.append(" value=\"").append(v).append("\">").append(q).append("</option>");
			}

			// do the input box
			sb.append("</select></span><input class=\"form-control\" type=\"text\" name=\"").append(fieldName)
					.append("_value");
			if (repeatable)
				sb.append("_").append(j + 1);
			if (readonly) {
				sb.append("\" readonly=\"readonly\"");
			}
			sb.append("\" size=\"34\" value=\"").append(currentVal.replaceAll("\"", "&quot;")).append("\"/></span>\n");

			if (repeatable && !readonly && j < fieldCount - 1) {
				// put a remove button next to filled in values
				sb.append("<button class=\"btn btn-danger col-md-2\" name=\"submit_").append(fieldName)
						.append("_remove_").append(j).append("\" value=\"")
						.append(LocaleSupport.getLocalizedMessage(pageContext,
								"jsp.submit.edit-metadata.button.remove"))
						.append("\"><span class=\"glyphicon glyphicon-trash\"></span>&nbsp;&nbsp;" + LocaleSupport
								.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.remove")
								+ "</button>");
			} else if (repeatable && !readonly && j == fieldCount - 1) {
				// put a 'more' button next to the last space
				sb.append("<button class=\"btn btn-default col-md-2\" name=\"submit_").append(fieldName)
						//            .append("_add\" value=\"Add More\"/> </td></tr>");
						.append("_add\" value=\"")
						.append(LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add"))
						.append("\"><span class=\"glyphicon glyphicon-plus\"></span>&nbsp;&nbsp;"
								+ LocaleSupport.getLocalizedMessage(pageContext, "jsp.submit.edit-metadata.button.add")
								+ "</button>");
			}

			// put a blank if nothing else
			sb.append("</div>");
		}
		sb.append("</div></div><br/>");
		out.write(sb.toString());
	}

	void doDropDown(javax.servlet.jsp.JspWriter out, Item item, String fieldName, String schema, String element,
			String qualifier, boolean repeatable, boolean required, boolean readonly, List valueList, String label,
			List<DCInput> children, boolean hasParent) throws java.io.IOException {
		List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema,
				element, qualifier, Item.ANY);
		StringBuffer sb = new StringBuffer();
		Iterator vals;
		String display, value;
		int j;

		sb.append("<div class=\"row\"><label class=\"col-md-2" + (required ? " label-required" : "") + "\">")
				.append(label).append("</label>");

		sb.append("<div class=\"col-md-10\"><div class=\"row col-md-12\"><div class=\"col-md-10\">")
				.append("<select class=\"form-control\" name=\"").append(fieldName).append("\"");
		if (repeatable)
			sb.append(" size=\"15\"  multiple=\"multiple\"");
		if (readonly) {
			sb.append(" readonly=\"readonly\"");
		}
		sb.append(">");

		for (int i = 0; i < valueList.size(); i += 2) {
			display = (String) valueList.get(i);
			value = (String) valueList.get(i + 1);
			for (j = 0; j < defaults.size(); j++) {
				if (value.equals(defaults.get(j).getValue()))
					break;
			}
			sb.append("<option ").append(j < defaults.size() ? " selected=\"selected\" " : "").append("value=\"")
					.append(value.replaceAll("\"", "&quot;")).append("\">").append(display).append("</option>");
		}

		sb.append("</select></div></div></div></div><br/>");
		out.write(sb.toString());
	}

	void doChoiceSelect(javax.servlet.jsp.JspWriter out, PageContext pageContext, Item item, String fieldName,
			String schema, String element, String qualifier, boolean repeatable, boolean required, boolean readonly,
			List valueList, String label, Collection collection) throws java.io.IOException {
		List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema,
				element, qualifier, Item.ANY);
		StringBuffer sb = new StringBuffer();

		sb.append("<div class=\"row\"><label class=\"col-md-2" + (required ? " label-required" : "") + "\">")
				.append(label).append("</label>");

		sb.append("<div class=\"col-md-10\"><div class=\"row col-md-12\"><div class=\"col-md-10\">")
				.append(doAuthority(pageContext, fieldName, 0, defaults.size(), fieldName, null, Choices.CF_UNSET,
						false, repeatable, defaults, null, collection))

				.append("</div></div></div></div><br/>");
		out.write(sb.toString());
	}

	/** Display Checkboxes or Radio buttons, depending on if repeatable! **/
	void doList(javax.servlet.jsp.JspWriter out, Item item, String fieldName, String schema, String element,
			String qualifier, boolean repeatable, boolean required, boolean readonly, List valueList, String label,
			List<DCInput> children, boolean hasParent) throws java.io.IOException {
		List<IMetadataValue> defaults = ContentServiceFactory.getInstance().getItemService().getMetadata(item, schema,
				element, qualifier, Item.ANY);
		int valueCount = valueList.size();

		StringBuffer sb = new StringBuffer();
		String display, value;
		int j;

		int numColumns = 1;
		//if more than 3 display+value pairs, display in 2 columns to save space
		if (valueCount > 6)
			numColumns = 2;

		//print out the field label
		sb.append("<div class=\"row\"><label class=\"col-md-2" + (required ? " label-required" : "") + "\">")
				.append(label).append("</label>");

		sb.append("<div class=\"col-md-10\"><div class=\"col-md-12 row\">");

		if (numColumns > 1)
			sb.append("<div class=\"col-md-" + (12 / numColumns) + "\">");
		else
			sb.append("<div class=\"col-md-12\">");

		//flag that lets us know when we are in Column2
		boolean inColumn2 = false;
		boolean notSet = false;
		//loop through all values
		for (int i = 0; i < valueList.size(); i += 2) {
			//get display value and actual value
			display = (String) valueList.get(i);
			value = (String) valueList.get(i + 1);

			boolean checked = false;
			//check if this value has been selected previously
			for (j = 0; j < defaults.size(); j++) {
				if (value.equals(defaults.get(j).getValue())) {
					checked = true;
					break;
				}
			}

			if (!checked && i == 0 && StringUtils.isBlank(value)) {
				notSet = true;
				continue;
			}

			// print input field
			sb.append("<div class=\"input-group\"><span class=\"input-group-addon\">");
			sb.append("<input type=\"");

			//if repeatable, print a Checkbox, otherwise print Radio buttons
			if (repeatable) {
				sb.append("checkbox");
			} else {
				sb.append("radio");
			}
			sb.append("\"");

			if (readonly) {
				sb.append(" disabled=\"disabled\"");
			}
			if (!checked && i == 0 && !notSet) {
				sb.append(" checked");
			}
			sb.append(" name=\"").append(fieldName).append("\"")
					.append(j < defaults.size() ? " checked=\"checked\" " : "").append(" value=\"")
					.append(value.replaceAll("\"", "&quot;")).append("\">");
			sb.append("</span>");

			//print display name immediately after input
			sb.append("<span class=\"form-control\">").append(display).append("</span></div>");

			// if we are writing values in two columns,
			// then start column 2 after half of the values
			if ((numColumns == 2) && (i + 2 >= (valueList.size() / 2)) && !inColumn2) {
				//end first column, start second column
				sb.append("</div>");
				sb.append("<div class=\"row col-md-" + (12 / numColumns) + "\">");
				inColumn2 = true;
			}

		} //end for each value

		sb.append("</div></div></div></div><br/>");

		out.write(sb.toString());
	}//end doList

	/** Display language tags **/
	StringBuffer doLanguageTag(StringBuffer sb, String fieldNameIdx, List<String> valueLanguageList, String lang) {
		sb.append("<select class=\"form-control\" name=\"").append(fieldNameIdx + "[lang]").append("\"").append(">");

		for (int j = 0; j < valueLanguageList.size(); j += 2) {
			String display = (String) valueLanguageList.get(j);
			String value = (String) valueLanguageList.get(j + 1);

			sb.append("<option ").append(value.equals(lang) ? " selected=\"selected\" " : "").append("value=\"")
					.append(value.replaceAll("\"", "&quot;")).append("\">").append(display).append("</option>");
		}

		sb.append("</select>");
		return sb;
	}%>

<%
    // Obtain DSpace context
    Context context = UIUtil.obtainContext(request);

    SubmissionInfo si = SubmissionController.getSubmissionInfo(context, request);

    Item item = si.getSubmissionItem().getItem();

    final int halfWidth = 23;
    final int fullWidth = 50;
    final int twothirdsWidth = 34;

    DCInputSet inputSet =
        (DCInputSet) request.getAttribute("submission.inputs");

    Integer pageNumStr =
        (Integer) request.getAttribute("submission.page");
    int pageNum = pageNumStr.intValue();
    
    // for later use, determine whether we are in submit or workflow mode
    String scope = "";
    int wfState=-1;
    if(si.isInWorkflow()){
       	WorkflowItem wfi = (WorkflowItem) si.getSubmissionItem();
    	wfState = wfi.getState();   
        if(wfState== BasicWorkflowService.WFSTATE_STEP1){
        	scope = DCInput.WORKFLOW_STEP1_SCOPE;
        }else if(wfState== BasicWorkflowService.WFSTATE_STEP2){
        	scope = DCInput.WORKFLOW_STEP2_SCOPE;
        }else if(wfState== BasicWorkflowService.WFSTATE_STEP3){
        	scope = DCInput.WORKFLOW_STEP3_SCOPE;
        }else{
        	scope = "workflow";
        }
    }
    else{
    	scope = "submit";
    }
    // owning Collection ID for choice authority calls
    Collection collection = si.getSubmissionItem().getCollection();
    UUID collectionID = collection.getID();
	String collectionName = collection.getName();
    // Fetch the document type (dc.type)
    String documentType = "";
    if( (ContentServiceFactory.getInstance().getItemService().getMetadataByMetadataString(item, "dc.type") != null) && (ContentServiceFactory.getInstance().getItemService().getMetadataByMetadataString(item, "dc.type").size() >0) )
    {
        documentType = ContentServiceFactory.getInstance().getItemService().getMetadataByMetadataString(item, "dc.type").get(0).getValue();
    }
%>
<c:set var="dspace.layout.head.last" scope="request">
	<script type="text/javascript" src="<%= request.getContextPath() %>/static/js/scriptaculous/prototype.js"></script>
	<script type="text/javascript" src="<%= request.getContextPath() %>/static/js/scriptaculous/builder.js"></script>
	<script type="text/javascript" src="<%= request.getContextPath() %>/static/js/scriptaculous/effects.js"></script>
	<script type="text/javascript" src="<%= request.getContextPath() %>/static/js/scriptaculous/controls.js"></script>
</c:set>
<dspace:layout style="submission" locbar="off" navbar="off" titlekey="jsp.submit.edit-metadata.title">

<%
        contextPath = request.getContextPath();
		lcl = request.getLocale();
		String keyCollectionName = StringUtils.deleteWhitespace(collectionName.toLowerCase());
		String infoKey = "jsp.submit.edit-metadata.info"+pageNum+"." + keyCollectionName;
		String messageInfo = I18nUtil.getMessage(infoKey, lcl, false);
		String anchorKey = "jsp.submit.edit-metadata.describe"+pageNum+"." + keyCollectionName;
		String anchorHelp = I18nUtil.getMessage("jsp.submit.edit-metadata.describe"+pageNum+"."+keyCollectionName, lcl, false);
		
%>

  <form action="<%= request.getContextPath() %>/submit#<%= si.getJumpToField()%>" method="post" name="edit_metadata" id="edit_metadata" onkeydown="return disableEnterKey(event);">

        <jsp:include page="/submit/progressbar.jsp"></jsp:include>

    <h1><fmt:message key="jsp.submit.edit-metadata.heading"/>
  	<%
		if(!anchorKey.equals(anchorHelp)) {
	%>  
		<dspace:popup page="<%= LocaleSupport.getLocalizedMessage(pageContext, \"help.index\") + anchorHelp%>"><fmt:message key="jsp.submit.edit-metadata.help"/></dspace:popup>
	<% } else { %>
		<dspace:popup page="<%= LocaleSupport.getLocalizedMessage(pageContext, \"help.index\")%>"><fmt:message key="jsp.submit.edit-metadata.help"/></dspace:popup>
	<% } %>	
    </h1>

	<%
	if(!infoKey.equals(messageInfo)) {
	%>    
	    <p><fmt:message key="jsp.submit.edit-metadata.info1"><fmt:param><%= messageInfo%></fmt:param></fmt:message></p>
	<%       
	}
	else {
	     //figure out which help page to display
	     if (pageNum <= 1)
	     {
	%>
	        <p><fmt:message key="jsp.submit.edit-metadata.info1"/></p>
	<%
	     }
	     else
	     {
	%>
	        <p><fmt:message key="jsp.submit.edit-metadata.info2"/></p>
	    
	<%
	     }
	 }
	 
	 int pageIdx = pageNum - 1;
     DCInput[] inputs = inputSet.getPageRows(pageIdx, si.getSubmissionItem().hasMultipleTitles(),

    		 si.getSubmissionItem().isPublishedBefore() );
     
  
     for (int z = 0; z < inputs.length; z++)
     {
       boolean readonly = false;

       // Omit fields not allowed for this document type
       if(!inputs[z].isAllowedFor(documentType))
       {
           continue;
       }

       if(inputs[z].hasParent()){
    	   
    	   List<DCInput> childs = new ArrayList<DCInput>();
    	   List<DCInput> list = parent2child.get(inputs[z].getParent());
    	   if(list != null){
    		   childs = list;
    	   }
    	   childs.add(inputs[z]);
    	   parent2child.put(inputs[z].getParent(),childs);
    	   continue;
       }
       
       // ignore inputs invisible in this scope
       if (!si.isEditing() && !inputs[z].isVisible(scope))
       {
           if (inputs[z].isReadOnly(scope))
           {
                readonly = true;
           }
           else
           {
               continue;
           }
       }
       String dcElement = inputs[z].getElement();
       String dcQualifier = inputs[z].getQualifier();
       String dcSchema = inputs[z].getSchema();
       boolean language = inputs[z].getLanguage();
       
       String fieldName;
       int fieldCountIncr;
       boolean repeatable;
       String vocabulary;
	   boolean required;
	   
       vocabulary = inputs[z].getVocabulary();
       required = inputs[z].isRequired();
       
       if (dcQualifier != null && !dcQualifier.equals("*"))
          fieldName = dcSchema + "_" + dcElement + '_' + dcQualifier;
       else
          fieldName = dcSchema + "_" + dcElement;


       if ((si.getMissingFields() != null) && (si.getMissingFields().contains(fieldName)))
       {
           if(inputs[z].getWarning() != null)
           {
                   if(si.getJumpToField()==null || si.getJumpToField().length()==0)
                                si.setJumpToField(fieldName);

                   String req = "<div class=\"alert alert-warning\">" +
                                                        inputs[z].getWarning() +
                                                        "<a name=\""+fieldName+"\"></a></div>";
                   out.write(req);
           }
       }
       else if ((si.getErrorsValidationFields()!= null) && (si.getErrorsValidationFields().contains(fieldName)))
       {
           if(inputs[z].requireValidation())
           {
                   if(si.getJumpToField()==null || si.getJumpToField().length()==0)
                                si.setJumpToField(fieldName);
				   Locale locale = I18nUtil.getSupportedLocale(request.getLocale());
				   String message = "";
				   Object[] i18nargs = new Object[] {inputs[z].getValidation()};
                   try {
                   		 message = I18nUtil.getMessage("jsp.submit.edit-metadata.validation.errors."+fieldName, i18nargs, locale, true);
                   }
                   catch(Exception ex) {
                       message = I18nUtil.getMessage("jsp.submit.edit-metadata.validation.errors", i18nargs, locale);
                   }
                   String req = "<div class=\"alert alert-warning\">" + message + "<a name=\""+fieldName+"\"></a></div>";
                   out.write(req);
           }
       }
       else
       {
                        //print out hints, if not null
           if(inputs[z].getHints() != null)
           {
           		%>
           		<div class="help-block">
                	<%= inputs[z].getHints() %>
                <%
                    if (hasVocabulary(vocabulary) &&  !readonly)
                    {
             	%>
             						<span class="pull-right">
                                             <dspace:popup page="/help/index.html#controlledvocabulary"><fmt:message key="jsp.controlledvocabulary.controlledvocabulary.help-link"/></dspace:popup>
             						</span>
             	<%
                    }
				%>
				</div>
				<%
           }
       }
       
       repeatable = inputs[z].getRepeatable();
       fieldCountIncr = 0;
       if (repeatable && !readonly)
       {
         fieldCountIncr = 1;
         if (si.getMoreBoxesFor() != null && si.getMoreBoxesFor().equals(fieldName))
             {
           fieldCountIncr = 2;
         }
       }
       String inputType = inputs[z].getInputType();
       String label = inputs[z].getLabel();
       boolean closedVocabulary = inputs[z].isClosedVocabulary();
       boolean hasParent = inputs[z].hasParent();
       
       if (inputType.equals("name"))
       {
           doPersonalName(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                                          repeatable, required, readonly, fieldCountIncr, label, pageContext, collection, language, inputs[z].getValueLanguageList(), parent2child.get(fieldName), hasParent);
       }
       else if (isSelectable(fieldName))
       {
           doChoiceSelect(out, pageContext, item, fieldName, dcSchema, dcElement, dcQualifier,
                                   repeatable, required, readonly, inputs[z].getPairs(), label, collection);
       }
       else if (inputType.equals("date"))
       {
           doDate(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                          repeatable, required, readonly, fieldCountIncr, label, pageContext, collection, language, inputs[z].getValueLanguageList(), parent2child.get(fieldName),hasParent);
       }
       else if (inputType.equals("year")) 
       {
    	   doYear(true, out, item, fieldName, dcSchema, dcElement, dcQualifier,
                   repeatable, required, readonly, fieldCountIncr, label, pageContext, parent2child.get(fieldName),hasParent);
       }
       else if (inputType.equals("year_noinprint")) 
       {
    	   doYear(false, out, item, fieldName, dcSchema, dcElement, dcQualifier,
                   repeatable, required, readonly, fieldCountIncr, label, pageContext, parent2child.get(fieldName),hasParent);
       }
       else if (inputType.equals("number")) 
       {
    	   doNumber(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                   repeatable, required, readonly, fieldCountIncr, label, pageContext, collection, language, inputs[z].getValueLanguageList(), parent2child.get(fieldName), hasParent);
       }
       else if (inputType.equals("series"))
       {
           doSeriesNumber(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                              repeatable, required, readonly, fieldCountIncr, label, pageContext,parent2child.get(fieldName),hasParent);
       }
       else if (inputType.equals("qualdrop_value"))
       {
           doQualdropValue(out, item, fieldName, dcSchema, dcElement, inputSet, repeatable, required,
                                   readonly, fieldCountIncr, inputs[z].getPairs(), label, pageContext,parent2child.get(fieldName),hasParent);
       }
       else if (inputType.equals("textarea"))
       {
                   doTextArea(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                                  repeatable, required, readonly, fieldCountIncr, label, pageContext, vocabulary,
                                  closedVocabulary, collection, language, inputs[z].getValueLanguageList(), parent2child.get(fieldName), hasParent);
       }
       else if (inputType.equals("dropdown"))
       {
                        doDropDown(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                                   repeatable, required, readonly, inputs[z].getPairs(), label,parent2child.get(fieldName),hasParent);
       }
       else if (inputType.equals("twobox"))
       {
                        doTwoBox(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                                 repeatable, required, readonly, fieldCountIncr, label, pageContext, 
                                 vocabulary, closedVocabulary, language, inputs[z].getValueLanguageList());
       }
       else if (inputType.equals("list"))
       {
          doList(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                        repeatable, required, readonly, inputs[z].getPairs(), label,parent2child.get(fieldName),hasParent);
       }
       else
       {
                        doOneBox(out, item, fieldName, dcSchema, dcElement, dcQualifier,
                                 repeatable, required, readonly, fieldCountIncr, label, pageContext, vocabulary,
                                 closedVocabulary, collection, language, inputs[z].getValueLanguageList(), parent2child.get(fieldName), hasParent);
       }
       
     } // end of 'for rows'
%>
        
<%-- Hidden fields needed for SubmissionController servlet to know which item to deal with --%>
        <%= SubmissionController.getSubmissionParameters(context, request) %>
<div class="row">
<%  //if not first page & step, show "Previous" button
		if(!(SubmissionController.isFirstStep(request, si) && pageNum<=1))
		{ %>
			<div class="col-md-6 pull-right btn-group">
				<input class="btn btn-default col-md-4" type="submit" name="<%=AbstractProcessingStep.PREVIOUS_BUTTON%>" value="<fmt:message key="jsp.submit.edit-metadata.previous"/>" />
				<input class="btn btn-default col-md-4" type="submit" name="<%=AbstractProcessingStep.CANCEL_BUTTON%>" value="<fmt:message key="jsp.submit.edit-metadata.cancelsave"/>"/>
				<input class="btn btn-primary col-md-4" type="submit" name="<%=AbstractProcessingStep.NEXT_BUTTON%>" value="<fmt:message key="jsp.submit.edit-metadata.next"/>"/>
    <%  } else { %>
    		<div class="col-md-4 pull-right btn-group">
                <input class="btn btn-default col-md-6" type="submit" name="<%=AbstractProcessingStep.CANCEL_BUTTON%>" value="<fmt:message key="jsp.submit.edit-metadata.cancelsave"/>"/>
				<input class="btn btn-primary col-md-6" type="submit" name="<%=AbstractProcessingStep.NEXT_BUTTON%>" value="<fmt:message key="jsp.submit.edit-metadata.next"/>"/>
    <%  }  %>
    		</div><br/>
</div>    		

	<input type="hidden" name="pageCallerID" value="<%= request.getAttribute("pageCallerID")%>"/>
</form>

<script type="text/javascript">

j(document).ready(
		function()
		{			
			<%@ include file="/deduplication/javascriptDeduplication.jsp" %>
		}		
);

</script>
<%@ include file="/deduplication/template.jsp" %>
<%@ include file="/deduplication/htmlDeduplication.jsp" %>

</dspace:layout>