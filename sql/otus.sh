 #!/bin/bash
 PGPASSWORD=postgres psql -h haproxy -p5000 -Upostgres -f "/sql/otus.sql"