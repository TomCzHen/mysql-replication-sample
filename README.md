# 说明

由于是单机同时运行主从实例，仅用于开发环境或学习主从复制配置。

项目地址 [https://github.com/TomCzHen/mysql-replication-sample](https://github.com/TomCzHen/mysql-replication-sample)

## 文件结构

```
├── docker-compose.yaml
├── env
│   ├── base.env
│   ├── master.env
│   └── node.env
├── .env
├── init-db-sql
│   ├── init-master.sh
│   ├── init-node.sh
│   ├── sakila-data.sql
│   └── sakila-schema.sql
└── README.md
```

### env

根目录下的 `.env` 文件作用域是在 `docker-compose.yaml` 中，而 `env` 路径下的文件作用与容器内部环境变量，两者作用不同。

* `.env`

```shell
TAG=5.7.20

MASTER_SERVER_ID=1
NODE_1_SERVER_ID=10
NODE_2_SERVER_ID=20

MASTER_MYSQL_ROOT_PASSWORD=master_root_pwd
NODE_MYSQL_ROOT_PASSWORD=node_root_pwd
```

### docker-compose.yaml

```yaml
version: "3.3"

services:
  
  mysql-master: &mysql
    image: mysql:${TAG}
    container_name: mysql-master
    restart: unless-stopped
    env_file:
      - env/base.env
      - env/master.env
    environment:
      - MYSQL_ROOT_PASSWORD=${MASTER_MYSQL_ROOT_PASSWORD}
    ports:
      - "3306:3306"
    expose:
      - "3306"
    volumes:
      - mysql-master-data:/var/lib/mysql
      - ./init-db-sql/sakila-schema.sql:/docker-entrypoint-initdb.d/1-schema.sql
      - ./init-db-sql/sakila-data.sql:/docker-entrypoint-initdb.d/2-data.sql
      - ./init-db-sql/init-master.sh:/docker-entrypoint-initdb.d/3-init-master.sh
    command: [
      "--log-bin=mysql-bin",
      "--server-id=${MASTER_SERVER_ID}",
      "--character-set-server=utf8mb4",
      "--collation-server=utf8mb4_unicode_ci",
      "--innodb_flush_log_at_trx_commit=1",
      "--sync_binlog=1"
      ]

  mysql-node-1: &mysql-node
    <<: *mysql
    container_name: mysql-node-1
    environment:
      - MYSQL_ROOT_PASSWORD=${NODE_MYSQL_ROOT_PASSWORD}
      - MASTER_MYSQL_ROOT_PASSWORD=${MASTER_MYSQL_ROOT_PASSWORD}
    ports:
      - "3307:3306"
    depends_on:
      - mysql-master
    volumes:
      - mysql-node-1-data:/var/lib/mysql
      - ./init-db-sql/sakila-schema.sql:/docker-entrypoint-initdb.d/1-schema.sql
      - ./init-db-sql/sakila-data.sql:/docker-entrypoint-initdb.d/2-data.sql
      - ./init-db-sql/init-node.sh:/docker-entrypoint-initdb.d/3-init-node.sh
    command: [
      "--server-id=${NODE_1_SERVER_ID}",
      "--character-set-server=utf8mb4",
      "--collation-server=utf8mb4_unicode_ci",
      ]
  
  mysql-node-2:
    <<: *mysql-node
    container_name: mysql-node-2
    ports:
      - "3308:3306"
    volumes: 
      - mysql-node-2-data:/var/lib/mysql
      - ./init-db-sql/sakila-schema.sql:/docker-entrypoint-initdb.d/1-schema.sql
      - ./init-db-sql/sakila-data.sql:/docker-entrypoint-initdb.d/2-data.sql
      - ./init-db-sql/init-node.sh:/docker-entrypoint-initdb.d/3-init-node.sh
    command: [
      "--server-id=${NODE_2_SERVER_ID}",
      "--character-set-server=utf8mb4",
      "--collation-server=utf8mb4_unicode_ci",
      ]
    

volumes:
  mysql-master-data:
  mysql-node-1-data:
  mysql-node-2-data:
```

由于使用了 YAML 的引用语法，可以通过 `docker-compose config` 查看完整的内容。这里配置了一个主库，两个从库，可以根据需求改变从库数量。

#### 初始化实例

```yaml
    ...
    volumes:
      - mysql-master-data:/var/lib/mysql
      - ./init-db-sql/sakila-schema.sql:/docker-entrypoint-initdb.d/1-schema.sql
      - ./init-db-sql/sakila-data.sql:/docker-entrypoint-initdb.d/2-data.sql
      - ./init-db-sql/init-master.sh:/docker-entrypoint-initdb.d/3-init-master.sh
    ...
```

基础镜像会在初始化(仅首次运行)时按文件名顺序执行 `/docker-entrypoint-initdb.d` 下的 `.sql` `.sh` 等文件，详细信息可以查看镜像说明页面：

https://hub.docker.com/_/mysql/

> Initializing a fresh instance

> When a container is started for the first time, a new database with the specified name will be created and initialized with the provided configuration variables. Furthermore, it will execute files with extensions `.sh`, `.sql` and `.sql.gz` that are found in `/docker-entrypoint-initdb.d`. Files will be executed in alphabetical order. You can easily populate your mysql services by mounting a SQL dump into that directory and provide custom images with contributed data. SQL files will be imported by default to the database specified by the `MYSQL_DATABASE` variable.

*注：`sakila` 是 MySQL 的官方示例数据库 [https://dev.mysql.com/doc/sakila/en/sakila-installation.html](https://dev.mysql.com/doc/sakila/en/sakila-installation.html)*

#### 配置实例参数

```yaml
    ...
    command: [
      "--log-bin=mysql-bin",
      "--server-id=${MASTER_SERVER_ID}",
      "--character-set-server=utf8mb4",
      "--collation-server=utf8mb4_unicode_ci",
      "--innodb_flush_log_at_trx_commit=1",
      "--sync_binlog=1"
      ]
    ...
```

使用执行参数可以不依靠 `my.cnf` 对实例进行配置，详细资料可以查看镜像说明页面：

https://hub.docker.com/_/mysql/

> Configuration without a cnf file
> Many configuration options can be passed as flags to `mysqld`. This will give you the flexibility to customize the container without needing a `cnf` file. For example, if you want to change the default encoding and collation for all tables to use UTF-8 (utf8mb4) just run the following:
>```
>$ docker run --name some-mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw -d mysql:tag --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
>```
> If you would like to see a complete list of available options, just run:
>```
>$ docker run -it --rm mysql:tag --verbose --help
>```

#### 主从配置

##### init-master.sh

```shell
#!/bin/bash

set -e

# create replication user

mysql_net=$(ip route | awk '$1=="default" {print $3}' | sed "s/\.[0-9]\+$/.%/g")

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CREATE USER '${MYSQL_REPLICATION_USER}'@'${mysql_net}' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'${mysql_net}';"
```

在主库中添加用于复制的帐号，由于镜像默认开启 `--skip-name-resolve` 参数，因此只能通过 IP 配置权限。

*注：脚本中是获取容器默认网关网段后添加用户，不适用于生产环境。*

##### init-node.sh

```shell
#!/bin/bash

# check mysql master run status

set -e

until MYSQL_PWD=${MASTER_MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master ; do
  >&2 echo "MySQL master is unavailable - sleeping"
  sleep 3
done

# create replication user

mysql_net=$(ip route | awk '$1=="default" {print $3}' | sed "s/\.[0-9]\+$/.%/g")

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CREATE USER '${MYSQL_REPLICATION_USER}'@'${mysql_net}' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'${mysql_net}';"

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
```

配置从库时会先等待主库就绪，并在从库连接到主库获取必要的参数值进行从库初始化并开启从库复制状态。

## 使用说明

根据需要调整变量值与脚本，修改 `docker-compose.yaml` 中各个实例暴露的端口，在项目目录下执行 `docker-compose up -d` 部署编排。

使用 `docker-compose logs mysql-master` 可以查看对应容器输出日志。

使用 `docker exec -ti mysql-master bash` 可进入对应容器控制台环境。

### 其他

GTIDs 模式需要调整脚本与编排文件中的执行参数。如果想使用容器来为已有实例添加从库，需要修改 `init-node.sh` 将 File 与 Position 作为环境变量传入应该更合适。