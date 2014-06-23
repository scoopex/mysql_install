mysql_install
=============

A simple script to install mysql/mariadb databases.

The script create mysql/mariadb instances with the following characteristics:
* the database instance runs in a dedicated directory to use a fiberchannel/san volume
* the database instance with a dedicated user
  (group mysql, to allow usage of linux hugepages)
* multiple database instances (with different releases) can be executed
* the script creates pacemaketr configuration commands to add the instance to a pacemaker cluster
  * the fiberchannel/san volume needs to be only used for a single instance
  * the fiberchannel/san volume should be available at all systems
  * split brain problems have to be prevented by STONITH (i.e. using IPMI)

Please forgive the poor documentation, this is work in progress.

MariaDB Installation
====================


* TODO: Configure linux hugepages
* TODO: Configure a dedicated mountpoint fpr the database
* Install Percona Toolkit : http://www.percona.com/downloads/percona-toolkit/LATEST/RPM/
* Install the tooling
```
mkdir /data/tools
cd /data/tools
git clone git@github.com:scoopex/mysql_install.git
sudo su -
```
* Download installation binaries to /data/tools/mysql_install/install
  * MariaDB: https://downloads.mariadb.org/
    ("mariadb-5.5.36-linux-x86_64.tar.gz")
  * XtraDB Backup: http://www.percona.com/software/percona-xtrabackup
    ("percona-xtrabackup-2.1.8-733-Linux-x86_64.tar.gz")
    
* Install a new instance
```
groupadd -g 27 mysql
mkdir -p /data/mariadb/
cd /data/tools/mysql_install
export PASSWD_MONITOR="myfunkypassword"
# - Change version number
# - Execute installation procedure
# - ANswer questions
./local_mariadb_database.sh
```
* Start instance and add it to system startup procedure
```
/etc/init.d/l_mam01 start
chkconfig l_mam01 on
```
* Test the new instance
```
su - l_mam01
mysql
exit
```
* Create a cronjob (i.e. at the slave) 
```
crontab -l
0 5,8,11,14,17,20 * * * /data/tools/mysql_install/backup-databases.sh /data/mariadb/l_mas01/backup/ 3
```


Manage databases
=================


* Define passwords
```
# User for regular application access, without ddl permissions
export APP_PASSWORD="$RADNOM$RANDOM$RANDOM"
# User for privileged administration access, with ddl permissions
export ADM_PASSWORD="$RADNOM$RANDOM$RANDOM"
```
* Get information about the dbcreator.sh Script
```
/data/tools/mysql_install/dbcreator.sh
```
* Manage datbases
 * Create two databases "foo1" and "foo2" and two users "fooapp_adm" and "fooapp_app" which can access the databases
```
/data/tools/mysql_install/dbcreator.sh -u fooapp -d foo1 -d foo2
```
 * Create a new datbases and resuse the users fooapp_adm and fooapp_app
```
/data/tools/mysql_install/dbcreator.sh -u fooapp -d foo3 -c db
```
 * TODO: TO BE CONTINUED
 

