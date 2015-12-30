create or replace package body render_plugin_pivot as

type varchar_table is table of varchar2(32000) index by binary_integer;

type t_region_properties is record (
  source_sql       varchar2(32767),
  aggregates_list  varchar_table,
  categories_count number,
  sort_categories  varchar2(100),
  totals_in_rows   boolean,
  totals_in_cols   boolean
);

/* Replaces up to 5 values         */
function multi_replace(p_source        in varchar2,
                       p_string1       in varchar2,
                       p_replace_with1 in varchar2,
                       p_string2       in varchar2 default null,
                       p_replace_with2 in varchar2 default null,
                       p_string3       in varchar2 default null,
                       p_replace_with3 in varchar2 default null,
                       p_string4       in varchar2 default null,
                       p_replace_with4 in varchar2 default null,
                       p_string5       in varchar2 default null,
                       p_replace_with5 in varchar2 default null) return varchar2 is
  result varchar2(32767);
begin
  result := replace(p_source, p_string1, p_replace_with1);
  if p_string2 is not null then
     result := replace(result, p_string2, p_replace_with2);
  end if;
  if p_string3 is not null then
     result := replace(result, p_string3, p_replace_with3);
  end if;
  if p_string4 is not null then
     result := replace(result, p_string4, p_replace_with4);
  end if;
  if p_string5 is not null then
     result := replace(result, p_string5, p_replace_with5);
  end if;
  return result;
end;

/* Removes unnecessary columns CATEGORY and VALUE from columns list collection  */
function remove_unused (p_coll in dbms_sql.desc_tab) return dbms_sql.desc_tab is
  new_coll dbms_sql.desc_tab;
begin
  for i in p_coll.first .. p_coll.last loop
    if p_coll(i).col_name not in ('CATEGORY', 'VALUE') then
       new_coll(nvl(new_coll.count, 0) + 1) := p_coll(i);
    end if;
  end loop;
  return new_coll;
end;

/* Searches for column with name P_COLUMN_NAME in collection P_COLL.
   Raises an exception if not found.                                 */
procedure check_column_presence(p_coll        in dbms_sql.desc_tab,
                                p_column_name in varchar2) is

  col_number number;
begin
  for i in p_coll.first .. p_coll.last loop
    if p_coll(i).col_name = p_column_name then
       col_number := i;
    end if;
  end loop;
  
  if col_number is null then
     raise_application_error(-20000, 'Column ' || p_column_name || ' is not present in the source SQL query of the Pivot plug-in.');
  end if;
end;

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

  check_column_presence(columns_list, 'CATEGORY');
  check_column_presence(columns_list, 'VALUE');
  if columns_list.count < 3 then
     raise_application_error(-20001, 'Source query have to contain at least 3 columns.');
  end if;
  
  return columns_list;
exception
  when others then
    if dbms_sql.is_open(source_cursor) then
       dbms_sql.close_cursor(source_cursor);
    end if;
    raise;
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
        case when p_columns(j).col_type = 1  then '''' || replace(p_data(j)(i), '''', '''''') || ''''
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

/* Builds pivot query for given aggregate function    */
function get_pivot_query(p_aggr_function    in varchar2,
                         p_categories_list  in varchar2) return varchar2 is
  pivot_query varchar2(4000);
  
begin
  pivot_query := 'select * from ' || temp_pivot_table || ' pivot (' ||
      case when p_aggr_function = 'sum'     then 'sum(value) ' 
           when p_aggr_function = 'count'   then 'count(value) ' 
           when p_aggr_function = 'avg'     then 'avg(value) ' 
           when p_aggr_function = 'listagg' then 'listagg(value, '', '') within group (order by value) ' 
           end || 
      ' for category in (' || p_categories_list || '))';
  
  return pivot_query;
end;

/* Outputs to a page a single pivot report */
procedure output_single_aggregate_pivot(p_sql           in varchar2,
                                        p_columns       in dbms_sql.desc_tab,
                                        p_categories    in varchar_table,
                                        p_aggr_list     in varchar_table) is
  source_cursor    number;
  col_count        number;
  columns_list     dbms_sql.desc_tab;
  str_var          varchar2(4000);
  num_var          number;
  dat_var          date;
  head_template    varchar2(100) := '<td class="t-Report-colHead" id="#COLUMN_HEADER_NAME#" #ALIGNMENT#>#COLUMN_HEADER#</th>';
  cell_template    varchar2(100) := '<td class="t-Report-cell" #ALIGNMENT#>#COLUMN_VALUE#</td>';
  cell_text        varchar2(4000);
begin
  source_cursor := dbms_sql.open_cursor;
  dbms_sql.parse(source_cursor, p_sql, 1);
  dbms_sql.describe_columns(source_cursor, col_count, columns_list);
    
  htp.p('<table class="t-Report-report"><thead><tr>');
  for i in columns_list.first .. columns_list.last loop
    case when columns_list(i).col_type =  1 then dbms_sql.define_column(source_cursor, i, str_var, 4000);
         when columns_list(i).col_type =  2 then dbms_sql.define_column(source_cursor, i, num_var);
         when columns_list(i).col_type = 12 then dbms_sql.define_column(source_cursor, i, dat_var);
    end case;
  end loop;

  if p_aggr_list.count = 1 then
     -- single pivot query header
     for i in columns_list.first .. columns_list.last loop
       htp.p(multi_replace(head_template, '#COLUMN_HEADER_NAME#', columns_list(i).col_name, 
                                          '#COLUMN_HEADER#',      columns_list(i).col_name,
                                          '#ALIGNMENT#',          ''));
     end loop;
  else
     -- multiple pivot query header
     for i in p_columns.first .. p_columns.last loop
       htp.p(multi_replace(head_template, '#COLUMN_HEADER_NAME#', p_columns(i).col_name, 
                                          '#COLUMN_HEADER#',      p_columns(i).col_name,
                                          '#ALIGNMENT#',          ' rowspan="2"'));
     end loop;
     
     for i in p_categories.first .. p_categories.last loop
       htp.p(multi_replace(head_template, '#COLUMN_HEADER_NAME#', p_categories(i), 
                                          '#COLUMN_HEADER#',      p_categories(i),
                                          '#ALIGNMENT#',          ' colspan="' || p_aggr_list.count || '"'));
     end loop;
     
     htp.p('</tr>');
     
     for i in p_categories.first .. p_categories.last loop
       for j in p_aggr_list.first .. p_aggr_list.last loop
         htp.p(multi_replace(head_template, '#COLUMN_HEADER_NAME#', '', 
                                            '#COLUMN_HEADER#',      p_aggr_list(j),
                                            '#ALIGNMENT#',          ''));
       end loop;
     end loop;

  end if;
  htp.p('</tr></thead><tbody>');
 
  num_var := dbms_sql.execute(source_cursor);
  while dbms_sql.fetch_rows(source_cursor) > 0 loop
    htp.p('<tr>');
      for i in columns_list.first .. columns_list.last loop
        case when columns_list(i).col_type =  1 then 
                  dbms_sql.column_value(source_cursor, i, str_var);
                  cell_text := replace(replace(cell_template, '#ALIGNMENT#', ''), '#COLUMN_VALUE#', str_var);
             when columns_list(i).col_type =  2 then 
                  dbms_sql.column_value(source_cursor, i, num_var);
                  cell_text := replace(replace(cell_template, '#ALIGNMENT#', 'align="right"'), '#COLUMN_VALUE#', num_var);
             when columns_list(i).col_type = 12 then dbms_sql.column_value(source_cursor, i, dat_var);
                  cell_text := replace(replace(cell_template, '#ALIGNMENT#', 'align="center"'), '#COLUMN_VALUE#', dat_var);
        end case;
        htp.p(cell_text);
      end loop;
    htp.p('</tr>');
  end loop;
  htp.p('</tbody></table>');
  
  dbms_sql.close_cursor(source_cursor);
exception
  when others then
    if dbms_sql.is_open(source_cursor) then
       dbms_sql.close_cursor(source_cursor);
    end if;
    raise;
end;

function get_multi_pivot_query(p_queries         in varchar_table,
                               p_columns         in dbms_sql.desc_tab,
                               p_categories      in varchar_table) return varchar2 is
  uni_query varchar2(32767) := 'select ';
begin
  -- SELECT clause
  for i in p_columns.first .. p_columns.last loop
    uni_query := uni_query || 't1.' || p_columns(i).col_name || ' "' || p_columns(i).col_name || '", ';
  end loop;

  for j in p_categories.first .. p_categories.last loop
    for i in p_queries.first .. p_queries.last loop
      uni_query := uni_query || 't' || i || '."' || p_categories(j) || '" "' || 't' || i || '_' || p_categories(j) || '"';
      
      if i = p_queries.last and j = p_categories.last then
         uni_query := uni_query || chr(10) || ' from ';
      else
         uni_query := uni_query || ', ';
      end if;
    end loop;
  end loop;

  -- FROM clause
  for i in p_queries.first .. p_queries.last loop
    uni_query := uni_query || ' (' || p_queries(i) || ') t' || i;
    if i = p_queries.last then
       uni_query := uni_query || chr(10) || ' where ';
    else
       uni_query := uni_query || ', ' || chr(10);
    end if;
  end loop;
  
  -- WHERE clause
  for i in p_columns.first .. p_columns.last loop
    for j in (p_queries.first + 1) .. p_queries.last loop
      uni_query := uni_query || 't1.' || p_columns(i).col_name || ' = t' || j || '.' || p_columns(i).col_name;
      if not (i = p_columns.last and j = p_queries.last) then
         uni_query := uni_query || ' and ';
     end if;
    end loop;
  end loop;
  
  return uni_query;
end;

/* Transform custom region plugin properites to appropriate format     */
function get_region_properties (p_region in apex_plugin.t_region) return t_region_properties is
  p t_region_properties;
begin
  p.source_sql := p_region.source;

  -- get list of aggregate functions for pivot:
  select regexp_substr(p_region.attribute_01,'[^:]+', 1, level) 
    bulk collect into p.aggregates_list
    from dual
 connect by regexp_substr(p_region.attribute_01,'[^:]+', 1, level) is not null;
  
  p.categories_count := to_number(p_region.attribute_02);
  p.sort_categories := p_region.attribute_03;
  p.totals_in_rows := nvl(instr(p_region.attribute_04, 'rows') > 0, false);
  p.totals_in_cols := nvl(instr(p_region.attribute_04, 'cols') > 0, false);
  return p;
end;

/* Main render function for pivot plug-in                           
     render flow:
      - define columns: 
           column 'category' for categories
           column 'value' for aggregate function
      - define list of aggregate function
      - data calculation
      - define sorting direction for categories
      - data sorting
      - output                             */
function render(
  p_region              in apex_plugin.t_region,
  p_plugin              in apex_plugin.t_plugin,
  p_is_printer_friendly in boolean) return apex_plugin.t_region_render_result is

  categories_list  varchar_table;
  pivot_queries    varchar_table;
  header_html      varchar2(32767);
  
  query_result     apex_plugin_util.t_column_value_list;
  category_count   number;
  columns_list     dbms_sql.desc_tab;
  temp_created     boolean;
  sort_categories  varchar2(4000);
  categories_sql   varchar2(4000);
  final_query      varchar2(32000);
  reg_properties   t_region_properties;
begin
  reg_properties := get_region_properties(p_region);
  
  columns_list := get_columns(reg_properties.source_sql);
  
  query_result := apex_plugin_util.get_data (
      p_sql_statement      => reg_properties.source_sql,
      p_min_columns        => 1,
      p_max_columns        => 20,
      p_component_name     => p_region.name,
      p_search_type        => null,
      p_search_column_name => null,
      p_search_string      => null);

  temp_created := create_temp_table(columns_list, query_result);
  columns_list := remove_unused(columns_list);

  -- get distinct list of categories:
  execute immediate 'select distinct category from ' || temp_pivot_table || reg_properties.sort_categories
    bulk collect into categories_list;
  
  -- calculate categories count for output:
  category_count := least(nvl(to_number(reg_properties.categories_count), categories_list.count), categories_list.count);
  for i in categories_list.first .. category_count loop
    categories_sql := categories_sql || '''' || replace(categories_list(i), '''', '''''') || ''' "' || categories_list(i);
    if i = category_count then
       categories_sql := categories_sql || '"';
    else
       categories_sql := categories_sql || '", ';
    end if;
  end loop;
  
  for i in reg_properties.aggregates_list.first .. reg_properties.aggregates_list.last loop
    pivot_queries(i) := get_pivot_query(reg_properties.aggregates_list(i), categories_sql);
--    htp.p('pivot query for ' || aggregates_list(i) || ' is: ' || get_pivot_query(aggregates_list(i), categories_sql) || '<br>' || '<br>');
  end loop;

  -- output single query result:
  if pivot_queries.count = 1 then
     final_query := pivot_queries(pivot_queries.first);
  else
     final_query := get_multi_pivot_query(pivot_queries, columns_list, categories_list);
  end if;
  output_single_aggregate_pivot(final_query, columns_list, categories_list, reg_properties.aggregates_list);

 -- drop_temp_table;
  return null;
exception
  when others then
    if temp_created then 
       drop_temp_table;
    end if;
    return null;
 /*   raise;*/
end;

procedure create_demo is
  demo_already_exists exception;
  pragma exception_init (demo_already_exists, -955);
begin
  execute immediate 'create table fruit (id number, name varchar2(20))';
  execute immediate 'create table sale (fruit_id number, cost number, sale_date date)';
  execute immediate 'insert into fruit (id, name) values (1, ''apple'')';
  execute immediate 'insert into fruit (id, name) values (2, ''orange'')';
  execute immediate 'insert into fruit (id, name) values (3, ''mango'')';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(1, 100, to_date(''01.01.2016'', ''dd.mm.yyyy''))';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(1, 200, to_date(''05.01.2016'', ''dd.mm.yyyy''))';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(1,  50, to_date(''01.02.2016'', ''dd.mm.yyyy''))';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(2,  30, to_date(''01.01.2016'', ''dd.mm.yyyy''))';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(2,  90, to_date(''12.02.2016'', ''dd.mm.yyyy''))';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(2, 135, to_date(''01.03.2016'', ''dd.mm.yyyy''))';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(2,  55, to_date(''11.01.2016'', ''dd.mm.yyyy''))';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(3,  95, to_date(''01.02.2016'', ''dd.mm.yyyy''))';
  execute immediate 'insert into sale (fruit_id, cost, sale_date) values(3, 115, to_date(''15.03.2016'', ''dd.mm.yyyy''))';  
exception
  when demo_already_exists then
    raise_application_error(-20999, 'Unable to create demo tables. Check if demo already exists.');
end;

end render_plugin_pivot;