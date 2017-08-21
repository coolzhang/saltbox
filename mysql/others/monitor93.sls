#{% set zabbix_server = "10.104.19.43" %}
{% set zabbix_server = "10.104.48.166" %}
{% set zabbix_repo = "zabbix-release-2.2-1.el6.noarch.rpm" %}

zabbix-yum-repo:
  file.managed:
    - name: /tmp/{{ zabbix_repo }}
    - source: salt://pkg/{{ zabbix_repo }}
    - onlyif: ping -c 4 baidu.com > /dev/null
    - order: 1

install-zabbix-repo:
  cmd.run:
    - name: rpm -ivh /tmp/{{ zabbix_repo }}
    - onlyif: test -e /tmp/{{ zabbix_repo }}
    - unless: rpm -qa |grep zabbix-release
    - require:
      - file: zabbix-yum-repo

install-zabbix-agent:
  pkg.installed:
    - pkgs:
      {% if salt['pkg.version']('zabbix-release') %}
        - zabbix-agent
        - zabbix-sender
      {% else %}
        - zabbix22-agent
      {% endif %}
    - require:
      - cmd: install-zabbix-repo

install-mpm-perlpkgs:
  pkg.installed:
    - pkgs:
      - perl-File-Which
      - perl-libwww-perl
      - perl-Digest-SHA
      - perl-DBD-MySQL
      - perl-Time-HiRes
      - perl-Crypt-SSLeay

rm-zabbix_agentd.conf:
  cmd.run:
    - name: rm -f /etc/zabbix_agent*.conf; rm -f /etc/zabbix/zabbix_agent*.conf
    - require:
      - pkg: install-zabbix-agent

zabbix_agentd.conf:
  file.managed:
    - name: /etc/zabbix/zabbix_agentd.conf
    - source: salt://conf/zabbix/zabbix_agentd.conf
    - mode: 644
    - template: jinja
    - defaults:
        Server: {{ zabbix_server }}
        ServerActive: {{ zabbix_server }}
        Hostname: {{ grains['id'] }}
    - require:
      - pkg: install-zabbix-agent

ln-zabbix_agentd.conf:
  cmd.run:
    - name: ln -s /etc/zabbix/zabbix_agentd.conf /etc/zabbix_agentd.conf
    - require:
      - cmd: rm-zabbix_agentd.conf
      - file: zabbix_agentd.conf

mpm-agent-pkg:
  file.managed:
    - name: /etc/zabbix/mpm.tar.gz
    - source: salt://pkg/mpm.tar.gz
    - onlyif: test ! -e /etc/zabbix/mpm
    - require:
      - pkg: install-zabbix-agent

uncompress-mpm-agent-pkg:
  cmd.run:
    - name: tar -xzf mpm.tar.gz
    - cwd: /etc/zabbix
    - onlyif: test -e /etc/zabbix/mpm.tar.gz
    - require:
      - file: mpm-agent-pkg

chown-mpm:
  file.directory:
    - name: /etc/zabbix/mpm
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
    - name: /etc/zabbix/mpm/etc/mpm.conf
    - source: salt://conf/zabbix/mpm.conf
    - user: zabbix
    - group: zabbix
    - mode: 644
    - template: jinja
    - defaults:
        ZabbixServer: {{ zabbix_server }}
    - require:
      - file: chown-mpm

{% for port in grains['id'].split('-')[3].split('_') %}
mpm.conf{{ port }}:
  file.append:
    - name: /etc/zabbix/mpm/etc/mpm.conf
    - context:
      {% if 'slave' in grains['id'] %}
        {% set Role = 'slave' %}
      {% else %}
        {% set Role = 'master' %}
      {% endif %}
    - text: |

        [{{ grains['id'].rsplit('-',1)[0] }}-{{ port }}]          # This MUST match Hostname in Zabbix!
        MysqlPort    = {{ port }}
        Type         = mysqld
        Modules      = mysql innodb {{ Role }}
    - require:
      - file: mpm.conf
{% endfor %}
    
mkdir-zabbix_agentd.d:
  file.directory:
    - name: /etc/zabbix/zabbix_agentd.d
    - user: zabbix
    - group: zabbix
    - makedirs: True
    - dir_mode: 755
    - onlyif: test ! -e /etc/zabbix/zabbix_agentd.d
    - require:
      - pkg: install-zabbix-agent

sync-userparameter:
  file.managed:
    - name: /etc/zabbix/zabbix_agentd.d/userparameter_mysql.conf
    - source: salt://conf/zabbix/userparameter_mysql.conf
    - user: zabbix
    - group: zabbix
    - mode: 644
    - require:
      - file: mkdir-zabbix_agentd.d
      - pkg: install-zabbix-agent
   
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
    - name: rm -f /etc/zabbix/mpm.tar.gz;rm -f /tmp/zabbix-release-2.2-1.el6.noarch.rpm
    - onlyif: test -e /etc/zabbix/mpm.tar.gz || test -e /tmp/zabbix-release-2.2-1.el6.noarch.rpm
    - order: last
