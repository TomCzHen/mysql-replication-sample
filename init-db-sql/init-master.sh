#!/bin/bash

set -e

# create replication user

mysql_net=$(ip route | awk '$1=="default" {print $3}' | sed "s/\.[0-9]\+$/.%/g")

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CREATE USER '${MYSQL_REPLICATION_USER}'@'${mysql_net}' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'${mysql_net}';"