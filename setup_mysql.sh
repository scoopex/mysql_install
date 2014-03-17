#!/bin/bash

SKIPFS="${SKIPFS:-no}"
INSTALLGLOB="${INSTALLGLOB:-mysql-}"
INSTALLPREFIX="${INSTALLPREFIX:-/db/mysql/}"
TEMPLATE_PREFIX="templates/${TEMPLATE_PREFIX:-tmpl_my}"
PACEMAKER="${PACEMAKER:-yes}"
PORT="${PORT:-3306}"
PASSWD_ROOT="$RANDOM$RANDOM"
PASSWD_MONITOR="$RANDOM$RANDOM"
PASSWD_PHPMYADMIN="$RANDOM$RANDOM"

usage(){
  cat <<EOF

Environment Variables:

 INST          : Installationsverzeichnis unterhalb ${INSTALLPREFIX}/
 INST_UID      : Username
 MYVER         : Mysql Version
 IPADDR        : IP Adresse
 PORT          : Port
 INTERFACE     : Interface
 PREF_NODE     : Prefered Node
 TYPE          : master|slave (optional)
 SKIPFS        : yes|no (optional)
 INST_ARCH_DIR : Installations Archive Basedir
 INSTALLPREFIX : Installation Dir (default $INSTALLPREFIX)
 INSTALLGLOB   : Archive Glob

Example:

 export INTERFACE=bond0
 export INST=c_mym01
 export INST_UID=5000
 export MYVER="5.5.20"
 export IPADDR=192.168.1.XXX
 export PORT=3306
 export PREF_NODE="foobar-h01-dbXXX"
 export INST_ARCH_DIR="/foo/bar/"

EOF

}

if [ "$INST" == "" ]; then
  echo "INST not set"
  usage
  exit -1
fi
if [ "$INST_UID" == "" ]; then
  echo "INST_UID not set"
  usage
  exit -1
fi
if [ "$MYVER" == "" ]; then
  echo "MYVER not set"
  usage
  exit -1
fi
if [ "$IPADDR" == "" ]; then
  echo "IPADDR not set"
  usage
  exit -1
fi
if [ "$INTERFACE" == "" ]; then
  echo "INTERFACE not set"
  usage
  exit -1
fi
if [ "$PREF_NODE" == "" ]; then
  echo "PREF_NODE not set"
  usage
  exit -1
fi


INST_ARCH_DIR="${INST_ARCH_DIR:-/srv/files/}"


if (  ! ls -1 $INST_ARCH_DIR/${INSTALLGLOB}${MYVER}-linux*.tar.gz &>/dev/null );then
  echo "Missing installation archive: $INST_ARCH_DIR/${INSTALLGLOB}${MYVER}-linux*.tar.gz"
  exit 1
fi 

echo
echo "instance: $INST"
echo "uid/gid: $INST_UID"
echo "mysql version: $MYVER"
echo "listen address: $IPADDR:$PORT"
echo "interface: $INTERFACE"
echo "pref node: $PREF_NODE"
echo "root/repl/backup password: $PASSWD_ROOT"
echo "phpMyAdmin password: $PASSWD_PHPMYADMIN"
echo "monitor password: $PASSWD_MONITOR"


read -p "REALLY CREATE NEW INSTANCE ? ('yesmaster') : " ASK
if [ "$ASK" != "yesmaster" ];then
	exit 1
fi

echo

if ( id $INST &>/dev/null || \
	egrep -q "^.*:.*:$INST_UID:$INST_UID:" /etc/passwd || \
        groups $INST &>/dev/null || \
	egrep -q ":$INST_UID:" /etc/group
   );then
   echo "FAIL: USERID, GROUPID, USER or GROUP already exists"
   exit 1
fi

if ( ! [ -d ${INSTALLPREFIX}/ ] );then
	echo "${INSTALLPREFIX}/ does not exist"
        exit 1
fi

echo "creating user and group"
groupadd -g ${INST_UID}  ${INST}
if [ "$?" != "0" ]; then echo FAIL; exit 1; fi
useradd -u ${INST_UID} -g mysql -G $INST -d ${INSTALLPREFIX}/${INST} -m ${INST} -s /bin/bash
if [ "$?" != "0" ]; then echo FAIL; exit 1; fi

if [ "$SKIPFS" != "yes" ];then
	#echo "fdisk"
	#echo -e "o\nn\np\n\n\n\nw\n"|fdisk /dev/mapper/${INST}

	echo "mkfs.xfs"
#	mkfs.xfs -f /dev/mapper/${INST}_part1
	mkfs.xfs -f /dev/mapper/${INST}

	echo "mounting SAN volume"
	mkdir -p ${INSTALLPREFIX}/${INST}
#	mount /dev/mapper/${INST}_part1 ${INSTALLPREFIX}/${INST}
	mount /dev/mapper/${INST} ${INSTALLPREFIX}/${INST}
	if [ "$?" != "0" ]; then echo FAIL; exit 1; fi
fi

echo "creating folders"
mkdir -p ${INSTALLPREFIX}/${INST}/datadir ${INSTALLPREFIX}/${INST}/bindir ${INSTALLPREFIX}/${INST}/tmpdir ${INSTALLPREFIX}/${INST}/app
if [ "$?" != "0" ]; then echo FAIL; exit 1; fi

echo "extracting mysql binaries"
pushd .
cd ${INSTALLPREFIX}/${INST}/app && \
tar xzf $INST_ARCH_DIR/${INSTALLGLOB}${MYVER}-linux*.tar.gz && \
ln -snf ${INSTALLGLOB}${MYVER}-linux* current 

if [ "$?" != "0" ]; then echo FAIL; exit 1; fi
popd

echo "setup mysql database"
cp ${TEMPLATE_PREFIX}_master.cnf ${INSTALLPREFIX}/${INST}/datadir/my.cnf
if ( [ "`echo ${INST} | egrep "mys|mas"`" != "" ] || [ "$TYPE" = "slave" ] ); then
  cp ${TEMPLATE_PREFIX}_slave.cnf ${INSTALLPREFIX}/${INST}/datadir/my.cnf
fi
sed -i -e "s|{IP}|127.0.0.1|" ${INSTALLPREFIX}/${INST}/datadir/my.cnf
sed -i -e "s|{PORT}|${PORT}|" ${INSTALLPREFIX}/${INST}/datadir/my.cnf
sed -i -e "s|{basedir}|${INSTALLPREFIX}/${INST}/app/current|" ${INSTALLPREFIX}/${INST}/datadir/my.cnf
sed -i -e "s|{datadir}|${INSTALLPREFIX}/${INST}/datadir|" ${INSTALLPREFIX}/${INST}/datadir/my.cnf
sed -i -e "s|{tmpdir}|${INSTALLPREFIX}/${INST}/tmpdir|" ${INSTALLPREFIX}/${INST}/datadir/my.cnf
sed -i -e "s|{bindir}|${INSTALLPREFIX}/${INST}/bindir|" ${INSTALLPREFIX}/${INST}/datadir/my.cnf
chown -R ${INST_UID}:${INST_UID} ${INSTALLPREFIX}/${INST}

${INSTALLPREFIX}/${INST}/app/current/scripts/mysql_install_db --defaults-file=${INSTALLPREFIX}/${INST}/datadir/my.cnf --datadir=${INSTALLPREFIX}/${INST}/datadir --basedir=${INSTALLPREFIX}/${INST}/app/current --user=${INST}

if [ -f ${INSTALLPREFIX}/${INST}/app/current/my.cnf ];then
  echo "adding basedir and datadir to ${INSTALLPREFIX}/${INST}/app/current/my.cnf"
  echo "basedir=${INSTALLPREFIX}/${INST}/app/current" >> ${INSTALLPREFIX}/${INST}/app/current/my.cnf
  echo "datadir=${INSTALLPREFIX}/${INST}/datadir" >> ${INSTALLPREFIX}/${INST}/app/current/my.cnf
fi

echo "setup db homedir"
cat > ${INSTALLPREFIX}/${INST}/datadir/my.cnf.tmp << EOF

[client]
user=root
password=${PASSWD_ROOT}
socket=${INSTALLPREFIX}/${INST}/datadir/mysql.sock

EOF
cat ${INSTALLPREFIX}/${INST}/datadir/my.cnf >> ${INSTALLPREFIX}/${INST}/datadir/my.cnf.tmp
mv ${INSTALLPREFIX}/${INST}/datadir/my.cnf.tmp ${INSTALLPREFIX}/${INST}/datadir/my.cnf

ln -snf ${INSTALLPREFIX}/${INST}/datadir/my.cnf ${INSTALLPREFIX}/${INST}/.my.cnf

cat > ${INSTALLPREFIX}/${INST}/.bash_profile << EOF
export PATH="${INSTALLPREFIX}/${INST}/app/current/bin:\$PATH"
export MANPATH="${INSTALLPREFIX}/${INST}/app/current/man/"
EOF

echo "setup FEDERAL_ADMIN_RESERVE_BANK"
dd if=/dev/zero of=${INSTALLPREFIX}/${INST}/FEDERAL_ADMIN_RESERVE_BANK count=512 bs=1M

echo "setup init script"
cp ${INSTALLPREFIX}/${INST}/app/current/support-files/mysql.server /etc/init.d/${INST}

awk '{print $0}/^service_startup_timeout/{exit 1}' ${INSTALLPREFIX}/${INST}/app/current/support-files/mysql.server > /etc/init.d/${INST}
cat >> /etc/init.d/${INST} <<'EOF'
if [ "$1" = "status" ] && ( ! [ -d "$datadir" ] ||  ! [ -d "$basedir" ] );then
        echo "INSTANCE $(basename $0) NOT ACTIVE ON THIS NODE"
        exit 3
fi
EOF
awk '{if(a == 1){print $0}}/^service_startup_timeout/{a=1}' ${INSTALLPREFIX}/${INST}/app/current/support-files/mysql.server >> /etc/init.d/${INST}

sed -i -e "s/# Provides: mysql/# Provides: ${INST}/" /etc/init.d/${INST}
sed -i -e "s|^basedir=|basedir=${INSTALLPREFIX}/${INST}/app/current|" /etc/init.d/${INST}
sed -i -e "s|^datadir=|datadir=${INSTALLPREFIX}/${INST}/datadir|" /etc/init.d/${INST}
sed -i -e "s|bindir/mysqld_safe --datadir=|bindir/mysqld_safe --defaults-file=\$datadir/my.cnf --user=${INST} --datadir=|" /etc/init.d/${INST}
sed -i -e 's|# Default-Start:.*$|# Default-Start:  2 3 5|' /etc/init.d/${INST}

echo "permission fix"
chown -R ${INST_UID}:${INST_UID} ${INSTALLPREFIX}/${INST}

echo "startup mysql and grant"

/etc/init.d/${INST} start

su -c "mysql -uroot --password='' -S ${INSTALLPREFIX}/${INST}/datadir/mysql.sock" - ${INST} << EOF
drop database IF EXISTS test;
use mysql;
truncate table user;
truncate table db;
grant all privileges on *.* to root@'%' identified by '${PASSWD_ROOT}' with grant option;
grant all privileges on *.* to root@localhost identified by '${PASSWD_ROOT}' with grant option;
grant replication slave, replication client on *.* to repl@'%' identified by '${PASSWD_ROOT}';
grant select on mysql.user to phpMyAdmin@'%' identified by '${PASSWD_PHPMYADMIN}';
grant usage, replication client on *.* to monitor@'%' identified by '${PASSWD_MONITOR}';
grant select, reload, lock tables, replication client, show view on *.* to backup@'%' identified by '${PASSWD_ROOT}';
flush privileges;
EOF

echo "shutdown mysql"
/etc/init.d/${INST} stop

if ( echo "${IPADDR}"|grep "all" );then
 sed -i -e 's|^.*bind-address.*=.*$||'  ${INSTALLPREFIX}/${INST}/datadir/my.cnf
else
  sed -i -e "s|127.0.0.1|${IPADDR}|" ${INSTALLPREFIX}/${INST}/datadir/my.cnf
fi

if [ "$SKIPFS" != "yes" ];then
	echo "unmounting SAN volume"
	umount ${INSTALLPREFIX}/${INST}
	if [ "$?" != "0" ]; then echo FAIL; exit 1; fi
fi

if [ "$PACEMAKER" == "yes" ];then
cat <<EOF
EXECUTE THE FOLLING COMMANDS ON ALL CLUSTER NODES:
-------------------------------------------------------------------------------------------
groupadd -g ${INST_UID} ${INST} ; useradd -u ${INST_UID} -g ${INST_UID} -d ${INSTALLPREFIX}/${INST} ${INST} ; mkdir -p ${INSTALLPREFIX}/${INST} ;  chown -R ${INST_UID}:${INST_UID} ${INSTALLPREFIX}/${INST} ; scp $HOSTNAME:/etc/init.d/${INST} /etc/init.d/
-------------------------------------------------------------------------------------------

ADD THE FOLLOWING CONFIGURATION TO PACEMAKER:
-------------------------------------------------------------------------------------------
primitive db-mount_${INST} ocf:heartbeat:Filesystem \\
        params fstype="xfs" directory="${INSTALLPREFIX}/${INST}" device="/dev/mapper/${INST}" \\
        op start interval="0" timeout="60s" \\
        op monitor interval="30s" timeout="40s"
primitive virtual-ip_${INST} ocf:heartbeat:IPaddr2 \\
        params ip="${IPADDR}" broadcast="193.110.102.255" nic="${INTERFACE}" cidr_netmask="24" \\
        op start interval="0" timeout="50s" \\
        op monitor interval="10s" timeout="25s"
primitive service_${INST} lsb:${INST} \\
        op start interval="0" timeout="120s" \\
        op monitor interval="20s" timeout="60s" start-delay="10s"
group group_${INST} db-mount_${INST} virtual-ip_${INST} service_${INST} \\
        meta migration-threshold="3" target-role="Started" is-managed="true"
location prefer-group_${INST}-on-${PREF_NODE} group_${INST} \\
        rule \$id="prefer-group_${INST}-on-${PREF_NODE}-rule" inf: #uname eq ${PREF_NODE}
-------------------------------------------------------------------------------------------
EOF

fi
