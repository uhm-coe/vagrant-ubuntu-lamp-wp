#!/bin/bash
# This script should be run AFTER the initial ubuntu_setup.sh has been run, 
# and the subsequent lamp_setup.sh script has also been run.

# Set current directory for basis of script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source color variables
source $script_dir/lib/variables_colors

# Source functions for printing status messages
source $script_dir/lib/functions_messages

# Make sure we're in a vagrant vm before continuing
if [ ! -d "/vagrant" ]; then
  echo -e "${red}Error: you need to be in a vagrant virtual machine to run this script.${coloroff}"
  echo -e "Please run ${yellow}vagrant ssh${coloroff} from your project directory to do so."
  exit 1;
fi

# These values can remain static, or can be changed to suit the needs of the user.
# SITENAME should be changed to the actual name of the Wordpress site being developed.
db_name=development
db_user=admin
db_pass=vagrant
db_host=localhost
wp_url=$(cat /vagrant/Vagrantfile | grep '[^#][ +]config.vm.network' | cut -d: -f2 | xargs)
wp_name=SITENAME

print_message "Downloading and installing Wordpress CLI tool..."
print_ok

# Download the Wordpress CLI tool, and make sure it's available.
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
sudo wp cli update --nightly

# Test that it's installed correctly
wp --info | grep -q 'WP-CLI version' &> /dev/null
if [ $? = 0 ]; then
    echo -e "[ ${green}OK${coloroff} ] Wordpress CLI Successfully installed!"
else
    echo -e "[ ${red}FAIL${coloroff} ] There was an issue with the Wordpress CLI installation, exiting..."
    exit 1
fi

print_message "Configuring database for Wordpress usage..."
print_ok

# Create default MySQL database and user (using db_name, db_user, db_pass values above):
mysql -e "CREATE DATABASE ${db_name}; GRANT ALL ON ${db_name}.* TO ${db_user}@localhost IDENTIFIED BY '${db_pass}';"

# Check that the database was set up correctly.
if [ $? = 0 ]; then
  echo -e "[ ${green}OK${coloroff} ] Database successfully configured for Wordpress!"
else
  echo -e "[ ${red}FAIL${coloroff} ] There was an issue with configuring the MySQL database, exiting..."
  exit 1
fi

print_message "Installing Wordpress to /var/www/html directory..."
print_ok

# Install Wordpress into the /var/www/html/ directory with the supplied information
# NOTE:  If the install is in a sub-directory of /var/www/html, please add that here, and uncomment the wp option task below.

cd /var/www/html
rm -r index.html
wp core download
wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_pass --dbhost=$db_host
wp core install --url=http://$wp_url --title="$wp_name" --admin_user="$db_user" --admin_password="$db_pass" --admin_email=admin@example.com 2> /dev/null


print_message "Enable WP_DEBUG, WP_DEBUG_LOG, and FTP settings in wp-config.php (overwriting existing wp-config)..."
print_ok
rm -f wp-config.php
printf "define( 'WP_DEBUG', true );\ndefine( 'WP_DEBUG_LOG', true );\n\ndefine( 'FS_METHOD', \"ftpext\" );\ndefine( 'FTP_BASE', \"/var/www/html/\" );\ndefine( 'FTP_USER', \"vagrant\" );\ndefine( 'FTP_PASS', \"password\" );\ndefine( 'FTP_HOST', \"${wp_url}\" );\ndefine( \"FTP_SSL\", false);" | wp core config --dbname=${db_name} --dbuser=${db_user} --dbpass=${db_pass} --dbhost=${db_host} --extra-php

print_message "Updating default WordPress settings..."
print_ok

## General Settings:
print_message "Setting timezone to Honolulu..."
print_ok
wp option update timezone_string "Pacific/Honolulu"

## Discussion Settings:
print_message "Disabling 'Attempt to notify any blogs linked to from the article'..."
print_ok
wp option update default_pingback_flag 0
print_message "Disabling 'Allow link notifications from other blogs (pingbacks and trackbacks) on new articles'..."
print_ok
wp option update default_ping_status 0
print_message "Disabling 'Allow people to post comments on new articles'..."
print_ok
wp option update default_comment_status 0
print_message "Enabling 'Users must be registered and logged in to comment'..."
print_ok
wp option update comment_registration 1
print_message "Enabling 'Comment must be manually approved'..."
print_ok
wp option update comment_moderation 1
print_message "Disabling comments on all existing posts..."
print_ok
wp post list --format=ids | xargs wp post update --comment_status=closed
print_message "Disabling pingbacks on all existing posts..."
print_ok
wp post list --format=ids | xargs wp post update --ping_status=closed

## Permalink Settings:
print_message "Setting permalink structure to 'Post name'..."
print_ok
printf "apache_modules:\n  - mod_rewrite\n" >> ~/.wp-cli/config.yml
wp rewrite structure --hard '/%postname%/'


# Uncomment this option if your site is in a sub-directory of the main /var/www/html/ folder.
# wp option update siteurl http://{$wp_url}/location


echo -e "[ ${green}OK${coloroff} ] Install has completed!"
if [ ! $is_production = true ]; then
	echo "Admin:  $db_user    Password:  $db_pass"
fi
echo "Please log in immediately to http://$wp_url/wp-admin/ with the admin user and change the password!"

exit 0
