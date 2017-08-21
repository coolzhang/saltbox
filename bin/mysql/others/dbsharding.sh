#!/bin/bash
#
#

db_name=reduce
table_name=reduorder
key_name=updtm
col_name=upd_tm

# For bonus
# Instance count: 4 ( 32 tables per instance), DB count: 16 (4 dbs per instance), Table count: 128 (8 tables per db)
for i in {0..127}
do
instance_no=$(($i / 32))
db_index=$(($i / 8))
table_index=$i
case ${instance_no} in
"0") echo "alter table ${db_name}_${db_index}.${table_name}_${table_index} add index idx_${key_name}(${col_name});" >> ${instance_no}.sql;;
"1") echo "alter table ${db_name}_${db_index}.${table_name}_${table_index} add index idx_${key_name}(${col_name});" >> ${instance_no}.sql;;
"2") echo "alter table ${db_name}_${db_index}.${table_name}_${table_index} add index idx_${key_name}(${col_name});" >> ${instance_no}.sql;;
"3") echo "alter table ${db_name}_${db_index}.${table_name}_${table_index} add index idx_${key_name}(${col_name});" >> ${instance_no}.sql;;
esac
done

