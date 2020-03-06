#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root."
  exit 1
fi
if [ "$1" = "-h" ]; then 
  echo "Please run as root."
  exit 1
fi

#this is a work in progress

ASTERISK_USER="asterisk"

MY_SERVER_NAME="localhost"

FREEPBX_VER="freepbx-15.0-latest.tgz"

header() {
  HEADER=$1
  STRLENGTH=$(echo -n $HEADER | wc -m)
  DISPLAY="  " #65
  center=`expr $STRLENGTH / 2`
  max=`expr 33 - $center`
  echo $max
  for i in $(seq 1 $max)
  do
    DISPLAY="${DISPLAY}-"    
  done
  DISPLAY="${DISPLAY} "$HEADER" "
  
  STRLENGTH=$(echo -n $DISPLAY | wc -m)
  max=`expr 65 - $STRLENGTH`
  for i in $(seq 1 $max)
  do
    DISPLAY="${DISPLAY}-"
  done
    
  clear
  echo "  =================================================================="
  echo "$DISPLAY"
  echo "  =================================================================="
  echo ""
}

install_dep() {
  apt-get install -y openssh-server apache2 mariadb-server\
  mariadb-client bison flex php php-curl php-cli php7.3-common php-mysql php-pear php-gd php-mbstring php-intl\
  curl sox libncurses5-dev libssl-dev mpg123 libxml2-dev libnewt-dev sqlite3\
  libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev\
  libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp2-dev\
  libspandsp-dev sudo subversion libtool-bin python-dev unixodbc dirmngr sendmail-bin sendmail\
  
  apt-get install -y nodejs
  
  apt-get install -y asterisk
    
  pear install Console_Getopt
}

mysql_setup() {
  cat > /etc/mysql/my.cnf <<EOF
[mysqld]
sql_mode=NO_ENGINE_SUBSTITUTION
EOF

  cat <<EOF > /etc/odbcinst.ini
[MySQL]
Description = ODBC for MySQL (MariaDB)
Driver = /usr/local/lib/libmaodbc.so
FileUsage = 1
EOF

  cat <<EOF > /etc/odbc.ini
[MySQL-asteriskcdrdb]
Description = MySQL connection to 'asteriskcdrdb' database
Driver = MySQL
Server = localhost
Database = asteriskcdrdb
Port = 3306
Socket = /var/run/mysqld/mysqld.sock
Option = 3
EOF

}

user_setup() {
  useradd -m asterisk
  chown asterisk. /var/run/asterisk
  chown -R asterisk. /etc/asterisk
  chown -R asterisk. /var/{lib,log,spool}/asterisk
  chown -R asterisk. /usr/lib/asterisk
  rm -rf /var/www/html
}

apache_setup() {
  sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.0/apache2/php.ini
  cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig
  sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
  sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
  a2enmod rewrite
  service apache2 restart
}

freepbx_setup() {  
  mkdir -p /usr/src
  cd /usr/src

  MIRROR="mirror"
  while [ ! -f "$FREEPBX_VER" ]
  do
    URL=http://$MIRROR.freepbx.org/modules/packages/freepbx/$FREEPBX_VER
    header $URL
    wget http://$MIRROR.freepbx.org/modules/packages/freepbx/$FREEPBX_VER
    sleep 1
    case "$MIRROR" in
      mirror)
              MIRROR="mirror1"
               ;;
      mirror1)
              MIRROR="mirror2"
               ;;
      *)
              MIRROR="mirror"
               ;;
    esac      
  done
  touch /etc/asterisk/{modules,cdr}.conf
  rm -R freepbx
  tar vxfz $FREEPBX_VER
    
  cd freepbx

  ./install -n
  
  service apache2 restart
}

post_install() {
  fwconsole ma disablerepo commercial
  fwconsole ma installall
  fwconsole ma delete firewall
  fwconsole ma delete digium_phones
  fwconsole r
}


#------------------------------------------
#-    Main
#------------------------------------------
header "This script is a work in progress"

install_dep

mysql_setup

user_setup

apache_setup

freepbx_setup

post_install
