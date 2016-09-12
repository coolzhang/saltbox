{% set basedir = "mysql software path" %}
{% set master_mid = "" %}
{% set rootpass= "" %}

{% if master_mid %}
{% for port in grains['id'].split('-')[3].split('_') %}
grant-user{{ port }}:
  cmd.run:
    - name: {{ basedir }}/bin/mysql -uroot -S /data/mysql{{ port }}/mysql.sock -e "set password=password('{{ rootpass }}');DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost');DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;grant replication slave, replication client on *.* to 'repl_user'@'%' identified by 'repl_password';GRANT SELECT, SUPER, PROCESS, REPLICATION CLIENT ON *.* TO 'mpm_user'@'127.0.0.1' identified BY 'mpm_password';grant select on *.* to restore@localhost identified by 'xxxxxxxx';grant all on *.* to admin@'10.%' identified by 'xxxxxxxx';grant all on *.* to admin@localhost identified by 'xxxxxxxxxxx';GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO 'anemometer'@'%' IDENTIFIED BY 'xxxxxxxx';reset master"
    - onlyif: {{ basedir }}/bin/mysql -uroot -S /data/mysql{{ port }}/mysql.sock -e "select @@port" |grep {{ port }} >  /dev/null

{% if 'slave' in grains['id'] %}
change-master{{ port }}:
  cmd.run:
    - name: {{ basedir }}/bin/mysql -uroot -p{{ rootpass }} -S /data/mysql{{ port }}/mysql.sock -e "CHANGE MASTER TO MASTER_HOST='{{ master_mid.split('-')[2] }}', MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_PORT={{ port }}, MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=120;start slave"
    - unless: {{ basedir }}/bin/mysql -uroot -p{{ rootpass }} -S /data/mysql{{ port }}/mysql.sock -NBe "show slave status\G" |grep {{ master_mid.split('-')[2] }} > /dev/null
    - require:
      - cmd: grant-user{{ port }}
{% endif %}

{% endfor %}
{% endif %}
