#!/bin/bash


#TODO:
# - my.cnf backupppen
# - letztes Backup aufheben
# - fehlgeschlagene Bacjups entfernen

BACKUPDIR="$1"
MAXAGE="$2"

TIMESTAMP="`date --date="today" "+%Y-%m-%d_%H-%M-%S"`"

sendStatus(){
    local STATUS="$1"
    zabbix_sender -s `hostname` -c /etc/zabbix/zabbix_agentd.conf -k mysql.backup.globalstatus -o "$STATUS" -vvv
}

cd $BACKUPDIR 
if [ "$?" != 0 ];then
        echo "Unable to change to dir '$BACKUPDIR'"
	exit 1 
fi

FAILED="0"
while read DBNAME;
do
   echo "*** BACKUP $DBNAME ****************************************************************************"
   if [ "$DBNAME" == "information_schema" ] || [ "$DBNAME" == "performance_schema" ];then
        echo SKIPPED
	continue
   fi
   mysqldump --opt --triggers --routines --force --single-transaction "$DBNAME"|\
	gzip -c > ${DBNAME}-${TIMESTAMP}_currently_dumping.sql.gz
   RET="$?"
   if [ "$RET" == "0" ];then
	echo "SUCESSFULLY CREATED BACKUP FOR '$DBNAME'"
	mv ${DBNAME}-${TIMESTAMP}_currently_dumping.sql.gz ${DBNAME}-${TIMESTAMP}.sql.gz
   else
	FAILED="$($FAILED + 1)"
	echo "FAILED TO BACKUP '$DBNAME'"
   fi
done < <(mysql --xml -e "show databases;"|grep '<field name="Database">'|sed '~s,^.*<field name="Database">\(..*\)</field>.*$,\1,')

if [ "$FAILED" -gt 0 ];then 
  echo "OVERALL STATUS: FAILED ($FAILED backups)"
else
  echo "OVERALL STATUS: SUCCESS"
fi

echo "*** REMOVE OUTDATED BACKUPS **********************************************************************"

if ( echo -n "$MAXAGE"|egrep -q '^[0-9][0-9]*$' );then
	find . -name ".sql.gz" -mtime +${MAXAGE} -exec rm -fv {} \;
else
	echo "Age not correctly defined"
	exit 1 
fi


