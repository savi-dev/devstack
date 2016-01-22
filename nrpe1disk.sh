#$1 is the nagios3 server's IP
#$2 is the first hard disk to monitor

# Check whether we have sufficient privileges
. ~/vars.env

NAGIOS_SERVER=$HEAD_IP
sudo apt-get install openssl nagios-nrpe-server nagios-plugins nagios-plugins-basic nagios-plugins-standard -y

sudo sed -i "s/allowed_hosts=127.0.0.1/allowed_hosts=127.0.0.1,172.17.0.0/24,$NAGIOS_SERVER/g" /etc/nagios/nrpe.cfg
sudo sed -i "s/dont_blame_nrpe=0/dont_blame_nrpe=1/g" /etc/nagios/nrpe.cfg
sudo sed -i "s/command\[check/\#command[check/g" /etc/nagios/nrpe.cfg

sudo sh -c "echo command[check_users]=/usr/lib/nagios/plugins/check_users -w 55 -c 70 >> /etc/nagios/nrpe.cfg"

sudo sh -c "echo command[check_load]=/usr/lib/nagios/plugins/check_load -w 15,10,5 -c 30,25,20 >> /etc/nagios/nrpe.cfg"
sudo sh -c "echo command[check_zombie_procs]=/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z >> /etc/nagios/nrpe.cfg"
sudo sh -c "echo command[check_total_procs]=/usr/lib/nagios/plugins/check_procs -w 500 -c 650 >> /etc/nagios/nrpe.cfg"

DISKS=`sudo df -h | grep "/dev/" | awk '{print $1}'`
echo "disks found:"
count=0
for disk in $DISKS; do
    echo "performing for disk: $disk"
    sudo sh -c "echo command[check_disk$count]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p $disk  >> /etc/nagios/nrpe.cfg"
    sudo sh -c "echo define command{ >> /etc/nagios-plugins/config/disk.cfg"
    sudo sh -c "echo command_name    check_disk$count  >> /etc/nagios-plugins/config/disk.cfg"
    sudo sh -c "echo command_line    /usr/lib/nagios/plugins/check_disk -w \'\$\ARG1\$\' -c \'\$\ARG2\$\' -e -p \'\$\ARG3\$\'  >> /etc/nagios-plugins/config/disk.cfg"
    sudo sh -c "echo }  >> /etc/nagios-plugins/config/disk.cfg"
    count=$((count+1))
done

sudo /etc/init.d/nagios-nrpe-server restart

exit 0

cd /etc/nagios/

echo "
##########################################################################
# Sample NRPE Config File 
# Written by: Ethan Galstad (nagios@nagios.org)
# 
# Last Modified: 11-23-2007
#
# NOTES:
# This is a sample configuration file for the NRPE daemon.  It needs to be
# located on the remote host that is running the NRPE daemon, not the host
# from which the check_nrpe client is being executed.
#############################################################################


# LOG FACILITY
# The syslog facility that should be used for logging purposes.

log_facility=daemon



# PID FILE
# The name of the file in which the NRPE daemon should write it's process ID
# number.  The file is only written if the NRPE daemon is started by the root
# user and is running in standalone mode.

pid_file=/var/run/nagios/nrpe.pid



# PORT NUMBER
# Port number we should wait for connections on.
# NOTE: This must be a non-priviledged port (i.e. > 1024).
# NOTE: This option is ignored if NRPE is running under either inetd or xinetd

server_port=5666



# SERVER ADDRESS
# Address that nrpe should bind to in case there are more than one interface
# and you do not want nrpe to bind on all interfaces.
# NOTE: This option is ignored if NRPE is running under either inetd or xinetd

#server_address=127.0.0.1



# NRPE USER
# This determines the effective user that the NRPE daemon should run as.  
# You can either supply a username or a UID.
# 
# NOTE: This option is ignored if NRPE is running under either inetd or xinetd

nrpe_user=nagios



# NRPE GROUP
# This determines the effective group that the NRPE daemon should run as.  
# You can either supply a group name or a GID.
# 
# NOTE: This option is ignored if NRPE is running under either inetd or xinetd

nrpe_group=nagios



# ALLOWED HOST ADDRESSES
# This is an optional comma-delimited list of IP address or hostnames 
# that are allowed to talk to the NRPE daemon.
#
# Note: The daemon only does rudimentary checking of the client's IP
# address.  I would highly recommend adding entries in your /etc/hosts.allow
# file to allow only the specified host to connect to the port
# you are running this daemon on.
#
# NOTE: This option is ignored if NRPE is running under either inetd or xinetd

allowed_hosts=127.0.0.1,$1 


# COMMAND ARGUMENT PROCESSING
# This option determines whether or not the NRPE daemon will allow clients
# to specify arguments to commands that are executed.  This option only works
# if the daemon was configured with the --enable-command-args configure script
# option.  
#
# *** ENABLING THIS OPTION IS A SECURITY RISK! *** 
# Read the SECURITY file for information on some of the security implications
# of enabling this variable.
#
# Values: 0=do not allow arguments, 1=allow command arguments

dont_blame_nrpe=1



# COMMAND PREFIX
# This option allows you to prefix all commands with a user-defined string.
# A space is automatically added between the specified prefix string and the
# command line from the command definition.
#
# *** THIS EXAMPLE MAY POSE A POTENTIAL SECURITY RISK, SO USE WITH CAUTION! ***
# Usage scenario: 
# Execute restricted commmands using sudo.  For this to work, you need to add
# the nagios user to your /etc/sudoers.  An example entry for alllowing 
# execution of the plugins from might be:
#
# nagios          ALL=(ALL) NOPASSWD: /usr/lib/nagios/plugins/
#
# This lets the nagios user run all commands in that directory (and only them)
# without asking for a password.  If you do this, make sure you don't give
# random users write access to that directory or its contents!

# command_prefix=/usr/bin/sudo 



# DEBUGGING OPTION
# This option determines whether or not debugging messages are logged to the
# syslog facility.
# Values: 0=debugging off, 1=debugging on

debug=0



# COMMAND TIMEOUT
# This specifies the maximum number of seconds that the NRPE daemon will
# allow plugins to finish executing before killing them off.

command_timeout=60



# CONNECTION TIMEOUT
# This specifies the maximum number of seconds that the NRPE daemon will
# wait for a connection to be established before exiting. This is sometimes
# seen where a network problem stops the SSL being established even though
# all network sessions are connected. This causes the nrpe daemons to
# accumulate, eating system resources. Do not set this too low.

connection_timeout=300



# WEEK RANDOM SEED OPTION
# This directive allows you to use SSL even if your system does not have
# a /dev/random or /dev/urandom (on purpose or because the necessary patches
# were not applied). The random number generator will be seeded from a file
# which is either a file pointed to by the environment valiable $RANDFILE
# or $HOME/.rnd. If neither exists, the pseudo random number generator will
# be initialized and a warning will be issued.
# Values: 0=only seed from /dev/[u]random, 1=also seed from weak randomness

#allow_weak_random_seed=1



# INCLUDE CONFIG FILE
# This directive allows you to include definitions from an external config file.

#include=<somefile.cfg>



# INCLUDE CONFIG DIRECTORY
# This directive allows you to include definitions from config files (with a
# .cfg extension) in one or more directories (with recursion).

#include_dir=<somedirectory>
#include_dir=<someotherdirectory>



# COMMAND DEFINITIONS
# Command definitions that this daemon will run.  Definitions
# are in the following format:
#
# command[<command_name>]=<command_line>
#
# When the daemon receives a request to return the results of <command_name>
# it will execute the command specified by the <command_line> argument.
#
# Unlike Nagios, the command line cannot contain macros - it must be
# typed exactly as it should be executed.
#
# Note: Any plugins that are used in the command lines must reside
# on the machine that this daemon is running on!  The examples below
# assume that you have plugins installed in a /usr/local/nagios/libexec
# directory.  Also note that you will have to modify the definitions below
# to match the argument format the plugins expect.  Remember, these are
# examples only!


# The following examples use hardcoded command arguments...

command[check_users]=/usr/lib/nagios/plugins/check_users -w 55 -c 70
command[check_load]=/usr/lib/nagios/plugins/check_load -w 15,10,5 -c 30,25,20
command[check_disk]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p $2
#command[check_disk1]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p $3
command[check_zombie_procs]=/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z
command[check_total_procs]=/usr/lib/nagios/plugins/check_procs -w 500 -c 650 


#
# local configuration:
#   if you'd prefer, you can instead place directives here
include=/etc/nagios/nrpe_local.cfg

# 
# you can place your config snipplets into nrpe.d/
# only snipplets ending in .cfg will get included
include_dir=/etc/nagios/nrpe.d/" > nrpe.cfg


sudo /etc/init.d/nagios-nrpe-server restart


