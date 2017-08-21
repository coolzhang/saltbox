{% for script in ['anemometer_collect.sh'] %}
cp-{{ script }}:
  file.managed:
    - name: /data/soft/dbadmin/script/{{ script }}
    #- name: /usr/bin/{{ script }}
    - source: salt://bin/mysql/profile/{{ script }}
    - mode: 755

#{% if 'master' in grains['id'] and script in ['mysqldump.sh','xtrabackup.sh'] %}
#comment-rsync{{ script }}:
#  cmd.run:
#    - name: sed -i 's/rsync/#rsync/' /data/soft/dbadmin/script/{{ script }}
#    - require:
#      - file: cp-{{ script }}
#{% endif %}
#{% endfor %}
