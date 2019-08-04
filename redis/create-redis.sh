#!/bin/bash
# Program:
# This program is used to create, start, stop or clear the redis-cluster.
# But the redis version need to be greater than 5;
# Now the script only supports creating clusters on one node.

# History:
# 2019/06/09 rod First release
#
# Prepared:
# yum install -y wget
# yum install -y gcc-c++
#
# Note:
# redis-version need to be greater than 5;

REDIS_VERSION="5.0.5"
# redis 集群的ip,该集群搭建在同一台机器上
REDIS_IP="192.168.19.130"
# redis 集群的端口
REDIS_PORTS=(7001 7002 7003 7004 7005 7006)
# redis 集群的安装路径
INSTALL_PATH="/usr/local"
# redis 集群的安装文件夹名
INSTALL_DIR_NAME="redis-cluster"
# redis 安装临时文件目录, 用于临时存储make生成的文件(redis-cli,redis-server等文件,完成后会删除)
INSTALL_TEMP_DIR="/usr/local/redis"

function startCluster(){
    echo "begin to start all nodes"
    for port in ${REDIS_PORTS[@]}; do
        cd ${INSTALL_PATH}/${INSTALL_DIR_NAME}/${port}
        ./redis-server ./redis.conf
    done
    ps aux|grep redis
}

function createCluster() {
    echo "begin to install ${INSTALL_DIR_NAME} in the '${INSTALL_PATH}' path."
    test -f "redis-${REDIS_VERSION}.tar.gz" && echo "The redis installation package exists" || wget "http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz"
    echo "begin to make directory and decompress the redis."
    if [ ! -d "${INSTALL_PATH}/${INSTALL_DIR_NAME}" ]; then
        mkdir ${INSTALL_PATH}/${INSTALL_DIR_NAME}
    fi
    cp redis-${REDIS_VERSION}.tar.gz ${INSTALL_PATH}/${INSTALL_DIR_NAME}
    cd ${INSTALL_PATH}/${INSTALL_DIR_NAME}
    pwd
    tar -zxvf redis-${REDIS_VERSION}.tar.gz
    for port in ${REDIS_PORTS[@]}; do
        mkdir ${port}
    done
    ls

    echo "begin to compile the redis"
    cd ${INSTALL_PATH}/${INSTALL_DIR_NAME}/redis-${REDIS_VERSION}
    pwd
    make
    cd src
    make PREFIX=${INSTALL_TEMP_DIR} install

    echo "begin to copy the config to all the nodes"
    for port in ${REDIS_PORTS[@]}; do
        cp ${INSTALL_PATH}/${INSTALL_DIR_NAME}/redis-${REDIS_VERSION}/redis.conf ${INSTALL_PATH}/${INSTALL_DIR_NAME}/${port}
    done

    # 编辑所有配置文件
    #port 7001
    #daemonize yes
    #pidfile /var/run/redis_7001.pid
    #bind ${REDIS_IP}
    #cluster-enabled yes
    echo "begin to edit the config of all nodes"
    for port in ${REDIS_PORTS[@]}; do
        sed -i '/^port/c port '${port}'' ${INSTALL_PATH}/${INSTALL_DIR_NAME}/${port}/redis.conf
        sed -i '/^daemonize/c daemonize yes' ${INSTALL_PATH}/${INSTALL_DIR_NAME}/${port}/redis.conf
        sed -i '/^pidfile/c pidfile /var/run/redis_'${port}'.pid' ${INSTALL_PATH}/${INSTALL_DIR_NAME}/${port}/redis.conf
        sed -i '/^bind/c bind '${REDIS_IP}'' ${INSTALL_PATH}/${INSTALL_DIR_NAME}/${port}/redis.conf
        sed -i '/^# cluster-enabled/c cluster-enabled yes' ${INSTALL_PATH}/${INSTALL_DIR_NAME}/${port}/redis.conf
    done

    echo "begin to copy the redis-cli, redis-server and so on"
    for port in ${REDIS_PORTS[@]}; do
        cp ${INSTALL_PATH}/redis/bin/* ${INSTALL_PATH}/${INSTALL_DIR_NAME}/${port}/
    done
    cp ${INSTALL_PATH}/redis/bin/* ${INSTALL_PATH}/${INSTALL_DIR_NAME}/

    echo "begin to the install file"
    rm -rf ${INSTALL_PATH}/redis/

    startCluster

    # 创建集群
    #./redis-cli --cluster create ${REDIS_IP}:7001 ${REDIS_IP}:7002 ${REDIS_IP}:7003 ${REDIS_IP}:7004 ${REDIS_IP}:7005 ${REDIS_IP}:7006 --cluster-replicas 1
    echo "create redis cluster"
    create_cluster="${INSTALL_PATH}/${INSTALL_DIR_NAME}/redis-cli --cluster create"
    for port in ${REDIS_PORTS[@]}; do
        create_cluster="${create_cluster} ${REDIS_IP}:${port}"
    done
    create_cluster="${create_cluster} --cluster-replicas 1"
    echo ${create_cluster}
    ${create_cluster}
}

function shutdown() {
    echo "begin to shutdown the redis-cluster."
    cd ${INSTALL_PATH}/${INSTALL_DIR_NAME}
#    pwd
    for port in ${REDIS_PORTS[@]}; do
       ./redis-cli -h ${REDIS_IP} -p ${port} shutdown
    done
    echo "all nodes has been shutdown."
    ps aux|grep redis
}

function clear() {
    echo "begin to clear previous redis-cluster."
    count=`ps aux|grep redis|wc -l`
    if [ count==${#REDIS_PORTS[@]} ]; then
        shutdown
    fi
    test -d "${INSTALL_PATH}/${INSTALL_DIR_NAME}" && rm -rf ${INSTALL_PATH}/${INSTALL_DIR_NAME}
    echo "the previous redis-cluster has been cleared."
}

case ${1} in
    "start")
        startCluster
        ;;
    "create")
        createCluster
        ;;
    "shutdown")
        shutdown
        ;;
    "clear")
        clear
        ;;
    *)
        echo "Usage ${0} {start|create|shutdown|clear}"
        ;;
esac