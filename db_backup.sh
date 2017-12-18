#!/bin/bash

source /var/www/db_backup.config

if [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$UPLOADED_FILES_PATH" ] || [ -z "$LOGS_PATH" ]; then
    echo "Insufficient parameters";
    exit 0;
fi

view_help()
{
cat << _EOF_
____________________________________

-b, --backup  :make backup
-s, --sync    :synchronize
____________________________________
_EOF_
}

make_backup()
{
    if [ "${ENV_TYPE}" != "prod" ]; then
        exit 0;
    fi

    DUMP_FILENAME=dump_$DB_NAME_`date +%d-%m-%Y"_"%H_%M_%S`.sql
    pg_dump --dbname=postgresql://$DB_USER:$DB_PASS@postgres:5432/$DB_NAME > /tmp/$DUMP_FILENAME

    lftp -c "set ssl:ca-file '/etc/ssl/certs/ca_certs.crt'; set ssl:check-hostname no; ftp:ssl-protect-data true; set xfer:log-file '$LOGS_PATH/lftp.log'; open -u $FTP_USER,$FTP_PASS $FTP_HOST; mkdir -p -f $PROJECT_NAME/sqls; put -O $PROJECT_NAME/sqls /tmp/$DUMP_FILENAME; mirror -c -R $UPLOADED_FILES_PATH $PROJECT_NAME/files; bye"

    rm /tmp/$DUMP_FILENAME
}

synchronize()
{
    LAST_SQL_BACKUP=$(lftp -c "set ssl:ca-file '/etc/ssl/certs/ca_certs.crt'; set ssl:check-hostname no; set xfer:log-file '$LOGS_PATH/lftp.log'; open -u $FTP_USER,$FTP_PASS $FTP_HOST; cd $PROJECT_NAME/sqls; ls -lat | head -2 | tail -1; bye" | awk '{print $9}' | grep '.sql')

    if [ -z "$LAST_SQL_BACKUP" ]; then
        echo "Error get sql file path";
        exit 0;
    fi

    echo -n "Static files will be downloaded from backup server. Existing tables from db '$DB_NAME' will be removed and replaced by schema and data from dump file '$LAST_SQL_BACKUP'. Are you sure? (type 'yes' to continue) > ";
    read answer;
    if [ "$answer" == 'yes' ]; then

        lftp -c "set ssl:ca-file '/etc/ssl/certs/ca_certs.crt'; set ssl:check-hostname no; set xfer:log-file '$LOGS_PATH/lftp.log'; open -u $FTP_USER,$FTP_PASS $FTP_HOST; mget -O '/tmp' $PROJECT_NAME/sqls/$LAST_SQL_BACKUP; bye"

        psql -h postgres -p 5432 -U $DB_USER $DB_NAME -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;"

        psql -h postgres -p 5432 -U $DB_USER $DB_NAME < /tmp/$LAST_SQL_BACKUP

        rm /tmp/$LAST_SQL_BACKUP

    else
        echo "Abort"
    fi
}

case $1 in
    -b | --backup ) 	make_backup
		                ;;
    -s | --sync ) 	    synchronize
		                ;;
    * )                 view_help
esac
