#!/bin/bash


echo "Install percona xtradb backup"

HOMEDIR="$(getent passwd $INST | cut -d: -f6)"

if [ ! -d "${HOMEDIR}/app/" ];then
  echo "ERROR: ${HOMEDIR}/app/ does not exist"
  exit 1
fi

mkdir -p ${HOMEDIR}/app/percona-xtrabackup 
cd ${HOMEDIR}/app/percona-xtrabackup || exit 1

BASENAME="$(basename $INST_ARCH_DIR/percona-xtrabackup*)"

mkdir -p ${BASENAME%%.tar.gz}

tar -C ${BASENAME%%.tar.gz} --strip-components 1 -zxf $INST_ARCH_DIR/percona-xtrabackup* 
chown -R $INST:$INST ${BASENAME%%.tar.gz}

ln -snf ${BASENAME%%.tar.gz} current

if ( ! egrep -q "PATH.*~/app/percona-xtrabackup/current/bin" ${INSTALLPREFIX}/${INST}/.bash_profile );then
  echo 'export PATH="~/app/percona-xtrabackup/current/bin:$PATH"' >> ${INSTALLPREFIX}/${INST}/.bash_profile
fi
