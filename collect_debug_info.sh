#!/bin/bash

MYSQL_ARG=" "
LOGDIR=""


usage(){
   echo "USAGE: $0 -l <logdir> -m '<mysql options>'" >&2
   echo >&2
   echo "EXAMPLE: $0 -l /var/log/mysql/collect_debug_info -m '--defaults-file=/root/.my-foobar.cnf'" >&2
   echo
   exit 1
}
while getopts ":m:l:" opt; do
  case $opt in
    m)
      MYSQL_ARG="$OPTARG"
      ;;
    l)
      LOGDIR="$OPTARG"
      ;;

    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ -z "$LOGDIR" ];then
   usage
fi

echo "LOGDIR        : $LOGDIR" >&2
echo "MYSQL OPTIONS : $MYSQL_ARG" >&2

HN=`hostname`
DT=`date "+%d.%m.%Y %H:%M:%S"`
TS=`date "+%Y%m%d"`
VMSTAT_DNAME=${LOGDIR}/${TS}/${HN}-vmstat.txt
NETSTAT_DNAME=${LOGDIR}/${TS}/${HN}-netstat.txt
IOSTAT_DNAME=${LOGDIR}/${TS}/${HN}-iostat.txt
PS_DNAME=${LOGDIR}/${TS}/${HN}-ps.txt
SHOW_DNAME=${LOGDIR}/${TS}/${HN}-showprocesslist.txt

SERVSTAT_DNAME=${LOGDIR}/${TS}/${HN}-serverstatus.txt
FREE_DNAME=${LOGDIR}/${TS}/${HN}-free.txt
GLOBAL_DNAME=${LOGDIR}/${TS}/${HN}-showglobalstatus.txt

if [ -e "/tmp/mysql_collect.lck" ]; then
  echo "`date` already running"
  exit -1;
fi

touch /tmp/mysql_collect.lck
trap "rm -f /tmp/mysql_collect.lck; echo removed /tmp/mysql_collect.lck" INT TERM

mkdir -p ${LOGDIR}/${TS} > /dev/null 2>&1

if (which vmstat &>/dev/null);then
	CMD="vmstat 2 5"
	echo "running ${CMD}"
	ERG=`${CMD}`
	echo "=== ${DT} == ${CMD}" >> ${VMSTAT_DNAME}
	echo "${ERG}" >> ${VMSTAT_DNAME}
	echo >> ${VMSTAT_DNAME}
fi

if (which iostat &>/dev/null);then
	CMD="iostat -dx 2 5"
	echo "running ${CMD}"
	ERG=`${CMD}`
	echo "=== ${DT} == ${CMD}" >> ${IOSTAT_DNAME}
	echo "${ERG}" >> ${IOSTAT_DNAME}
	echo >> ${IOSTAT_DNAME}
fi

CMD="ps -ef"
echo "running ${CMD}"
ERG=`${CMD}`
echo "=== ${DT} == ${CMD}" >> ${PS_DNAME}
echo "${ERG}" >> ${PS_DNAME}
echo >> ${PS_DNAME}

CMD="free"
echo "running ${CMD}"
ERG=`${CMD}`
echo "=== ${DT} == ${CMD}" >> ${FREE_DNAME}
echo "${ERG}" >> ${FREE_DNAME}
echo >> ${FREE_DNAME}

CMD="netstat -anp"
echo "running ${CMD}"
ERG=`${CMD}`
echo "DATUM: ${DT}" >> ${NETSTAT_DNAME}
echo "${ERG}" >> ${NETSTAT_DNAME}
echo >> ${NETSTAT_DNAME}

echo "running SHOW FULL PROCESSLIST"
echo "=== ${DT}" >> ${SHOW_DNAME}
mysql $MYSQL_ARG >> ${SHOW_DNAME} << EOF
show full processlist
EOF
echo >> ${SHOW_DNAME}

echo "running SHOW_GLOBAL STATUS"
echo "=== ${DT}" >> ${GLOBAL_DNAME}
mysql $MYSQL_ARG >> ${GLOBAL_DNAME} << EOF
show global status
EOF
echo >> ${GLOBAL_DNAME}

rm /tmp/mysql_collect.lck


