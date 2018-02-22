#!/bin/bash

# Installs a Linux Apache MySQL PHP (LAMP) stack service on the system.

# Set current directory for basis of script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source color variables
source $script_dir/lib/variables_colors

# Make sure we're in a vagrant vm before continuing
if [ ! -d "/vagrant" ]; then
  echo -e "${red}Error: you need to be in a vagrant virtual machine to run this script.${coloroff}"
  echo -e "Please run ${yellow}vagrant ssh${coloroff} from your project directory to do so."
  exit 1;
fi

# General configuration options; set to IP address for Vagrant box, OR set to domain name
# and set HOSTS file on parent OS to point to the IP address of the Vagrant box.
host_url=$(cat /vagrant/Vagrantfile | grep '[^#][ +]config.vm.network' | cut -d: -f2 | xargs)
mysql_root_pass=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 12 | xargs)


# Install MySQL
sudo debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password string ${mysql_root_pass}"
sudo debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password_again string ${mysql_root_pass}"
sudo debconf-set-selections <<< "mysql-server-5.5 mysql-server-5.5/start_on_boot boolean true"
sudo apt-get install -y  mysql-server

# Configure ~/vagrant/.my.cnf to allow mysql root logins by Vagrant user.
printf "[client]\nhost = localhost\nuser = root\npassword = ${mysql_root_pass}\n" > /home/vagrant/.my.cnf

# Install PHP and Apache (set up LAMP server):
sudo apt-get install -y lamp-server^

# Install necessary PHP Packages:
sudo apt-get install -y php-gd php-mcrypt php-ldap php-curl php-xdebug php-mbstring php-memcached php-xml memcached libcurl4-openssl-dev php-zip

# Configure xdebug for vagrant environment. Use by appending
# ?XDEBUG_SESSION_START=whatever to your php-based URL.
# https://xdebug.org/docs/remote
# Note: If you want to enable xdebug without using the querystring, set
# remote_autostart=1 in the config below, and restart apache.
if ! grep -q remote_enable /etc/php/7.0/mods-available/xdebug.ini ; then
  cat <<EOL | sudo tee -a /etc/php/7.0/mods-available/xdebug.ini

xdebug.remote_enable=1
xdebug.remote_host='192.168.10.1'
xdebug.remote_port='9000'
xdebug.remote_autostart=0
xdebug.remote_connect_back=1
xdebug.remote_handler='dbgp'
xdebug.remote_mode='jit'
xdebug.idekey='vagrant'
EOL
  sudo service apache2 reload
fi

# Write default httpd.conf
# NOTE:  This is no longer default behavior; instead it should be stored in /etc/apache2/conf-available/something.conf and then
# set to enabled using a2enconf.  These steps have been added.  PK
printf "ServerName localhost\n" | sudo tee /etc/apache2/conf-available/servername.conf
sudo a2enconf servername
sudo service apache2 reload

# Write default apache config (redirect to https):
cat <<EOF | sudo tee /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName $host_url

    # Disable sendfile support because of virtualbox bug.
    # See: https://www.vagrantup.com/docs/synced-folders/virtualbox.html
    ServerSignature Off
    TraceEnable Off
    EnableSendfile Off

    DocumentRoot /var/www/html
    <Directory />
        Options FollowSymLinks
        AllowOverride All
    </Directory>
    <Directory /var/www/html/>
        Options -Indexes +FollowSymLinks +MultiViews
        AllowOverride All
        Order allow,deny
        allow from all
    </Directory>

    ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
    <Directory "/usr/lib/cgi-bin">
        AllowOverride None
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
        Order allow,deny
        Allow from all
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log

    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn

    CustomLog \${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
EOF


# Enable Apache modules:
sudo a2enmod headers
sudo a2enmod rewrite
# sudo a2ensite 000-default
sudo service apache2 restart


# Switch Apache user to vagrant (since /var/www is a vagrant shared folder, we
# cannot set owner or permissions on it from inside the vagrant machine. We
# sidestep the issue by running Apache as the default user, so it has write
# permissions to /var/www.  Also grant the vagrant user access to /var/log/apache2/
sudo sed -i 's/APACHE_RUN_USER=www-data/APACHE_RUN_USER=vagrant/' /etc/apache2/envvars
sudo sed -i 's/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=vagrant/' /etc/apache2/envvars
sudo chown -R vagrant:www-data /var/lock/apache2
sudo usermod -aG adm vagrant
sudo service apache2 restart
