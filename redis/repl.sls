{% set app_vip_mip_port = "" %}

{% if app_vip_mip_port %}
{% for v in app_vip_mip_port.split(' ')%}
{% set master_ip = v.split('-')[2] %}
{% set port =  v.split('-')[3] %}
slaveof{{ port }}:
  cmd.run:
    - name: /data/soft/redis/redis-cli -p {{ port }} slaveof {{ master_ip }} {{ port }}
    - unless: /data/soft/redis/redis-cli -p {{ port }} info replication | grep "role:slave" > /dev/null
{% endfor %}
{% endif %}
