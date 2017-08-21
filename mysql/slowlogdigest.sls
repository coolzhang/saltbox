{% for file in [ 'anemometer_collect.sh' ] %}
cp-{{ file }}:
  file.managed:
    - name: /data/soft/dbadmin/script/{{ file }}
    - source: salt://bin/mysql/profile/{{ file }}
    - mode: 755
{% endfor %}

cp-tool:
  file.managed:
    - name: /usr/local/bin/pt-query-digest
    - source: salt://bin/mysql/profile/pt-query-digest
    - mode: 755

set-crontab:
  file.append:
    - name: /var/spool/cron/root
    - text: |

        # mysql slowlog collection
        0 7 * * * /data/soft/dbadmin/script/anemometer_collect.sh
