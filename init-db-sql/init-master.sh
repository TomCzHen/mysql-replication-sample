#!/bin/bash

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e "select @@version;"

# create replication user

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e "CREATE USER '${MYSQL_REPLICATION_USER}'@'mysql-node-*' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}';"

# grant replication user

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e "GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'mysql-node-*';"