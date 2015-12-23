set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_050000 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2013.01.01'
,p_release=>'5.0.2.00.07'
,p_default_workspace_id=>1670552497385579
,p_default_application_id=>800
,p_default_owner=>'DXDY'
);
end;
/
prompt --application/ui_types
begin
null;
end;
/
prompt --application/shared_components/plugins/region_type/pivot
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(7116674869879485)
,p_plugin_type=>'REGION TYPE'
,p_name=>'PIVOT'
,p_display_name=>'Pivot plug-in'
,p_supported_ui_types=>'DESKTOP'
,p_render_function=>'dev.render_plugin_pivot.render'
,p_standard_attributes=>'SOURCE_SQL:SOURCE_REQUIRED:NO_DATA_FOUND_MESSAGE'
,p_sql_min_column_count=>1
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_version_identifier=>'1.0'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(7189269355783519)
,p_plugin_id=>wwv_flow_api.id(7116674869879485)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Aggregate function type'
,p_attribute_type=>'CHECKBOXES'
,p_is_required=>true
,p_default_value=>'sum'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Choose aggregate function for pivot. Default value is "Sum".'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(7189892023784643)
,p_plugin_attribute_id=>wwv_flow_api.id(7189269355783519)
,p_display_sequence=>10
,p_display_value=>'Sum'
,p_return_value=>'sum'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(7190321121785932)
,p_plugin_attribute_id=>wwv_flow_api.id(7189269355783519)
,p_display_sequence=>20
,p_display_value=>'Count'
,p_return_value=>'count'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(7190636785787049)
,p_plugin_attribute_id=>wwv_flow_api.id(7189269355783519)
,p_display_sequence=>30
,p_display_value=>'Average'
,p_return_value=>'avg'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(7191094388789408)
,p_plugin_attribute_id=>wwv_flow_api.id(7189269355783519)
,p_display_sequence=>40
,p_display_value=>'Concatenation'
,p_return_value=>'listagg'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(3653465928156785)
,p_plugin_id=>wwv_flow_api.id(7116674869879485)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Max categories count'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_display_length=>5
,p_supported_ui_types=>'DESKTOP'
,p_is_translatable=>false
,p_help_text=>'Define maximum count of category columns. If query returns too much of categories, report contains only first "Max categories count" of them. Use NULL to output all categories.'
);
end;
/
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false), p_is_component_import => true);
commit;
end;
/
set verify on feedback on define on
prompt  ...done
