mysql-query:
  file.managed:
    - name: /data/tmp/query.sql
    - source: salt://mysql/sql/query.sql
