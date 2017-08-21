# redis_version: 28, 3x
# cluster_enabled: true, false
{% set redis_version = "" %}
{% set redis_memory = "" %}
{% set cluster_enabled = true %}

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
  cmd.run:
    - name: sysctl vm.overcommit_memory=1; echo never > /sys/kernel/mm/transparent_hugepage/enabled; echo 1024 > /proc/sys/net/core/somaxconn

{% for port in grains['id'].split('-')[3].split('_') %}
{% if redis_memory %}
mkdir-datadir{{ port }}:
  file.directory:
  {% if '3x' in redis_version and cluster_enabled %}
    - name: /data/rediscluster/{{ port }}
  {% else %}
    - name: /data/redis{{ port }}
  {% endif %}
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: True

redis-conf{{ port }}:
  file.managed:
  {% if '3x' in redis_version and cluster_enabled %}
    - name: /data/rediscluster/{{ port }}/redis.conf
  {% else %}
    - name: /data/redis{{ port }}/redis.conf
  {% endif %}
    - source: salt://conf/redis/redis.conf
    - template: jinja
    - context:
        port: {{ port }}
        maxmemory: {{ redis_memory }}
      {% if '3x' in redis_version and cluster_enabled %}
        dir: dir /data/rediscluster/{{ port }}
        cluster_enabled: cluster-enabled yes
        cluster_config_file: cluster-config-file node.conf
        cluster_node_timeout: cluster-node-timeout 30000
        cluster_require_full_coverage: cluster-require-full-coverage no
      {% else %}
        dir: dir /data/redis{{ port }}
      {% endif %}
      {% if '3x' in redis_version %}
        protected_mode: protected-mode no
      {% endif %}
    - defaults:
        client_output_buffer_limit: ''
        protected_mode: ''
        cluster_enabled: ''
        cluster_config_file: ''
        cluster_node_timeout: ''
        cluster_require_full_coverage: ''
    - require:
      - file: mkdir-datadir{{ port }}

startup-redis{{ port }}:
  cmd.run:
  {% if '3x' in redis_version and cluster_enabled %}
    - name: /data/soft/redis/redis-server /data/rediscluster/{{ port }}/redis.conf
  {% else %}
    - name: /data/soft/redis/redis-server /data/redis{{ port }}/redis.conf
  {% endif %}
    - unless: ps -ef |grep -v grep |grep {{ port }} > /dev/null
    - require:
      - file: mkdir-datadir{{ port }}
      - file: redis-conf{{ port }}
  file.append:
    - name: /etc/rc.local
    - text: |
      {% if '3x' in redis_version and cluster_enabled %}
        /data/soft/redis/redis-server /data/rediscluster/{{ port }}/redis.conf
      {% else %}
        /data/soft/redis/redis-server /data/redis{{ port }}/redis.conf
      {% endif %}
    - unless: ps -ef |grep -v grep |grep {{ port }} > /dev/null
{% endif %}    
{% endfor %}

{% if '3x' in redis_version and cluster_enabled %}
install-rubygem:
  file.managed:
    - name: /tmp/redis-3.2.2.gem
    - source: salt://pkg/redis-3.2.2.gem
  cmd.run:
    - name: yum install -y ruby rubygems; gem install -l /tmp/redis-3.2.2.gem
    - require:
      - file: install-rubygem
{% endif %}

cleanup:
  cmd.run:
    - name: rm -f /tmp/{{ redis_version }}.tar.gz; rm -f /tmp/redis-3.2.2.gem
    - onlyif: test -e /tmp/{{ redis_version }}.tar.gz or test -e /tmp/redis-3.2.2.gem
    - order: last
