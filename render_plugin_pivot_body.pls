create or replace package body render_plugin_pivot as

/* parses the region source query and returns the list of columns  */
function get_columns (p_sql in varchar2) return dbms_sql.desc_tab is
  source_cursor    number;
  col_count        number;
  columns_list     dbms_sql.desc_tab;
begin
  source_cursor := dbms_sql.open_cursor;
  dbms_sql.parse(source_cursor, p_sql, 1);
  dbms_sql.describe_columns(source_cursor, col_count, columns_list);
  dbms_sql.close_cursor(source_cursor);

  return columns_list;
end;

/* Searches for column with name P_COLUMN_NAME in collection P_COLL.
   Raises an exception if not found.                                 */
function get_column_index(p_coll        in dbms_sql.desc_tab,
                          p_column_name in varchar2) return number is

  col_number number;
begin
  for i in p_coll.first .. p_coll.last loop
    if p_coll(i).col_name = p_column_name then
       col_number := i;
    end if;
  end loop;
  
  if col_number is null then
     raise_application_error(-20001, 'column not found');
  end if;

  return col_number;
end;

/* Main render function for pivot plug-in                           */
function render(
  p_region              in apex_plugin.t_region,
  p_plugin              in apex_plugin.t_plugin,
  p_is_printer_friendly in boolean) return apex_plugin.t_region_render_result is

  --source_query  varchar2(32767);
  header_html      varchar2(32767);
  
  query_result     apex_plugin_util.t_column_value_list;
  category_count   number;
  category_col_num number;
  value_col_num    number;
  columns_list     dbms_sql.desc_tab;
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
  
  --source_query := substr(p_region.source, 16, length(p_region.source) - 17);
  --htp.p(source_query);
  columns_list := get_columns(p_region.source);
  
  category_col_num := get_column_index(columns_list, 'category');
  value_col_num    := get_column_index(columns_list, 'value');
    
  
  
  query_result := apex_plugin_util.get_data (
      p_sql_statement      => p_region.source,
      p_min_columns        => 1,
      p_max_columns        => 20,
      p_component_name     => p_region.name,
      p_search_type        => null,
      p_search_column_name => null,
      p_search_string      => null);
  
  
  
  
  
  -- test output:
  htp.p('<table class="t-Report-report" summary="' || p_region.name || '">');
  htp.p(header_html);
  htp.p('<tbody></tbody></table><br>');

  htp.p('t_plugin output<br>');
  htp.p('name = ' || p_plugin.name || '<br>');
  htp.p('file_prefix = ' || p_plugin.file_prefix || '<br>');
  htp.p('attribute_01 = ' || p_plugin.attribute_01 || '<br>');
  htp.p('attribute_02 = ' || p_plugin.attribute_02 || '<br>');
  htp.p('attribute_03 = ' || p_plugin.attribute_03 || '<br>');
  htp.p('attribute_04 = ' || p_plugin.attribute_04 || '<br>');
  
  htp.p('p_region output<br>');
  htp.p('name = ' || p_region.name || '<br>');
  htp.p('id = ' || p_region.id || '<br>');
  htp.p('attribute_01 = ' || p_region.attribute_01 || '<br>');
  htp.p('attribute_02 = ' || p_region.attribute_02 || '<br>');
  htp.p('attribute_03 = ' || p_region.attribute_03 || '<br>');
  htp.p('attribute_04 = ' || p_region.attribute_04 || '<br>');
  
  return null;
exception
  when others then
  htp.p(dbms_utility.format_error_backtrace);
  return null;
end;
/*
function get_header_html (p_sql in varchar2) return varchar2 is
  source_cursor    number;
  col_count        number;
  columns_list     dbms_sql.desc_tab;
  html_header      varchar2(32767);
  i                number;
begin
  source_cursor := dbms_sql.open_cursor;
  dbms_sql.parse(source_cursor, p_sql, 1);
  dbms_sql.describe_columns(source_cursor, col_count, columns_list);
  dbms_sql.close_cursor(source_cursor);

  html_header := '<thead>';
  
  i := columns_list.first;
  while i is not null loop
    html_header := html_header || '<th class="t-Report-colHead" id="' || columns_list(i).col_name || '">' || columns_list(i).col_name || '</th>';
    i := columns_list.next(i);
  end loop;
  
  html_header := html_header || '</thead>';
  return html_header;
end;
*/
end render_plugin_pivot;