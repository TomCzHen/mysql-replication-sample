#!/bin/bash

# check mysql master run status

set -e

until MYSQL_PWD=${MASTER_MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master ; do
  >&2 echo "MySQL master is unavailable - sleeping"
  sleep 3
done

# get master log File & Position

master_status_info=$(MYSQL_PWD=${MASTER_MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master -e "show master status\G")

LOG_FILE=$(echo "${master_status_info}" | awk 'NR!=1 && $1=="File:" {print $2}')
LOG_POS=$(echo "${master_status_info}" | awk 'NR!=1 && $1=="Position:" {print $2}')

# set node master

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CHANGE MASTER TO MASTER_HOST='mysql-master', \
MASTER_USER='${MYSQL_REPLICATION_USER}', \
MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD}', \
MASTER_LOG_FILE='${LOG_FILE}', \
MASTER_LOG_POS=${LOG_POS};"

# start slave and show slave status
MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e "START SLAVE;show slave status\G"
