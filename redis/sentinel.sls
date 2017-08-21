{% set app_vip_mip_port = "" %}

{% if app_vip_mip_port %}
{% for v in app_vip_mip_port.split(' ') %}
{% set app_name = v.split('-')[0]|capitalize %}
{% set master_vip = v.split('-')[1] %}
{% set master_ip = v.split('-')[2] %}
{% set sentinel_port = v.split('-')[3] %}
mkdir-datadir{{ sentinel_port }}:
  file.directory:
    - name: /data/sentinel{{ app_name }}
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: True

mkdir-sentineldir{{ sentinel_port }}:
  file.directory:
    - name: /data/sentinel{{ app_name }}/{{ sentinel_port }}
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: True
    - require:
      - file: mkdir-datadir{{ sentinel_port }}

sentinel-conf{{ sentinel_port }}:
  file.managed:
    - name: /data/sentinel{{ app_name }}/{{ sentinel_port }}/sentinel.conf
    - source: salt://conf/redis/sentinel.conf
    - template: jinja
    - defaults:
        redis_port: {{ sentinel_port }}
        sentinel_port: {{ sentinel_port }}
        app_name: {{ app_name }}
        master_ip: {{ master_ip }}
        downtime: 60000
        client_reconfig_script: redis-reconfig-sms.sh
    - require:
      - file: mkdir-sentineldir{{ sentinel_port }}

sentinel-script{{ sentinel_port }}:
  file.managed:
    - name: /data/sentinel{{ app_name }}/{{ sentinel_port }}/redis-reconfig-sms.sh
    - source: salt://bin/redis/redis-reconfig-sms.sh
    - mode: 755
    - template: jinja
    - defaults:
        vip: {{ master_vip }}
        sentinel_ip: {{ grains['id'] }}
    - require:
      - file: mkdir-sentineldir{{ sentinel_port }}

startup-sentinel{{ sentinel_port }}:
  cmd.run:
    - name: /data/soft/redis/redis-sentinel /data/sentinel{{ app_name }}/{{ sentinel_port }}/sentinel.conf
    - unless: ps -ef |grep -v grep |grep -w {{ sentinel_port }} > /dev/null
    - require:
      - file: sentinel-conf{{ sentinel_port }}
      - file: sentinel-script{{ sentinel_port }}

boot-startup{{ sentinel_port }}:
  file.append:
    - name: /etc/rc.local
    - text: |
        /data/soft/redis/redis-sentinel /data/sentinel{{ app_name }}/{{ sentinel_port }}/sentinel.conf
    - require:
      - cmd: startup-sentinel{{ sentinel_port }}
{% endfor %}
{% endif %}
