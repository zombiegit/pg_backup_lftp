#!/bin/bash

if [ "${ENV_TYPE}" != "prod" ]; then
    exit 0;
fi

source /var/www/make_backup.config

if [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$UPLOADED_FILES_PATH" ] || [ -z "$LOGS_PATH" ]; then
    echo "Insufficient parameters";
    exit 0;
fi

DUMP_FILENAME=dump_$DB_NAME_`date +%d-%m-%Y"_"%H_%M_%S`.sql
pg_dump --dbname=postgresql://$DB_USER:$DB_PASS@postgres:5432/$DB_NAME > /tmp/$DUMP_FILENAME

lftp -c "set ssl:ca-file '/etc/ssl/certs/ca_certs.crt'; set ssl:check-hostname no; ftp:ssl-protect-data true; set xfer:log-file '$LOGS_PATH/lftp.log'; open -u $FTP_USER,$FTP_PASS $FTP_HOST; mkdir -p -f $PROJECT_NAME/sqls; put -O $PROJECT_NAME/sqls /tmp/$DUMP_FILENAME; mirror -c -R $UPLOADED_FILES_PATH $PROJECT_NAME/files; bye"

rm /tmp/$DUMP_FILENAME