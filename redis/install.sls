{% set redis_version = "redis28" %}
{% set redis_memory = "" %}

redis-binary-pkg:
  file.managed:
    - name: /tmp/{{ redis_version }}.tar.gz
    - source: salt://pkg/{{ redis_version }}.tar.gz
    - onlyif: test ! -e /data/soft/redis
    - order: 1

mkdir-soft:
  file.directory:
    - name: /data/soft
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: True
    - recurse:
      - user
      - group
      - mode
    - require:
      - file: redis-binary-pkg

mkdir-redis:
  cmd.run:
    - name: tar -xzf {{ redis_version }}.tar.gz -C /data/soft
    - cwd: /tmp
    - onlyif: test ! -e /data/soft/redis
    - require:
      - file: redis-binary-pkg
      - file: mkdir-soft

chmod-redis:
  file.directory:
    - name: /data/soft/redis
    - user: root
    - group: root
    - dir_mode: 755
    - recurse:
      - user
      - group
      - mode
    - require:
      - cmd: mkdir-redis

redis-cli:
  cmd.run:
    - name: \cp -fa /data/soft/redis/redis-cli /usr/bin/
    - unless: ls /usr/bin |grep redis-cli >/dev/null
    - require:
      - file: chmod-redis

init-env:
  file.append:
    - name: /etc/rc.local
    - text: |

        # redis
        sysctl vm.overcommit_memory=1
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
        echo 1024 > /proc/sys/net/core/somaxconn

{% for port in grains['id'].split('-')[3].split('_') %}
{% if redis_memory %}
mkdir-datadir{{ port }}:
  file.directory:
    - name: /data/redis{{ port }}
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: True

redis-conf{{ port }}:
  file.managed:
    - name: /data/redis{{ port }}/redis.conf
    - source: salt://conf/redis/redis.conf
    - template: jinja
    - context:
        port: {{ port }}
        maxmemory: {{ redis_memory }}
      {% if 'mb' not in redis_memory and redis_memory|replace("gb","")|int >= 10 %}
        client_output_buffer_limit: client-output-buffer-limit slave 0 0 0
      {% endif %}
    - defaults:
        client_output_buffer_limit: ''
    - require:
      - file: mkdir-datadir{{ port }}

startup-redis{{ port }}:
  cmd.run:
    - name: sysctl vm.overcommit_memory=1; echo never > /sys/kernel/mm/transparent_hugepage/enabled; echo 1024 > /proc/sys/net/core/somaxconn; /data/soft/redis/redis-server /data/redis{{ port }}/redis.conf
    - unless: ps -ef |grep -v grep |grep {{ port }} > /dev/null
    - require:
      - file: mkdir-datadir{{ port }}
      - file: redis-conf{{ port }}

boot-startup{{ port }}:
  file.append:
    - name: /etc/rc.local
    - text: |
        /data/soft/redis/redis-server /data/redis{{ port }}/redis.conf
    - unless: ps -ef |grep -v grep |grep {{ port }} > /dev/null
{% endif %}    
{% endfor %}


cleanup:
  cmd.run:
    - name: rm -f /tmp/{{ redis_version }}.tar.gz
    - onlyif: test -e /tmp/{{ redis_version }}.tar.gz
    - order: last
