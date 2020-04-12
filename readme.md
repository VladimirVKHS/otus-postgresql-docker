# DB Patroni homework

- Тестовый кластер PostgreSQL Patroni из трёх нод (Consul, HAProxy).
- Источник: https://github.com/xenit-eu/docker-patroni

## Запуск кластера

- Запуск

      docker-compose up
    
- Проверка статуса кластера

      docker-compose exec -T postgresqlalpha patronictl list otus

      +---------+-------------------+-------------------+--------+---------+----+-----------+
      | Cluster |       Member      |        Host       |  Role  |  State  | TL | Lag in MB |
      +---------+-------------------+-------------------+--------+---------+----+-----------+
      |   otus  |  postgresqlalpha  |  postgresqlalpha  | Leader | running |  5 |           |
      |   otus  |  postgresqlbravo  |  postgresqlbravo  |        | running |  5 |         0 |
      |   otus  | postgresqlcharlie | postgresqlcharlie |        | running |  5 |         0 |
      +---------+-------------------+-------------------+--------+---------+----+-----------+

- Загрузка тестовой базы

      docker-compose exec -T postgresqlalpha bash /sql/otus.sh    


- Проверка клиентского подключения через HAProxy (pgweb)

      http://127.0.0.1:8080

## Проверка failover
      
  -  Отключение 1-ой ноды
         
         docker-compose pause postgresqlalpha
  
  -  Проверка статуса кластера
  
         docker-compose exec -T postgresqlbravo patronictl list otus 
         
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         | Cluster |       Member      |        Host       |  Role  |  State  | TL | Lag in MB |
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         |   otus  |  postgresqlbravo  |  postgresqlbravo  | Leader | running |  3 |           |
         |   otus  | postgresqlcharlie | postgresqlcharlie |        | running |  3 |         0 |
         +---------+-------------------+-------------------+--------+---------+----+-----------+
  
  - Восстановление 1-й ноды
  
        docker-compose unpause postgresqlalpha          
  
  -  Проверка статуса кластера
  
         docker-compose exec -T postgresqlalpha patronictl list otus

         +---------+-------------------+-------------------+--------+---------+----+-----------+
         | Cluster |       Member      |        Host       |  Role  |  State  | TL | Lag in MB |
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         |   otus  |  postgresqlalpha  |  postgresqlalpha  |        | running |  3 |         0 |
         |   otus  |  postgresqlbravo  |  postgresqlbravo  | Leader | running |  3 |           |
         |   otus  | postgresqlcharlie | postgresqlcharlie |        | running |  3 |         0 |
         +---------+-------------------+-------------------+--------+---------+----+-----------+

## Проверка switchover

  -  Выполнение команды (из консоли ноды):
  
         root@31f9511f10ac:/# patronictl switchover otus
         Master [postgresqlbravo]:
         Candidate ['postgresqlalpha', 'postgresqlcharlie'] []: postgresqlalpha
         When should the switchover take place (e.g. 2020-04-12T14:55 )  [now]: now
         Current cluster topology
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         | Cluster |       Member      |        Host       |  Role  |  State  | TL | Lag in MB |
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         |   otus  |  postgresqlalpha  |  postgresqlalpha  |        | running |  3 |         0 |
         |   otus  |  postgresqlbravo  |  postgresqlbravo  | Leader | running |  3 |           |
         |   otus  | postgresqlcharlie | postgresqlcharlie |        | running |  3 |         0 |
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         Are you sure you want to switchover cluster otus, demoting current master postgresqlbravo? [y/N]: y
         2020-04-12 13:56:02.85084 Successfully switched over to "postgresqlalpha"
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         | Cluster |       Member      |        Host       |  Role  |  State  | TL | Lag in MB |
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         |   otus  |  postgresqlalpha  |  postgresqlalpha  | Leader | running |  3 |           |
         |   otus  |  postgresqlbravo  |  postgresqlbravo  |        | stopped |    |   unknown |
         |   otus  | postgresqlcharlie | postgresqlcharlie |        | running |  3 |         0 |
         +---------+-------------------+-------------------+--------+---------+----+-----------+
  
  -  Проверка статуса
  
         docker-compose exec -T postgresqlalpha patronictl list otus
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         | Cluster |       Member      |        Host       |  Role  |  State  | TL | Lag in MB |
         +---------+-------------------+-------------------+--------+---------+----+-----------+
         |   otus  |  postgresqlalpha  |  postgresqlalpha  | Leader | running |  4 |           |
         |   otus  |  postgresqlbravo  |  postgresqlbravo  |        | running |  4 |         0 |
         |   otus  | postgresqlcharlie | postgresqlcharlie |        | running |  4 |         0 |
         +---------+-------------------+-------------------+--------+---------+----+-----------+

## Изменение параметров требующих перезагрузки

  -   Изменение параметра (например max_connections)

          patronictl edit-config otus
          --- 
          +++ 
          @@ -8,7 +8,7 @@
               lc_monetary: en_US.utf8
               lc_numeric: en_US.utf8
               lc_time: en_US.utf8
          -    max_connections: 375
          +    max_connections: 100
               max_replication_slots: 1
               max_wal_senders: 2
               max_wal_size: 2GB
          
          Apply these changes? [y/N]: y
          Configuration changed
          
          patronictl list otus
          +---------+-------------------+-------------------+--------------+---------+----+-----------+-----------------+
          | Cluster |       Member      |        Host       |     Role     |  State  | TL | Lag in MB | Pending restart |
          +---------+-------------------+-------------------+--------------+---------+----+-----------+-----------------+
          |   otus  |  postgresqlalpha  |  postgresqlalpha  |    Leader    | running |  4 |           |        *        |
          |   otus  |  postgresqlbravo  |  postgresqlbravo  | Sync Standby | running |  4 |         0 |        *        |
          |   otus  | postgresqlcharlie | postgresqlcharlie |              | running |  4 |         0 |        *        |
          +---------+-------------------+-------------------+--------------+---------+----+-----------+-----------------+

