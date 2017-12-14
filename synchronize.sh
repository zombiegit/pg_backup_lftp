#!/bin/bash

source ${PYTHONPATH}/instance/make_backup.config

if [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$UPLOADED_FILES_PATH" ] || [ -z "$LOGS_PATH" ]; then
    echo "Insufficient parameters";
    exit 0;
fi

LAST_SQL_BACKUP=$(lftp -c "set ssl:ca-file '/etc/ssl/certs/ca_certs.crt'; set ssl:check-hostname no; set xfer:log-file '$LOGS_PATH/lftp.log'; open -u $FTP_USER,$FTP_PASS $FTP_HOST; cd $PROJECT_NAME/sqls; ls -lat | head -2 | tail -1; bye" | awk '{print $9}' | grep '.sql')

if [ -z "$LAST_SQL_BACKUP" ]; then
    echo "Error get sql file path";
    exit 0;
fi

lftp -c "set ssl:ca-file '/etc/ssl/certs/ca_certs.crt'; set ssl:check-hostname no; set xfer:log-file '$LOGS_PATH/lftp.log'; open -u $FTP_USER,$FTP_PASS $FTP_HOST; mget -O '/tmp' $PROJECT_NAME/sqls/$LAST_SQL_BACKUP; mirror -c $PROJECT_NAME/files $UPLOADED_FILES_PATH; bye"

psql -h postgres -p 5432 -U $DB_USER $DB_NAME < /tmp/$LAST_SQL_BACKUP

rm /tmp/$LAST_SQL_BACKUP