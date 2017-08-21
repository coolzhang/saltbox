zabbix-yum-repo:
  file.managed:
    - name: /tmp/zabbix-release-2.2-1.el6.noarch.rpm
    - source: salt://pkg/zabbix-release-2.2-1.el6.noarch.rpm
    - unless: rpm -qa |grep zabbix-release
    - order: 1

install-zabbix-repo:
  cmd.run:
    - name: rpm -ivh /tmp/zabbix-release-2.2-1.el6.noarch.rpm
    - onlyif: test -e /tmp/zabbix-release-2.2-1.el6.noarch.rpm
    - require:
      - file: zabbix-yum-repo

install-zabbix-agent:
  pkg.installed:
    - pkgs:
      - zabbix-agent
      - zabbix-sender
      - coreutils
      - php
      - php-mysqli
      - php-cli
      - php-process
      - perl-File-Which
      - perl-libwww-perl
      - perl-Digest-SHA1
      - perl-DBD-MySQL
      - perl-Time-HiRes
      - perl-Crypt-SSLeay
    - require:
      - file: install-zabbix-repo

zabbix_agentd.conf:
  file.managed:
    - name: /etc/zabbix/zabbix_agentd.conf
    - source: salt://conf/zabbix/zabbix_agentd.conf
    - mode: 644
    - require:
      - pkg: install-zabbix-agent

sed-zabbix_agentd.conf:
  file.sed:
    - name: /etc/zabbix/zabbix_agentd.conf
    - before: \{Hostname\}
    - after: {{ grains['id'] }}
    - require:
      - file: zabbix_agentd.conf

mpm-agent-pkg:
  file.managed:
    - name: /etc/zabbix/fpmmm.tar.gz
    - source: salt://pkg/fpmmm.tar.gz
    - onlyif: test ! -e /etc/zabbix/fpmmm
    - require:
      - pkg: install-zabbix-agent

uncompress-mpm-agent-pkg:
  cmd.run:
    - name: tar -xzf fpmmm.tar.gz
    - cwd: /etc/zabbix
    - unless: test -d /etc/zabbix/fpmmm
    - require:
      - file: mpm-agent-pkg

chown-mpm:
  file.directory:
    - name: /etc/zabbix/fpmmm
    - user: zabbix
    - group: zabbix
    - dir_mode: 755
    - recurse:
      - user
      - group
      - mode
    - require:
      - cmd: uncompress-mpm-agent-pkg

mpm.conf:
  file.managed:
    - name: /etc/zabbix/fpmmm.conf
    - source: salt://conf/zabbix/fpmmm.conf
    - mode: 644
    - require:
      - pkg: install-zabbix-agent

fpmmm.ini:
  file.managed:
    - name: /etc/php.d/fpmmm.ini
    - source: salt://conf/zabbix/fpmmm.ini
    - mode: 644
    - require:
      - pkg: install-zabbix-agent

sed-mpm.conf:
  cmd.run:
    {% if 'master' in grains['id'] %}
    - name: sed -i -e "s/{Hostname}/{{ grains['id'] }}/" -e "s/{Role}/master/" -e "s/{Port}/{{ grains['id'].split('-')[3] }}/" /etc/zabbix/fpmmm.conf
    {% elif 'slave' in grains['id'] %}
    - name: sed -i -e "s/{Hostname}/{{ grains['id'] }}/" -e "s/{Role}/slave/" -e "s/{Port}/{{ grains['id'].split('-')[3] }}/" /etc/zabbix/fpmmm.conf
    {% endif %}
    - unless: grep {Hostname} /etc/zabbix/fpmmm.conf || grep {Role} /etc/zabbix/fpmmm.conf || grep {Port} /etc/zabbix/fpmmm.conf
    - require:
      - file: mpm.conf
   
chown-cache:
  file.directory:
    - name: /var/log/zabbix/cache
    - user: zabbix
    - group: zabbix
    - makedirs: True
    - dir_mode: 755

usermod-zabbix:
  user.present:
    - name: zabbix
    - groups:
      - mysql
    - require:
      - pkg: install-zabbix-agent

cleanup:
  cmd.run:
    - name: rm -f /etc/zabbix/fpmmm.tar.gz
    - onlyif: test -e /etc/zabbix/fpmmm.tar.gz
    - order: last
