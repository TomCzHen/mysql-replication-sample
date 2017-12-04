#!/bin/bash

# check mysql master run status

set -e

until MYSQL_PWD=${MASTER_MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master ; do
  >&2 echo "MySQL master is unavailable - sleeping"
  sleep 3
done

# get master log file pos

master_status_info=$(MYSQL_PWD=${MASTER_MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master -e "show master status\G")
echo ${master_status_info}

#LOG_FILE=$()
#LOG_POS=$()

# set node master

sql="CHANGE MASTER TO MASTER_HOST='mysql-master', \
MASTER_USER='${MYSQL_REPLICATION_USER}', \
MASTER_PASSWORD=${MASTER_MYSQL_ROOT_PASSWORD}, \
MASTER_LOG_FILE='${LOG_FILE}', \
MASTER_LOG_POS=${LOG_POS};"

# mysql -u root -p${MYSQL_ROOT_PASSWORD} \
# -e ${sql}

# start slave and show slave status
# mysql -u root -p${MYSQL_ROOT_PASSWORD} \
# -e "START SLAVE;"
