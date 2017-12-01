#!/bin/bash

. ./make_backup.config
echo $DOCKER_CONTAINER_NAME

CONTAINER_ID=$(docker ps | grep $DOCKER_CONTAINER_NAME | awk '{print $1}')
if [ -z $CONTAINER_ID ] ;
then echo "Cant find docker container with this name"; 
     exit 0;
fi

mkdir -p $DB_NAME/sqls
mkdir -p $DB_NAME/files

ssh $SSH_USER@$SSH_HOST "docker exec -t -u postgres $CONTAINER_ID pg_dump $DB_NAME" > $DB_NAME/sqls/dump_$DB_NAME_`date +%d-%m-%Y"_"%H_%M_%S`.sql

rsync -p -t -r -e "ssh -p $SSH_PORT" --log-file=rsync.log $SSH_USER@$SSH_HOST:$UPLOADED_FILES_PATH ./$DB_NAME/files 
