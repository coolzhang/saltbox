{% set backuppass = "opencmug" %}

{% if backuppass %}
install-xtrabackup:
  pkg.installed:
    - pkgs:
      - perl
      - perl-DBD-MySQL
      - perl-DBI
      - perl-Time-HiRes
    - order: 1

{% for subdir in ['script','log','conf'] %}
mkdir-{{ subdir }}:
  file.directory:
    - name: /data/soft/dbadmin/{{ subdir }}
    - mode: 700
    - makedirs: True
{% endfor %}

{% for script in ['mysqlbackup.sh','mysqldump.sh','xtrabackup.sh','sendEmail','mysqlrestore.sh','dumpsync.sh','mysqlquery.sh'] %}
cp-{{ script }}:
  file.managed:
    - name: /data/soft/dbadmin/script/{{ script }}
    - source: salt://bin/mysql/backup/{{ script }}
    - mode: 755
    - backup: minion
    - require:
      - file: mkdir-script
{% endfor %}

cp-secret.sh:
  file.managed:
    - name: /data/soft/dbadmin/script/secret.sh
    - source: salt://bin/mysql/backup/secret.sh
    - template: jinja
    - mode: 755
    - defaults:
        backup_password: {{ backuppass }}
    - require:
      - file: mkdir-script

{% for script in ['xtrabackup','xtrabackup_55','xtrabackup_56','innobackupex'] %}
cp-{{ script }}:
  file.managed:
    - name: /data/soft/mysql/bin/{{ script }}
    - source: salt://bin/mysql/backup/{{ script }}
    - mode: 755
    - backup: minion
    - onlyif: test -e /data/soft/mysql/bin
{% endfor %}

init-bakcnf:
  file.managed:
    - name: /data/soft/dbadmin/conf/bakcnf
    - source: salt://conf/mysql/bakcnf
    - require:
      - file: mkdir-conf

{% for port in grains['id'].split('-')[3].split('_') %}
vim-bakcnf{{ port }}:
  file.append:
    - name: /data/soft/dbadmin/conf/bakcnf
    {% if 'master' in grains['id'] %}
    {% set role = "N" %}
    {% else %}
    {% set role = "Y" %}
    {% endif %}
    - text: |
        mysqldump     All  {{ role }}      /data/mysql{{ port }}/mysql.sock  {{ port }}  /data/mysql{{ port }}/my{{ port }}.cnf  pass4db  8  {{ grains['id'].split('-')[2] }}
        xtrabackup    Null {{ role }}      /data/mysql{{ port }}/mysql.sock  {{ port }}  /data/mysql{{ port }}/my{{ port }}.cnf  pass4db  8  {{ grains['id'].split('-')[2] }}
    - require:
      - file: mkdir-conf
      - file: init-bakcnf
{% endfor %}

crontab-mysql:
  file.append:
    - name: /var/spool/cron/root
    - text: |
        {% if 'slave' in grains['id'] %}
        # mysql backup
        0 1 * * * /data/soft/dbadmin/script/mysqlbackup.sh
        {% endif %}

{% if 'master' in grains['id'] %}
comment-rsync:
  cmd.run:
    - name: sed -i 's/rsync/#rsync/' /data/soft/dbadmin/script/mysqldump.sh; sed -i 's/rsync/#rsync/' /data/soft/dbadmin/script/xtrabackup.sh
    - require:
      - file: cp-mysqldump.sh 
      - file: cp-xtrabackup.sh
{% endif %}

alias-dba:
  file.append:
    - name: /root/.bash_profile
    - text: |

        alias dba='cd /data/soft/dbadmin'
{% endif %}
