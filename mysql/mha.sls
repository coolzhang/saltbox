{% set node = "mha4mysql-node-0.56-0.el6.noarch.rpm" %}
{% set keyfiles = ['authorized_keys','id_rsa'] %}
{% set appname = "your application name, e.g: the first field of mid" %}
{% set basedir = "mysql software path" %}

{% for keyfile in keyfiles  %}
cp-{{ keyfile }}:
  file.managed:
    - name: /root/.ssh/{{ keyfile }}
    #- source: salt://conf/mha/sshkeys/{{ grains['id'].split('-')[0]|replace("0","")|replace("1","")|replace("2","")|replace("3","")|replace("4","")|replace("5","")|replace("6","")|replace("7","")|replace("8","")|replace("9","") }}/{{ keyfile }}
    - source: salt://conf/mha/sshkeys/{{ appname }}/{{ keyfile }}
{% endfor %}

chmod-prikey:
  cmd.run:
    - name: chmod 600 /root/.ssh/id_rsa
    - require:
      - file: cp-id_rsa

chmod-pubkey:
  cmd.run:
    - name: chmod 640 /root/.ssh/authorized_keys
    - require:
      - file: cp-authorized_keys

install-perlpkgs:
  pkg.installed:
    - pkgs:
      - perl-DBD-MySQL

cp-node:
  file.managed:
    - name: /tmp/{{ node}}
    - source: salt://pkg/{{ node }}
    - unless: rpm -qa |grep mha4mysql-node

install-node:
  cmd.run:
    - name: rpm -ivh /tmp/{{ node }}
    - onlyif: test -e /tmp/{{ node }}
    - require:
      - file: cp-node
      - pkg: install-perlpkgs

ln-mysqlcommand:
  cmd.run:
    - name: \cp -a {{ basedir }}/bin/mysql /usr/local/bin/; \cp -a {{ basedir }}/bin/mysqlbinlog /usr/local/bin/

cleanup:
  cmd.run:
    - name: rm -f /tmp/{{ node }}
    - onlyif: test -e /tmp/{{ node }}
    - order: last
