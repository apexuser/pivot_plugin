-- demo query #1
select f.name, to_char(trunc(s.sale_date, 'mm'), 'dd month yyyy', 'NLS_DATE_LANGUAGE=russian') category, s.cost value
from dev.fruit f, dev.sale s
where f.id = s.fruit_id;

-- demo query #2
select f.name category, to_char(trunc(s.sale_date, 'mm'), 'dd month yyyy', 'NLS_DATE_LANGUAGE=russian') sale_date, s.cost value
from dev.fruit f, dev.sale s
where f.id = s.fruit_id;