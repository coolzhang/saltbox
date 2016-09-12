{% set master_mid = "" %}
{% set master_vip = "" %}

{% if master_mid and master_vip %}
{% set app_name = master_mid.split('-')[0]|capitalize %}
{% set i = 0 %}
{% set j = master_mid.split('-')[2].split('.')[3]|int %}
{% for redis_port in master_mid.split('-')[3].split('_') %}
{% set sentinel_port = redis_port|int + 1000 + j %}
mkdir-datadir{{ redis_port }}:
  file.directory:
    - name: /data/sentinel{{ app_name }}
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: True

sentinel-conf{{ redis_port }}:
  file.managed:
    - name: /data/sentinel{{ app_name }}/sentinel{{ redis_port }}.conf
    - source: salt://conf/redis/sentinel.conf
    - template: jinja
    - defaults:
        sentinel_port: {{ sentinel_port }}
        redis_port: {{ redis_port }}
        app_name: {{ app_name }}
        master_ip: {{ master_mid.split('-')[2] }}
        downtime: 300000
        client_reconfig_script: redis-reconfig-sms-{{ redis_port }}.sh
    - require:
      - file: mkdir-datadir{{ redis_port }}

sentinel-script{{ redis_port }}:
  file.managed:
    - name: /data/sentinel{{ app_name }}/redis-reconfig-sms-{{ redis_port }}.sh
    - source: salt://bin/redis/redis-reconfig-sms.sh
    - mode: 755
    - template: jinja
    - defaults:
        vip: {{ master_vip.split('-')[i] }}
        sentinel_ip: {{ grains['id'] }}
    - require:
      - file: mkdir-datadir{{ redis_port }}

startup-sentinel{{ redis_port }}:
  cmd.run:
    - name: /data/soft/redis/redis-sentinel /data/sentinel{{ app_name }}/sentinel{{ redis_port }}.conf
    - unless: ps -ef |grep -v grep |grep -w {{ sentinel_port }} > /dev/null
    - require:
      - file: sentinel-conf{{ redis_port }}
      - file: sentinel-script{{ redis_port }}

boot-startup{{ redis_port }}:
  file.append:
    - name: /etc/rc.local
    - text: |
        /data/soft/redis/redis-sentinel /data/sentinel{{ app_name }}/sentinel{{ redis_port }}.conf
    - require:
      - cmd: startup-sentinel{{ redis_port }}
{% set i = i + 1 %}
{% endfor %}
{% endif %}
