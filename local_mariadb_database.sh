export INTERFACE=eth0

read -p "master/slave : " TYPE

if [ "$TYPE" == "master" ];then 
	export INST=l_mam01
	export INST_UID=5001
	export PORT=3307
elif [ "$TYPE" == "slave" ];then
	export INST=l_mas01
	export INST_UID=5002
	export PORT=3308
else
	exit 1
fi

export MYVER="5.5.36"
export INSTALLGLOB="mariadb-"
export INSTALLPREFIX="/data/mariadb/"
export TEMPLATE_PREFIX="tmpl_mariadb"
export PACEMAKER="no"

export IPADDR="all"
export PREF_NODE="localhost"
export SKIPFS=yes
export INST_ARCH_DIR="$PWD/install/"

./setup_mysql.sh &&
./setup_perconaxtradb_backup.sh

echo "do not forget to enable service

Ubuntu: 
	update-rc.d $INST defaults
	start $INST

SLES/RHEL:
	chkconfig $INST on
        service $INST start
"
