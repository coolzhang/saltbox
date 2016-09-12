{% filepath = "path to scripts" %}

{% for script in ['mysqlkill.sh','mysqlquery.sh'] %}
cp-{{ script }}:
  file.managed:
    - name: {{ filepath }}/{{ script }}
    - source: salt://bin/mysql/backup/{{ script }}
    - mode: 755

{% if 'master' in grains['id'] and script in ['mysqldump.sh','xtrabackup.sh'] %}
comment-rsync{{ script }}:
  cmd.run:
    - name: sed -i 's/rsync/#rsync/' {{ filepath }}/{{ script }}
    - require:
      - file: cp-{{ script }}
{% endif %}
{% endfor %}
