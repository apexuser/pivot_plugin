create or replace package body render_plugin_pivot as

function render(
  p_region              in apex_plugin.t_region,
  p_plugin              in apex_plugin.t_plugin,
  p_is_printer_friendly in boolean) return apex_plugin.t_region_render_result is
begin
  /* render flow:
      - define columns: 
           column 'category' for categories
           column 'value' for aggregate function
      - define list of aggregate function
      - data calculation
      - define sorting direction for categories
      - data sorting
      - output        */
  
  
  
  return null;
end;

end render_plugin_pivot;