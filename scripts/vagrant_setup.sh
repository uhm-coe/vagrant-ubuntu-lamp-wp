#!/bin/bash

# This script prompts the user for a list of items to configure their Vagrantfile.
# After finishing, it launches the initial_boot.sh script to install basic services on the machine.
# Any additional services may be installed via the additional available scripts.
# Some settings made in this script will propagate over to other setup scripts, such as IP address.

# Set current directory for basis of script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#
script_name=$( cat <<EOF
Name: Initialize vagrant environment - Ubuntu 16.04
EOF
)
script_version=$( cat <<EOF
Version: x.1
EOF
)
script_desc=$( cat <<EOF
Description:
  Initializes a vagrant environment. Creates a default Vagrantfile from user-
  specified options, and boots the machine.  After initial boot, sets up the
EOF
)
script_usage=$( cat <<EOF
Usage:
  $ ./start [[--base-box|-b] nameofbox] [[--ip-address|-i] ipaddress] [--bridged-network|-b] [[--memory-size|-m] memoryinmegabytes] [--help|-h] [--version|-v]
EOF
)

# Rewrite gnu-style long options (command line arguments)
for arg
do
  delim=""
  case "$arg" in
    --base-box) args="${args}-b ";;
    --ip-address) args="${args}-i ";;
    --bridged-network) args="${args}-n ";;
    --memory-size) args="${args}-m ";;
    --help) args="${args}-h ";;
    --version) args="${args}-v ";;
    *) [[ "${arg:0:1}" == "-" ]] || delim="\""
      args="${args}${delim}${arg}${delim} ";;
  esac
done
eval set -- $args

# Parse command line options
while getopts ":b:u:i:n:m:hv" OPTIONS; do
  case $OPTIONS in
    b) base_box=${OPTARG[@]};;
    i) ip_address=${OPTARG[@]};;
    n) bridged_network="config.vm.network :bridged";;
    i) memory_size=${OPTARG[@]};;
    h) echo -e "$script_name\n$script_version\n$script_desc\n$script_usage"
      exit 1;;
    v) echo -e "$script_version"
      exit 1;;
  esac
done

# Source color variables
source $script_dir/lib/variables_colors

# Source functions for printing status messages
source $script_dir/lib/functions_messages


# Make sure we're not in a vagrant vm before continuing
if [ -d "/vagrant" ]; then
  echo -e "[${red}ERROR${coloroff}] you need to be outside a vagrant virtual machine to run this script."
  echo -e "Please run ${yellow}logout${coloroff} from the shell to do so."
  exit 1;
fi

# Make sure we're in the root of a vagrant project directory
if [ ! -f Vagrantfile.sample ]; then
  echo -e "${red}Error${coloroff}: you need to be in the root directory of a vagrant project to run this script."
  echo -e "Please run ${yellow}cd /your/vagrant/project${coloroff} from the shell to go there."
  exit 1;
fi

print_message "Setting up environment..."
print_ok

# Check the script directory for an existing Vagrantfile (presumes that the presence of one means it is configured)
print_message "Checking for existing Vagrantfile..."
if [ -f ${script_dir}/../Vagrantfile ]; then # Vagrantfile already exists
  print_warning
  echo -e -n "Vagrantfile already exists. Replace it? [yes|no] (default: no): "
  read replace_vf
  if [[ $replace_vf = "yes" || $replace_vf = "Yes" || $replace_vf = "y" || $replace_vf = "Y" ]]; then
    replace_vf="yes"
  else
    replace_vf="no"
  fi
else
  print_ok
  replace_vf="makenew"
fi

# If we're replacing or making a new Vagrantfile, let's get started!
if [[ $replace_vf = "yes" || $replace_vf = "makenew" ]]; then

  # Get the Base Box that we'll be installing (Which version of Ubuntu)
  base_box_replace="### Uncomment a line above to choose the base box. ###"
  if [[ -z "$base_box" ]]; then
    base_box_default="ubuntu/xenial64"
    base_boxes=(`grep "config.vm.box =" $script_dir/../Vagrantfile.sample | grep -o \".*\" | sed "s|\"||g"`)
    for (( i=0; i<${#base_boxes[@]}; i++ ))
    do
      if [ ${base_boxes[$i]} = $base_box_default ]; then
        label_default=" ${blue}(default)${coloroff}"
      else
        label_default=""
      fi
      echo -e " [${green}$(( i+1 ))${coloroff}] ${base_boxes[$i]}${label_default}"
    done
    echo -n "Choose your base box, or enter your own: "
    read CHOICE
    if [ ${#CHOICE} -lt 1 ]; then # no answer, so choose default
      base_box=$base_box_default
    elif [ ${#CHOICE} -lt 3 ]; then # short answer (assume a number), so pick the choice with that number
      eval CHOSEN_IP=\${base_boxes[$(( CHOICE-1 ))]}
      base_box=${CHOSEN_IP:-$base_box_default}
    else # long answer, so assume it's an answer itself
      base_box=${CHOICE:-$base_box_default}
    fi
  fi
  echo -e "Base box: [${green}${base_box}${coloroff}]\n"

  # Set the IP address that the Vagrant machine will be accessible at.
  # NOTE:  Need to set this in the lamp_setup.sh script from here.
  ip_address_replace="### Uncomment a line above to choose an IP address for this VM. ###"
  if [[ -z "$ip_address" ]]; then
    ip_address_default="192.168.10.10"
    ip_addresses=(`grep -n 'config.vm.network "private_network"' Vagrantfile.sample | grep -o ': \".*\"' | sed "s|: ||g" | sed "s|\"||g"`)
    for (( i=0; i<${#ip_addresses[@]}; i++ ))
    do
      if [ ${ip_addresses[$i]} = $ip_address_default ]; then
        label_default=" ${blue}(default)${coloroff}"
      else
        label_default=""
      fi
      echo -e " [${green}$(( i+1 ))${coloroff}] ${ip_addresses[$i]}${label_default}"
    done
    echo -n "Choose your ip address, or enter your own: "
    read CHOICE
    if [ ${#CHOICE} -lt 1 ]; then # no answer, so choose default
      ip_address=$ip_address_default
    elif [ ${#CHOICE} -lt 3 ]; then # short answer (assume a number), so pick the choice with that number
      eval CHOSEN_IP=\${ip_addresses[$(( CHOICE-1 ))]}
      ip_address=${CHOSEN_IP:-$ip_address_default}
    else # long answer, so assume it's an answer itself
      ip_address=${CHOICE:-$ip_address_default}
    fi
  fi
  echo -e "IP address: [${green}${ip_address}${coloroff}]\n"

  # If desired, set the machine to utilize a bridged network interface.
  bridged_network_replace="### Uncomment the line above to use a bridged network (i.e., this VM will be accessible on your local network). ###"
  if [[ -z "$bridged_network" ]]; then
    bridged_network_default="# config.vm.network :public_network"
    echo -e "A bridged network will allow your virtual machine to be accessible to other machines on the local network."
    echo -e -n "Use a bridged network? [yes|no] (default: no): "
    read bridged_network
    if [[ $bridged_network = "yes" || $bridged_network = "Yes" || $bridged_network = "y" || $bridged_network = "Y" ]]; then
      bridged_network="config.vm.network :public_network"
    else
      bridged_network=$bridged_network_default
    fi
  fi
  if [[ $bridged_network = "config.vm.network :public_network" ]]; then
    is_bridged="yes"
  else
    is_bridged="no"
  fi
  echo -e "Bridged network: [${green}${is_bridged}${coloroff}]\n"


  # Set the amount of memory allocated to the VM.
  memory_size_replace="### Uncomment a line above to set the vm memory size (in MiB) ###"
  if [[ -z "$memory_size" ]]; then
    memory_size_default="1024"
    memory_sizes=(`grep -n "vb.customize \[\"modifyvm\", :id, \"--memory\"" Vagrantfile.sample | grep -o \"[0-9]*\" | sed "s|\"||g"`)
    for (( i=0; i<${#memory_sizes[@]}; i++ ))
    do
      if [ ${memory_sizes[$i]} = $memory_size_default ]; then
        label_default=" ${blue}(default)${coloroff}"
      else
        label_default=""
      fi
      echo -e " [${green}$(( i+1 ))${coloroff}] ${memory_sizes[$i]}${label_default}"
    done
    echo -n "Choose your virtual machine memory size, or enter your own: "
    read CHOICE
    if [ ${#CHOICE} -lt 1 ]; then # no answer, so choose default
      memory_size=$memory_size_default
    elif [ ${#CHOICE} -lt 3 ]; then # short answer (assume a number), so pick the choice with that number
      eval CHOSEN_IP=\${memory_sizes[$(( CHOICE-1 ))]}
      memory_size=${CHOSEN_IP:-$memory_size_default}
    else # long answer, so assume it's an answer itself
      memory_size=${CHOICE:-$memory_size_default}
    fi
  fi
  echo -e "VM memory size: [${green}${memory_size}${coloroff}]\n"

  # Take the above list of settings and create a Vagrantfile from the provided Vagrantfile.sample
  print_message "Building default Vagrantfile..."
  print_ok
  if [[ $replace_vf = "yes" || $replace_vf = "makenew" ]]; then
    if [[ $replace_vf != "makenew" ]]; then
      print_message "Overwriting Vagrantfile with newer version..."
    else
      print_message "Writing new Vagrantfile..."
    fi
    cat $script_dir/../Vagrantfile.sample | \
    sed -e "s|${base_box_replace}|config.vm.box = \"${base_box}\"|g" | \
    sed -e "s|${ip_address_replace}|config.vm.network \"private_network\", ip: \"${ip_address}\"|g" | \
    sed -e "s|${bridged_network_replace}|${bridged_network}|g" | \
    sed -e "s|${memory_size_replace}|vb.customize [\"modifyvm\", :id, \"--memory\", \"${memory_size}\"]|g" > \
    $script_dir/../Vagrantfile
    reload_vm="yes"
  else
    print_message "Keeping old Vagrantfile and continuing..."
  fi
  print_ok
fi

# Choose whether to install the EXIM mail server.
print_message "Determining whether to install a mail server (exim)..."
print_ok
exim_replace="install_exim=false"
if [[ -z "$exim" ]]; then
  exim_default="no"
  exims=(yes no)
  for (( i=0; i<${#exims[@]}; i++ ))
  do
    if [ ${exims[$i]} = $exim_default ]; then
      label_default=" ${blue}(default)${coloroff}"
    else
      label_default=""
    fi
    echo -e " [${green}$(( i+1 ))${coloroff}] ${exims[$i]}${label_default}"
  done
  echo -n "Run a mail server (exim) in your virtual machine? "
  read CHOICE
  if [ ${#CHOICE} -lt 1 ]; then # no answer, so choose default
    exim=$exim_default
  elif [ ${#CHOICE} -lt 3 ]; then # short answer (assume a number), so pick the choice with that number
    eval CHOSEN=\${exims[$(( CHOICE-1 ))]}
    exim=${CHOSEN:-$exim_default}
  else # long answer, so assume it's an answer itself
    exim=${CHOICE:-$exim_default}
  fi
fi
if [[ $exim = "yes" || $exim = "Yes" || $exim = "y" || $exim = "Y" ]]; then
  exim="yes"
else
  exim="no"
fi
# Set install_exim=true in ubuntu_setup.sh
if [[ $exim = "yes" ]]; then
  sed -i "" "s|${exim_replace}|install_exim=true|g" $script_dir/lib/ubuntu_setup.sh
  reload_vm="yes"
fi
echo -e "Mail server (exim) installed: [${green}${exim}${coloroff}]\n"


# Update the base box
# This will include launching the ./scripts/ubuntu_setup.sh script for configuration of the machine.
print_message "Updating the vagrant base box..."
print_ok
cd $script_dir/../ && vagrant box update

# Start up the Vagrant machine for the first time
# This will include launching the ./scripts/ubuntu_setup.sh script for configuration of the machine.
print_message "Initializing the virtual machine..."
print_ok
cd $script_dir/../ && vagrant up

# If we've set our VM to reload during any part of the process, do so after our boot is finished.
if [ "$reload_vm" = "yes" ]; then
  print_message "Reloading the virtual machine..."
  print_ok
  cd $script_dir/../ && vagrant reload
fi

echo -e "\n${green}All done!${coloroff} See README.md for additional installation steps."
