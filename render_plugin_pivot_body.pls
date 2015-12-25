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
exception
  when others then
    if dbms_sql.is_open(source_cursor) then
       dbms_sql.close_cursor(source_cursor);
    end if;
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
     raise_application_error(-20001, 'Column ' || p_column_name || ' is not present in the source SQL query of Pivot plug-in.');
  end if;

  return col_number;
end;

/* Drops temporary table. */
procedure drop_temp_table is
begin
  execute immediate 'drop table ' || temp_pivot_table;
end;

/* Creates a temporary table for the query result. 
   Checks, if table already exists. */
function create_temp_table(p_columns in dbms_sql.desc_tab,
                           p_data    in apex_plugin_util.t_column_value_list) return boolean is
  cnt number;
  
  create_table_sql    varchar2(32767) := 'create table ' || temp_pivot_table || '(';
  insert_sql          varchar2(4000);
begin
  -- check: if table exists (not deleted from previous run) - drop it
  select count(*)
    into cnt
    from user_tables
   where table_name = temp_pivot_table;

  if cnt > 0 then
     drop_temp_table;
  end if;

  -- create table script
  for i in p_columns.first .. p_columns.last loop
    create_table_sql := create_table_sql || p_columns(i).col_name || ' ';
    create_table_sql := create_table_sql || 
      case when p_columns(i).col_type = 1  then 'varchar2(4000)'
           when p_columns(i).col_type = 2  then 'number'
           when p_columns(i).col_type = 12 then 'date'
      end;
    if i = p_columns.last then
       create_table_sql := create_table_sql || ')';
    else
       create_table_sql := create_table_sql || ', ';
    end if;
  end loop;
  execute immediate create_table_sql;

  -- fill the table
  for i in p_data(p_data.first).first .. p_data(p_data.first).last loop
    insert_sql :='insert into ' || temp_pivot_table || ' values (';
    for j in p_data.first .. p_data.last loop
      insert_sql := insert_sql ||
        case when p_columns(j).col_type = 1  then '''' || p_data(j)(i) || ''''
             when p_columns(j).col_type = 2  then p_data(j)(i)
             when p_columns(j).col_type = 12 then 'to_date(''' || p_data(j)(i) || ''')'
        end;
      if j = p_data.last then
         insert_sql := insert_sql || ')';
      else
         insert_sql := insert_sql || ', ';
      end if;
    end loop;
    execute immediate insert_sql;
  end loop;

  return true;
end;

/* Main render function for pivot plug-in                           */
function render(
  p_region              in apex_plugin.t_region,
  p_plugin              in apex_plugin.t_plugin,
  p_is_printer_friendly in boolean) return apex_plugin.t_region_render_result is

  type category_table is table of varchar2(4000) index by binary_integer;
  categories_list  category_table;
  --source_query  varchar2(32767);
  header_html      varchar2(32767);
  
  query_result     apex_plugin_util.t_column_value_list;
  category_count   number;
  category_col_num number;
  value_col_num    number;
  columns_list     dbms_sql.desc_tab;
  i                number;
  s                varchar2(4000);
  temp_created     boolean;
  sort_categories  varchar2(100);
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
  --htp.p(p_region.source || '<br>');
  columns_list := get_columns(p_region.source);
  
  
  --  DEBUG PRINT COLUMNS LIST
  for i in columns_list.first .. columns_list.last loop
    htp.p(' column = ' || columns_list(i).col_name || ' type = ' || columns_list(i).col_type || '<br>');
  end loop;
  
  category_col_num := get_column_index(columns_list, 'CATEGORY');
  value_col_num    := get_column_index(columns_list, 'VALUE');

  query_result := apex_plugin_util.get_data (
      p_sql_statement      => p_region.source,
      p_min_columns        => 1,
      p_max_columns        => 20,
      p_component_name     => p_region.name,
      p_search_type        => null,
      p_search_column_name => null,
      p_search_string      => null);

  temp_created := create_temp_table(columns_list, query_result);
  
  sort_categories := case when p_region.attribute_03 = 'asc'  then ' order by category'
                          when p_region.attribute_03 = 'desc' then ' order by category desc' end;
  -- get distinct list of categories:
  execute immediate 'select distinct category from ' || temp_pivot_table || sort_categories 
    bulk collect into categories_list;
  
  -- calculate categories count for output:
  category_count := nvl(to_number(p_region.attribute_02), categories_list.count);
  




  for i in categories_list.first .. categories_list.last loop
    htp.p('i = ' || i || ' cat = ' || categories_list(i) || '<br>');
  end loop;

  
  

  
  
/*  
  s := categories_list.first;
  while s is not null loop
    htp.p('s = ' || s || ' category = ' || categories_list(s) || '<br>');
    s := categories_list.next(s);
  end loop;*/
  /*
  for i in categories_list.first .. categories_list.last loop
    htp.p('i = ' || i || ' category = ' || categories_list(i) || '<br>');
  
  end loop;
  */
  -- test output:
  /*
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
  */
  
  drop_temp_table;
  return null;
exception
  when others then
    if temp_created then 
       drop_temp_table;
    end if;
    raise;
    --htp.p(replace(dbms_utility.format_error_backtrace, chr(10), '<br>'));
    --return null;
end;

end render_plugin_pivot;