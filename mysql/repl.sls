{% set master_mid = "" %}
{% set rootpass= "" %}

{% if master_mid %}
{% for port in grains['id'].split('-')[3].split('_') %}
grant-user{{ port }}:
  cmd.run:
    - name: /data/soft/mysql/bin/mysql -uroot -S /data/mysql{{ port }}/mysql.sock -e "set password=password('{{ rootpass }}');DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost');DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;grant replication slave, replication client on *.* to 'repl'@'%' identified by 'repl';GRANT SELECT, SUPER, PROCESS, REPLICATION CLIENT ON *.* TO 'monitor'@'127.0.0.1' identified BY 'pass4monitor';GRANT SELECT, UPDATE, DELETE, DROP ON performance_schema.* TO 'monitor'@'127.0.0.1';grant select on *.* to restore@localhost identified by 'opencmug';grant all on *.* to admin@'10.%' identified by 'opencmug';revoke DROP, FILE, RELOAD, SHUTDOWN, SUPER on *.* from admin@'10.%';grant SELECT, SHOW VIEW, RELOAD, REPLICATION CLIENT, EVENT, TRIGGER, LOCK TABLES, PROCESS, SUPER on *.* to backup@localhost identified by 'opencmug';GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO 'anemometer'@'%' IDENTIFIED BY 'opencmug';reset master"
    - onlyif: /data/soft/mysql/bin/mysql -uroot -S /data/mysql{{ port }}/mysql.sock -e "select @@port" |grep {{ port }} >  /dev/null

{% if 'slave' in grains['id'] %}
change-master{{ port }}:
  cmd.run:
    - name: /data/soft/mysql/bin/mysql -uroot -p{{ rootpass }} -S /data/mysql{{ port }}/mysql.sock -e "CHANGE MASTER TO MASTER_HOST='{{ master_mid.split('-')[2] }}', MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_PORT={{ port }}, MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=120;start slave"
    - unless: /data/soft/mysql/bin/mysql -uroot -p{{ rootpass }} -S /data/mysql{{ port }}/mysql.sock -NBe "show slave status\G" |grep {{ master_mid.split('-')[2] }} > /dev/null
    - require:
      - cmd: grant-user{{ port }}
{% endif %}

{% endfor %}
{% endif %}
