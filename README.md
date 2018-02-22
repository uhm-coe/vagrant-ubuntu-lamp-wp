VAGRANT MACHINE SETUP FOR UBUNTU 16.04
======================================

This is a set of bash scripts that will allow a user to set up a virtual machine 
using Vagrant with a LAMP stack and WordPress install.  It includes the following tools:

* apache 2.6
* mysql 5.7.x
* PHP 7.x
* [WP-CLI](http://wp-cli.org/)
* git
* (optional) exim mail client for testing

It presumes the following:

* Running on macOS or Linux
* Using VirtualBox as the VM Host

By default, the credentials for the Database and WordPress are:

User: admin
Pass: vagrant

The default user on login is `vagrant`.

The `/var/www/` directory is mounted to the host OS in the project's `www` folder.
Read more about Synced Folders:  https://www.vagrantup.com/docs/synced-folders/

Users may forego the LAMP and WordPress installs if they just want a basic Ubuntu VM, or
just install LAMP if they do not want WordPress.

THESE SCRIPTS ARE NOT MEANT FOR USE IN A PRODUCTION ENVIRONMENT.  THEY ARE ONLY
INTENDED FOR DEVELOPMENT ENVIRONMENTS.


ISSUES
------

Please open an issue on the GitHub repository if there are any problems!


FIRST TIME SETUP
----------------

### Install Git:
> http://git-scm.com/

### Install VirtualBox for your OS:
> https://www.virtualbox.org/wiki/Downloads

### Install Vagrant:
> http://downloads.vagrantup.com/

### (OPTIONAL) Put this in your /etc/hosts file:
    # vagrant development machines
    192.168.10.10	one.localhost.dev
    192.168.10.20	two.localhost.dev
    etc.


CLONE REPO AND VAGRANT SETUP
----------------------------

### From the terminal, clone our git repository, providing the name of the project being created
    $ cd ~/folder/where/your/projects/live
    $ git clone https://github.com/uhm-coe/vagrant-ubuntu-lamp-wp.git yourprojectname
    $ cd yourprojectname

### Set up the vagrant environment using the included script (Linux/Mac only):
    $ ./scripts/vagrant_setup.sh

### Answer the prompts, and wait for the vagrant box setup to complete

### Next steps
If desired, run the LAMP install and WordPress install in order


LAMP SERVER INSTALLATION
------------------------

### Install LAMP (Linux|Apache|MySQL|PHP) using the install script
##### SSH into your running vagrant-base project
    $ vagrant ssh

##### Run the lamp_setup.sh script
    $ /vagrant/scripts/lamp_setup.sh

### Wait for the installation to complete
    

WORDPRESS INSTALLATION
----------------------
    
### Install WordPress using the install script
##### SSH into your running vagrant-base project
    $ vagrant ssh

##### Launch the wordpress_setup.sh script to install
    $ /vagrant/scripts/wordpress_setup.sh

##### Answer any prompts that may arise

### Wait for the installation to complete


SHUTTING DOWN YOUR PROJECT
--------------------------

### When not working on your project, you can shut it down temporarily:
    $ cd ~/folder/where/your/projects/live
    $ cd yourprojectname
    $ vagrant suspend


RETURNING TO YOUR PROJECT
-------------------------

### Coming back to your project mostly involves making sure that your vagrant machine is up and running:
    $ cd ~/folder/where/your/projects/live
    $ cd yourprojectname
    $ vagrant up
