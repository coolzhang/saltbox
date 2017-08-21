{% set mysql_version = "Percona-Server-5.6.25-rel73.1-Linux.x86_64.ssl101" %}
{% set mycnf = "my.cnf" %}
{% set bp = "1G" %}
{% set ports = [3308] %}

{% if ports %}
{% for port in ports %}
datadir-{{ port }}:
  file.directory:
    - name: /data/mysql{{ port }}
    - user: mysql
    - group: mysql
    - dir_mode: 755
    - makedirs: True
    - order: 1

my.cnf-{{ port }}:
  file.managed:
    - name: /data/mysql{{ port }}/my{{ port }}.cnf
    - source: salt://conf/mysql/{{ mycnf }}
    - template: jinja
    - context:
      {% if 'slave' in grains['id'] %}
        read_only: 1
      {% endif %}
      {% if 'Percona' in mysql_version %}
        thread_handling: thread_handling                = pool-of-threads
      {% endif %}
    - defaults:
        port: {{ port }}
        innodb_buffer_pool_size: {{ bp }}
        server_id: {{ grains['server_id'] }}
        read_only: 0
        report_host: {{ grains['id'].split('-')[2] }}
        report_port: {{ port }}
        thread_handling: ''
    - onlyif: test ! -e /data/mysql{{ port }}/my{{ port }}.cnf
    - require:
      - file: datadir-{{ port }}

initDB-{{ port }}:
  cmd.run:
    - name: scripts/mysql_install_db --defaults-file=/data/mysql{{ port }}/my{{ port }}.cnf --user=mysql >/dev/null 2>&1
    - cwd: /data/soft/mysql
    - onlyif: test ! -e /data/mysql{{ port }}/mysql
    - require:
      - file: datadir-{{ port }}
      - file: my.cnf-{{ port }}

startup-mysqld-{{ port }}:
  cmd.run:
    - name: cd /data/soft/mysql;bin/mysqld_safe --defaults-file=/data/mysql{{ port }}/my{{ port }}.cnf --user=mysql >/dev/null 2>&1 &
    - unless: ps -ef |grep {{ port }} |grep -v grep > /dev/null
    - require:
      - cmd: initDB-{{ port }}

auto-startup-{{ port }}:
  file.append:
    - name: /etc/rc.local
    - text: |

        # mysqld{{ port }} startup
        cd /data/soft/mysql;bin/mysqld_safe --defaults-file=/data/mysql{{ port }}/my{{ port }}.cnf --user=mysql &
    - require:
      - cmd: startup-mysqld-{{ port }}
{% endfor %}
{% endif %}
