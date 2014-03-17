export INTERFACE=eth0
export INST=l_mym01
export INST_UID=5000
export MYVER="$1"

if [ -z "$MYVER" ];then
	echo "$0 <version>"
	exit 1
fi

export IPADDR="all"
export PORT=3306
export PREF_NODE="localhost"
export SKIPFS=yes
export INST_ARCH_DIR="/tmp/"

./setup_mysql.sh
