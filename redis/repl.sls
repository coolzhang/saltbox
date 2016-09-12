{% set master_mid = "" %}

{% if master_mid %}
{% for port in grains['id'].split('-')[3].split('_') %}
slaveof{{ port }}:
  cmd.run:
    - name: /data/soft/redis/redis-cli -p {{ port }} slaveof {{ master_mid.split('-')[2] }} {{ port }}
{% endfor %}
{% endif %}
