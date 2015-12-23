create or replace package render_plugin_pivot as

temp_pivot_table varchar2(30) := 'TEMP_PIVOT_TABLE';

function render(
  p_region              in apex_plugin.t_region,
  p_plugin              in apex_plugin.t_plugin,
  p_is_printer_friendly in boolean) return apex_plugin.t_region_render_result;
  

end render_plugin_pivot;