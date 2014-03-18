#!/bin/bash

TEST="false"
DATABASES=""
DBUSER_PREFIX=""
REMOVE="nothing"
CREATE="both"	
APP_PASSWORD="${APP_PASSWORD:-$RANDOM$RANDOM$RANDOM}"
ADM_PASSWORD="${ADM_PASSWORD:-$RANDOM$RANDOM$RANDOM}"
MAX_CONN_ADM="500"
MAX_CONN_APP="500"

##############################################################################################
###
### HELPERS

usage(){
	cat <<EOF
$0 <OPTIONS> -- <MYSQL OPTIONS>

  -u : Username des neuen Users 
       (es sind nur 12 Zeichen erlaubt)
  -d : Namen der Datenbanken (Mit Leerzeichen trennen und alles in Quotes fassen)
  -r : Datenbank bzw. User entfernen: 
        user    : Lösche den User
        db      : Lösche die Datenbank
        both    : Lösche Datenbank und User
        nothing : Nichts löschen (default)
  -c : User bzw. Datenbanken anlegen
        user    : Lege den User an
        db      : Lege die Datenbank an
        both    : Lege User und Datenbank an (default)
        nothing : Nichts anlegen 
  -d : Namen der Datenbanken (In Quotes fassen)
  -a : Anzahl der erlaubten App Verbindungen (default $MAX_CONN_APP)
  -b : Anzahl der erlaubten Adm Verbindungen (default $MAX_CONN_ADM)
  -t : Test (nix machen)

  Beispiel MB3 Datenbank:
  $0 -m foobar_l01

  Beispiel einzelne Datenbanken:
  $0 -d foobar_t02_foo -d foobar_t02_bar -u foobar_t02

EOF

}

while getopts "sc:td:r:u:a:b:" optname
  do
    case "$optname" in
     "a")
         MAX_CONN_ADM="$OPTARG"
	 ;;
     "b")
         MAX_CONN_APP="$OPTARG"
	 ;;
     "u")
	 DBUSER_PREFIX="$OPTARG"	
	 ;;
     "r")
	 REMOVE="$OPTARG"	
	 ;;
     "c")
	 CREATE="$OPTARG"	
	 ;;
     "s")
	 STANDARDS="false"	
	 ;;
     "d")
	 DATABASES="$DATABASES $OPTARG"	
	 ;;
      "t")
         TEST="true"
         ;;
      *)
      # Should not occur
        echo "ERROR: Unknown error while processing options"
        usage
        exit 1
        ;;
    esac
done
shift $((OPTIND-1))

MYSQL_ARGS="$@"

if ( [ -z "$DBUSER_PREFIX" ] || [ -z "$DATABASES" ] ); then
  usage
  exit 1
fi


##############################################################################################
###
### CHECK NAMING

if [ "`echo -n "$DBUSER_PREFIX" |wc -c`" -gt 12 ];then
  echo "ERROR: username too long with _adm/_app suffix (only 12 characters allowed, `echo -n "$DBUSER_PREFIX" |wc -c` used)"
  exit 1
fi

# FUER MYSQL 5.6, da unteliegen Schemaaenderungen dann auch Transaktionen
COMMANDS="$(cat <<EOF
SET autocommit=0;
START TRANSACTION;
EOF
)"

##############################################################################################################
# Vorhandene User löschen
if ( [ "$REMOVE" == "user" ] || [ "$REMOVE" == "both" ] );then
COMMANDS="$COMMANDS $(cat <<EOF

DROP USER '${DBUSER_PREFIX}_app'@'%';
DROP USER '${DBUSER_PREFIX}_adm'@'%';
EOF
)"
fi

##############################################################################################################
# Vorhandene DBs löschen
if ( [ "$REMOVE" == "db" ] || [ "$REMOVE" == "both" ] );then
 for db in $DATABASES;
  do
COMMANDS="$COMMANDS
$(cat <<EOF
DROP DATABASE \`$db\`;

EOF
)"
  done
fi

##############################################################################################################
# Erstelle Datenbanken

if ( [ "$CREATE" == "db" ] || [ "$CREATE" == "both" ] ) ;then

for db in $DATABASES;
do
COMMANDS="$COMMANDS $(cat <<EOF

CREATE DATABASE \`$db\` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
EOF
)"
done

fi

##############################################################################################################
# Neue User anlegen

if ( [ "$CREAT" == "user" ] || [ "$CREATE" == "both" ] ) ;then

COMMANDS="$COMMANDS $(cat <<EOF

CREATE USER '${DBUSER_PREFIX}_app'@'%' IDENTIFIED BY '${APP_PASSWORD}';
GRANT USAGE ON * . * TO '${DBUSER_PREFIX}_app'@'%' IDENTIFIED BY '${APP_PASSWORD}' WITH MAX_QUERIES_PER_HOUR 0 
   MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS $MAX_CONN_APP ;
REVOKE ALL PRIVILEGES ON *  . *  FROM '${DBUSER_PREFIX}_app'@'%';
CREATE USER '${DBUSER_PREFIX}_adm'@'%' IDENTIFIED BY '${ADM_PASSWORD}';
GRANT USAGE ON * . * TO '${DBUSER_PREFIX}_adm'@'%' IDENTIFIED BY '${ADM_PASSWORD}' WITH MAX_QUERIES_PER_HOUR 0 
MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS $MAX_CONN_ADM ;
REVOKE ALL PRIVILEGES ON *  . *  FROM '${DBUSER_PREFIX}_adm'@'%';
EOF
)"

for db in $DATABASES;
do
COMMANDS="$COMMANDS $(cat <<EOF

GRANT SELECT , INSERT , UPDATE , DELETE , EXECUTE
 ON \`$db\` . * TO '${DBUSER_PREFIX}_app'@'%' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS $MAX_CONN_APP ;
GRANT SELECT , INSERT , UPDATE , DELETE , CREATE , DROP , INDEX , ALTER , CREATE TEMPORARY TABLES , LOCK TABLES ,
 CREATE VIEW , SHOW VIEW , CREATE ROUTINE, ALTER ROUTINE, EXECUTE, EVENT, TRIGGER
 ON \`$db\` . * TO '${DBUSER_PREFIX}_adm'@'%' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS $MAX_CONN_ADM ;
EOF
)"
done
elif ( [ "$CREATE" == "db" ] && [ "$CREATE" != "both" ] ) ;then

for db in $DATABASES;
do
COMMANDS="$COMMANDS $(cat <<EOF

GRANT SELECT , INSERT , UPDATE , DELETE , EXECUTE
 ON \`$db\` . * TO '${DBUSER_PREFIX}_app'@'%' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 
 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS $MAX_CONN_APP ;
GRANT SELECT , INSERT , UPDATE , DELETE , CREATE , DROP , INDEX , ALTER , CREATE TEMPORARY TABLES , LOCK TABLES ,
 CREATE VIEW , SHOW VIEW , CREATE ROUTINE, ALTER ROUTINE, EXECUTE, EVENT, TRIGGER
 ON \`$db\` . * TO '${DBUSER_PREFIX}_adm'@'%' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 
 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS $MAX_CONN_ADM ;
EOF
)"
done
 APP_PASSWORD="n/a"
 ADM_PASSWORD="n/a"

else
 APP_PASSWORD="n/a"
 ADM_PASSWORD="n/a"
fi


##############################################################################################################
# geänderte Privileges aktivieren

COMMANDS="$COMMANDS $(cat <<EOF

COMMIT;
FLUSH PRIVILEGES;
EOF
)"

##############################################################################################################
# Änderungen ausführen

if [ "$TEST" != "true" ];then
 echo "$COMMANDS" | mysql -vv $MYSQL_ARGS mysql 
 if [ "$?" != "0" ];then
   echo "FAILED"
   echo
   echo "Kommandos:"
   echo "-----"
   echo "$COMMANDS"
   echo "-----"
   exit 1
 fi
else
 echo "INFO: Skipping creation, testmode...."
fi

##############################################################################################################
# Details ausgeben
#
echo "=============================================================================================================="
echo "Details zur angelegten Datenbank:"

echo "Kommandos:"
echo "-----"
echo "$COMMANDS"
echo "-----"


echo "-----"
echo "DB HOSTNAME  : 'FIXME'"
for dbn in $DATABASES;
do
 echo "DB NAME      : '$dbn'"
done

echo "APP DBUSER   : '${DBUSER_PREFIX}_app' (MAX CONNECTIONS: $MAX_CONN_APP)"
echo "APP PASSWORD : '${APP_PASSWORD}'"
echo "ADM DBUSER   : '${DBUSER_PREFIX}_adm' (MAX CONNECTIONS: $MAX_CONN_ADM)"
echo "ADM PASSWORD : '${ADM_PASSWORD}'"
echo "-----"
echo
echo "=============================================================================================================="

