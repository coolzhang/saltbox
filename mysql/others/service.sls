{% set password = "xxxxx" %}
{% basedir = "mysql software path" %}

stop:
  cmd.run:
    - name: {{ basedir }}/bin/mysqladmin -uroot -p{{ password }} -S/data/mysql{{ grains['id'].split('-')[3] }}/mysql.sock shutdown
    - onlyif: pgrep mysqld > /dev/null
    - order: 1

start:
  cmd.run:
    - name: cd {{ basedir }};bin/mysqld_safe --defaults-file=/data/mysql{{ grains['id'].split('-')[3] }}/my{{ grains['id'].split('-')[3] }}.cnf --user=mysql >/dev/null 2>&1 &
    - unless: pgrep mysqld > /dev/null
    - require:
      - cmd: stop
