{% set dbadir = "path for dba scripts" %}

{% for file in [ 'anemometer_collect.sh' ] %}
cp-{{ file }}:
  file.managed:
    - name: {{ dbadir }}/script/{{ file }}
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
        0 7 * * * {{ dbadir }}/script/anemometer_collect.sh
