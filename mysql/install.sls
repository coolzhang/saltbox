#{% set mysql_version = "Percona-Server-5.7.13-6-Linux.x86_64.ssl101" %}
{% set mysql_version = "Percona-Server-5.6.30-rel76.3-Linux.x86_64.ssl101" %}
{% set mycnf = "my.56.cnf" %}
{% set instance = grains['id'].split('-')[3].split('_')|length %}
{% set bp = (grains['mem_total'] / instance / 1000 * 0.64)|round|int %}
{% set server_id = grains['server_id'] %}
{% set softdir = "sofeware directory" %}

useradd-mysql:
  user.present:
    - name: mysql
    - shell: /sbin/nologin
    - home: /home/mysql
    - order: 1

mysql-binary-pkg:
  file.managed:
    - name: /tmp/{{ mysql_version }}.tar.gz
    - source: salt://pkg/{{ mysql_version }}.tar.gz
    - onlyif: test ! -e {{ softdir }}/mysql

grcat-pkg:
  file.managed:
    - name: /usr/bin/grcat
    - source: salt://pkg/grcat
    - mode: 755

grcat-conf:
  file.managed:
    - name: /root/.grcat
    - source: salt://pkg/grcat.conf
    - mode: 755

mkdir-basedir:
  file.directory:
    - name: {{ softdir }}
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: True
    - recurse:
      - user
      - group
      - mode
  cmd.run:
    - name: tar -xzf {{ mysql_version }}.tar.gz -C {{ softdir }} && mv {{ softdir }}/{{ mysql_version }} {{ softdir }}/mysql
    - cwd: /tmp
    - onlyif: test ! -e {{ softdir }}/mysql
    - require:
      - file: mysql-binary-pkg
      - file: mkdir-basedir

chown-basedir:
  file.directory:
    - name: {{ softdir }}/mysql
    - user: root
    - group: root
    - dir_mode: 755
    - recurse:
      - user
      - group
      - mode
    - require:
      - cmd: mkdir-basedir

{% for port in grains['id'].split('-')[3].split('_') %}
{% set sid = server_id %}

mkdir-datadir{{ port }}:
  file.directory:
    - name: /data/mysql{{ port }}
    - user: mysql
    - group: mysql
    - dir_mode: 755
    - makedirs: True

initDB{{ port }}:
  cmd.run:
    {% if "5.7" in mysql_version %}
    - name: mv /data/mysql{{ port }}/my{{ port }}.cnf /data/tmp/;bin/mysqld --defaults-file=/data/tmp/my{{ port }}.cnf --initialize-insecure --user=mysql >/dev/null 2>&1;mv /data/tmp/my{{ port }}.cnf /data/mysql{{ port }}/
    {% else %}
    - name: scripts/mysql_install_db --defaults-file=/data/mysql{{ port }}/my{{ port }}.cnf --user=mysql >/dev/null 2>&1
    {% endif %}
    - cwd: {{ softdir }}/mysql
    - onlyif: test ! -e /data/mysql{{ port }}/mysql
    - require:
      - file: mkdir-basedir
      - file: mkdir-datadir{{ port }}
      - file: mkdir-tmpdir
      - file: my{{ port }}.cnf

boot-startup{{ port }}:
  file.append:
    - name: /etc/rc.local
    - text: |
        # mysqld{{ port }} startup
        cd {{ softdir }}/mysql;bin/mysqld_safe --defaults-file=/data/mysql{{ port }}/my{{ port }}.cnf --user=mysql &

my{{ port }}.cnf:
  file.managed:
    - name: /data/mysql{{ port }}/my{{ port }}.cnf
    - source: salt://conf/mysql/{{ mycnf }}
    - template: jinja
    - context:
      {% if 'mysqlslave' in grains['id'] %}
        read_only: 1
        log_slave_updates: 0
      {% endif %}
      {% if 'Percona' in mysql_version %}
        thread_handling: thread_handling                = pool-of-threads
        thread_pool_size: thread_pool_size               = 16
      {% endif %}
      {% if "5.7" in mysql_version %}
        log_timestamps: log_timestamps                 = SYSTEM
      {% endif %}
    - defaults:
        basedir: {{ softdir }}/mysql
        port: {{ port }}
        innodb_buffer_pool_size: {{ bp }}G
        server_id: {{ sid }}
        read_only: 0
        report_host: {{ grains['id'].split('-')[2] }}
        report_port: {{ port }}
        thread_handling: ''
        thread_pool_size: ''
        log_slave_updates: 1
        log_timestamps: ''
    - require:
      - file: mkdir-datadir{{ port }}

startup-mysqld{{ port }}:
  cmd.run:
    - name: echo deadline > /sys/block/vdb/queue/scheduler;echo 0 > /proc/sys/vm/swappiness;cd {{ softdir }}/mysql;bin/mysqld_safe --defaults-file=/data/mysql{{ port }}/my{{ port }}.cnf --user=mysql >/dev/null 2>&1 & 
    - unless: ps -ef |grep -v grep |grep -w {{ port }} > /dev/null
    - require:
      - file: my{{ port }}.cnf
      - cmd: initDB{{ port }}

{% set server_id = server_id + 1 %}
{% endfor %}

os-env:
  file.append:
    - name: /etc/rc.local
    - text: |
       
        echo deadline > /sys/block/vdb/queue/scheduler 
        echo 0 > /proc/sys/vm/swappiness

mysql-env:
  file.append:
    - name: /root/.bash_profile
    - text: |

        MYSQL_UNIX_PORT=/data/mysql{{ grains['id'].split('-')[3].split('_')[0] }}/mysql.sock
        export MYSQL_UNIX_PORT
  cmd.run:
    - name: sed -i -e '/^PATH=/ s#:{{ softdir }}/mysql/bin##g' -e '/^PATH=/ s#$#:{{ softdir }}/mysql/bin#' /root/.bash_profile; echo "[mysql]" > /etc/my.cnf; echo 'prompt="\D \U [\d]> "' >> /etc/my.cnf; echo 'pager=grcat ~/.grcat | less -RSFXin' >> /etc/my.cnf; echo 'tee=/data/tmp/mysqlop.log' >> /etc/my.cnf;echo "mysql  -    nofile 100001" >> /etc/security/limits.conf; echo "mysql  -    nproc  10240" >> /etc/security/limits.conf
    - unless: grep '{{ softdir }}/mysql/bin' /root/.bash_profile

mkdir-tmpdir:
  file.directory:
    - name: /data/tmp
    - user: mysql
    - group: mysql
    - dir_mode: 755
    - makedirs: True

cleanup:
  cmd.run:
    - name: rm -f /tmp/{{ mysql_version }}.tar.gz
    - onlyif: test -e /tmp/{{ mysql_version }}.tar.gz
    - order: last
