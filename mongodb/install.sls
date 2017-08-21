{% set mongodb_version = "amazon-3.0.14" %}

useradd-mongo:
  user.present:
    - name: mongo
    - order: 1
  cmd.run:
    - name: sed -i '/^PATH=/ s#$#:/data/soft/mongodb/bin#' /home/mongo/.bash_profile
    - unless: grep '/data/soft/mongodb/bin' /home/mongo/.bash_profile

mongodb-binary-pkg:
  file.managed:
    - name: /tmp/mongodb-linux-x86_64-{{ mongodb_version }}.tgz
    - source: salt://pkg/mongodb-linux-x86_64-{{ mongodb_version }}.tgz
    - onlyif: test ! -e /data/soft/mongodb

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
      - file: mongodb-binary-pkg

mkdir-mongodb:
  cmd.run:
    - name: tar -xzf mongodb-linux-x86_64-{{ mongodb_version }}.tgz -C /data/soft && mv /data/soft/mongodb-linux-x86_64-{{ mongodb_version }} /data/soft/mongodb
    - cwd: /tmp
    - onlyif: test ! -e /data/soft/mongodb
    - require:
      - file: mongodb-binary-pkg
      - file: mkdir-soft

chmod-mongodb:
  file.directory:
    - name: /data/soft/mongodb
    - user: root
    - group: root
    - dir_mode: 755
    - recurse:
      - user
      - group
      - mode
    - require:
      - cmd: mkdir-mongodb

init-env:
  file.append:
    - name: /etc/rc.local
    - text: |

        # mongodb
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
        echo never > /sys/kernel/mm/transparent_hugepage/defrag
  cmd.run:
    - name: echo never > /sys/kernel/mm/transparent_hugepage/enabled;echo never > /sys/kernel/mm/transparent_hugepage/defrag

{% for port in grains['id'].split('-')[3].split('_') %}
mkdir-dbpath{{ port }}:
  file.directory:
    - name: /data/mongo{{ port }}
    - user: mongo
    - group: mongo
    - dir_mode: 755
    - makedirs: True

mkdir-logpath{{ port }}:
  file.directory:
    - name: /data/mongo{{ port }}/log
    - user: mongo
    - group: mongo
    - dir_mode: 755
    - makedirs: True
    - require:
      - file: mkdir-dbpath{{ port }}

replset-keyfile{{ port }}:
  file.managed:
    - name: /data/mongo{{ port }}/key4rs
    - source: salt://mongodb/key4rs
    - user: mongo
    - group: mongo
    - mode: 400
    - require:
      - file: mkdir-dbpath{{ port }}

startup-mongodb{{ port }}:
  cmd.run:
    - name: su - mongo -c '/data/soft/mongodb/bin/mongod --storageEngine wiredTiger --wiredTigerDirectoryForIndexes --dbpath /data/mongo{{ port }} --logpath /data/mongo{{ port }}/log/mongod.log --replSet rs0 --keyFile /data/mongo{{ port }}/key4rs --nojournal --fork'
    - unless: ps -ef |grep -v grep |grep {{ port }} > /dev/null
    - require:
      - cmd: mkdir-mongodb
      - file: mkdir-dbpath{{ port }}
      - file: mkdir-logpath{{ port }}
  file.append:
    - name: /etc/rc.local
    - text: |
        /data/soft/mongodb/bin/mongod --storageEngine wiredTiger --wiredTigerDirectoryForIndexes --dbpath /data/mongo{{ port }} --logpath /data/mongo{{ port }}/log/mongod.log --replSet rs0 --keyFile /data/mongo{{ port }}/key4rs  --nojournal --fork
    - unless: ps -ef |grep -v grep |grep {{ port }} > /dev/null
    - require:
      - file: init-env
{% endfor %}

cleanup:
  cmd.run:
    - name: rm -f /tmp/mongodb-linux-x86_64-{{ mongodb_version }}.tar
    - onlyif: test -e /tmp/mongodb-linux-x86_64-{{ mongodb_version }}.tar
    - order: last
