#!/bin/bash

#TODO:
# - my.cnf backupppen
# - letztes Backup aufheben

BACKUPDIR="$1"
MAXAGE="$2"

TIMESTAMP="`date --date="today" "+%Y-%m-%d_%H-%M-%S"`"
STARTTIME_GLOBAL="$SECONDS"

sendStatus(){
    local STATUS="$1"
    echo ">>>>$STATUS<<<<"
    zabbix_sender -s `hostname` -c /etc/zabbix/zabbix_agentd.conf -k mysql.backup.globalstatus -o "$STATUS" > /dev/null
}


if [ -z "$BACKUPDIR" ] || [ -z "$MAXAGE" ];then
	echo "USAGE: $0 <BACKUP PATH> <MAXAGE IN DAYS>"
	exit 1
fi

cd $BACKUPDIR 
if [ "$?" != 0 ];then
        echo "Unable to change to dir '$BACKUPDIR'"
	exit 1 
fi

sendStatus "INFO: STARTING DATABASE BACKUP"

FAILED="0"
while read DBNAME;
do
   echo "*** BACKUP $DBNAME ****************************************************************************"
   if [ "$DBNAME" == "information_schema" ] || [ "$DBNAME" == "performance_schema" ];then
        echo SKIPPED
	continue
   fi
   STARTTIME="$SECONDS"
   mysqldump --opt --triggers --routines --force --single-transaction "$DBNAME"|\
	gzip -c > ${DBNAME}-${TIMESTAMP}_currently_dumping.sql.gz
   RET="$?"

   DURATION="$(( $(( $SECONDS - $STARTTIME )) / 60 ))"
   if [ "$RET" == "0" ];then
        sendStatus "INFO: SUCESSFULLY CREATED BACKUP FOR '$DBNAME' in $DURATION minutes"
	mv ${DBNAME}-${TIMESTAMP}_currently_dumping.sql.gz ${DBNAME}-${TIMESTAMP}.sql.gz
   else
	FAILED="$($FAILED + 1)"
        sendStatus "INFO: FAILED TO BACKUP '$DBNAME'  in $DURATION minutes"
   fi
done < <(mysql --xml -e "show databases;"|grep '<field name="Database">'|sed '~s,^.*<field name="Database">\(..*\)</field>.*$,\1,')

DURATION="$(( $(( $SECONDS - $STARTTIME_GLOBAL )) / 60 ))"
if [ "$FAILED" -gt 0 ];then 
  sendStatus "ERROR: FAILED ($FAILED failed backups, in $DURATION minutes)"
else
  sendStatus "OK: BACKUPS WERE SUCCESSFUL ($DURATION minutes)"
fi

echo "*** REMOVE OUTDATED BACKUPS **********************************************************************"

if ( echo -n "$MAXAGE"|egrep -q '^[0-9][0-9]*$' );then
	find . -name ".sql.gz" -mtime +${MAXAGE} -exec rm -fv {} \;
else
	echo "Age not correctly defined"
	exit 1 
fi

echo "TOTAL AMOUNT OF BACKUPS $( du -scmh *.sql.gz|awk '/total/{print $1}')"
