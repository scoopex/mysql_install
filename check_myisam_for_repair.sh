#!/bin/bash

exec_query(){
  mysql -A -e "$1" -N -s
  return $?
}

DATABASES="$(exec_query 'show databases'|grep -v -P "performance_schema|information_schema" |xargs)"

TMPFILE="$(mktemp /tmp/repair-XXXXXXXXX.sql)"

echo "REPAIR FILE $TMPFILE"

for DATABASE in $DATABASES;
do
  echo "==> $DATABASE"
  exec_query "show tables FROM $DATABASE"|while read TABLE; do
    exec_query "show create table ${DATABASE}.${TABLE}" | grep -q "ENGINE=MyISAM"
    if [ "$?" != "0" ];then
      continue
    fi

    echo -n "."
    exec_query "select * from ${DATABASE}.${TABLE} limit 10" >/dev/null
    if [ "$?" != "0" ];then
      echo
      echo "BROKEN ${DATABASE}.${TABLE} (see /tmp/repair.sql)"
      echo "REPAIR TABLE ${DATABASE}.${TABLE} EXTENDED;" >>$TMPFILE
    fi
  done
  echo 
done

echo "INFO: completed to identify all crashed tables"
echo "mysql < $TMPFILE"
