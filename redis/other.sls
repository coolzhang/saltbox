{% set script = 'tcp_trapper_connect.sh' %}

{{ script }}:
  file.managed:
    - name: /etc/zabbix/script/{{ script }}
    - source: salt://bin/redis/{{ script }}
    - user: zabbix
    - group: zabbix
    - mode: 644
  cmd.run:
    - name: sed -i -e 's/zabbix_agent_hostname/{{ grains['id'].rsplit('-',1)[0] }}/' -e 's/zabbix_server_ip/10.1.1.166/' /etc/zabbix/script/tcp_trapper_connect.sh
    - require:
      - file: tcp_trapper_connect.sh
