{% set zabbix_server = "10.1.1.166" %}
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

mkdir-ret:
  file.directory:
    - name: /etc/zabbix/ret
    - user: zabbix
    - group: zabbix
    - dir_mode: 755
    - require:
      - pkg: install-zabbix-agent

mkdir-script:
  file.directory:
    - name: /etc/zabbix/script
    - user: zabbix
    - group: zabbix
    - dir_mode: 755
    - require:
      - pkg: install-zabbix-agent

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

userparams_connect-trapper.conf:
  file.managed:
    - name: /etc/zabbix/zabbix_agentd.d/userparams_connect-trapper.conf
    - source: salt://conf/zabbix/userparams_connect-trapper.conf
    - user: zabbix
    - group: zabbix
    - mode: 644
    - require:
      - file: mkdir-zabbix_agentd.d

tcp_trapper_connect.sh:
  file.managed:
    - name: /etc/zabbix/script/tcp_trapper_connect.sh
    - source: salt://bin/mongodb/tcp_trapper_connect.sh
    - user: zabbix
    - group: zabbix
    - mode: 644
    - require:
      - file: mkdir-script
  cmd.run:
    - name: sed -i -e 's/zabbix_agent_hostname/{{ grains['id'] }}/' -e 's/zabbix_server_ip/{{ zabbix_server }}/' /etc/zabbix/script/tcp_trapper_connect.sh
    - require:
      - file: tcp_trapper_connect.sh

chown-cache:
  file.directory:
    - name: /var/log/zabbix/cache
    - user: zabbix
    - group: zabbix
    - makedirs: True
    - dir_mode: 755
    - require:
      - pkg: install-zabbix-agent

sed-sudoers:
  cmd.run:
    - name: sed -i '/^Defaults    requiretty/ s/^/#/' /etc/sudoers
  file.append:
    - name: /etc/sudoers
    - text:
      - "%wheel ALL=(ALL)   NOPASSWD: ALL"

usermod-zabbix:
  user.present:
    - name: zabbix
    - groups:
      - wheel
    - require:
      - pkg: install-zabbix-agent

cleanup:
  cmd.run:
    - name: rm -f /tmp/{{ zabbix_repo }}
    - onlyif: test -e /tmp/{{ zabbix_repo }}
    - require:
      - cmd: install-zabbix-repo

startup:
  service.running:
    - name: zabbix-agentd
    - enable: True
    - watch:
      - file: zabbix_agentd.conf
    - order: last
