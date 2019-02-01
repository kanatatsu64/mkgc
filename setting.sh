###########################################
#	   CUSTOM CONFIGURATIONS
###########################################

# local_dns must be compatible with nsupdate command.
local_dns='10.146.0.2'
local_vpn_dns='172.16.0.2'
local_net_prefix='172.16'
# the interface whoes ip address is used for DNS
domain_iface='eth0'

# vpn routing
#
# vpn_iface -> vpn_iface_gw -> vpn_server -> ==vpn_tunnel== -> vpn_client
# |--------------------------------| |------------------------------|
#			 VPC subnet						vpn_subnet
#			172.16.0.0/24					  10.8.0.0/20
#
vpn_iface='eth1'
vpn_iface_gw='172.16.0.1'
vpn_subnet='10.8.0.0/20'

#
# To add another realm, modify /etc/krb5.conf configuration below. 
#
default_realm='MAIN.GC'
kdc_fqdn='krb-master.main.gc'
kadm_fqdn='krb-master.main.gc'

krb_admin_pw='yotuba822#admin'

install_libs='make less gcc git tree'

# the user to login with Kerberos authentication over SSH.
new_user='kanatatsu'
user_pw='yotuba822'
salt='fdospgwe'

# create a lock
creation_config_lock=/etc/lock/creation_config_lock
if [ -e $creation_config_lock ]; then
	# update dns server
	FQDN=$(hostname -f)
	nsupdate <<-EOF
		prereq yxrrset $FQDN IN A
		update delete $FQDN IN A
		send
		EOF
	TTL=86400 # 1 day
	IP_ADDR=$(ip a | grep "inet " | grep "$local_net_prefix" | head -1 | cut -d/ -f2 | awk '{ print $3 }')
	nsupdate <<-EOF
		update add $FQDN $TTL IN A $IP_ADDR
		send
		EOF
	exit 0
fi

###########################################
#	   NETWORK CONFIGURATIONS
###########################################

mkdir -p /etc/lock
touch $creation_config_lock

# create finalize code file
finalize_file=/usr/local/sbin/gc_finalize
touch $finalize_file
chmod u+x $finalize_file

# add a new route table
sudo sh -c 'echo "100	vpn" >> /etc/iproute2/rt_tables' # reserve a new route table

# add static routes via dhcp hook
cat > /etc/dhcp/dhclient-exit-hooks.d/vpn-route <<EOF
if [ "\$reason" = "BOUND" ] || [ "\$reason" = "REBOOT" ]; then
	if [ "\$interface" = "$vpn_iface" ]; then
		ip rule add to $vpn_subnet priority 100 table vpn # higher priority than main (default)
		ip route add $vpn_subnet via $vpn_iface_gw dev $vpn_iface table vpn
	fi
fi
exit 0
EOF

# overwrite dhcp configuration
cat >> /etc/dhcp/dhclient.conf <<EOF
prepend domain-name-servers $local_dns;
EOF

#cat >> /etc/dhcp/dhclient.conf <<EOF
#supersede domain-name "<domain>";
#supersede host-name "<hostname>";
#EOF

# set hostname
#echo <hostname> > /etc/hostname
#hostname -F /etc/hostname

# configure dynamic dns update
apt install -y dnsutils

cat > /etc/dhcp/dhclient-exit-hooks.d/vpn-update <<EOF
if [ "\$interface" = "$vpn_iface" ]; then
	echo "\$new_ip_address" > /var/${vpn_iface}_ip
fi
exit 0
EOF

cat >> $finalize_file <<'EOF'
FQDN=$(hostname -f)
nsupdate <<-EOF
	prereq yxrrset $FQDN IN A
	update delete $FQDN
	send
	EOF
EOF

# configure networking
cat > /etc/network/interfaces <<EOF
source-directory /etc/network/interfaces.d

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet dhcp
EOF

# apply network configure changes
systemctl restart networking

# update dns server
FQDN=$(hostname -f)
nsupdate <<-EOF
	prereq yxrrset $FQDN IN A
	update delete $FQDN IN A
	send
	EOF
TTL=86400 # 1 day
IP_ADDR=$(ip a | grep "inet " | grep "$local_net_prefix" | head -1 | cut -d/ -f2 | awk '{ print $3 }')
nsupdate <<-EOF
	update add $FQDN $TTL IN A $IP_ADDR
	send
	EOF

###########################################
#			SYSTEM CONFIGURATIONS
###########################################

# install Kerberos client tools
export DEBIAN_FRONTEND=noninteractive # prevent interactive installation
apt -y install krb5-user
cat > /etc/krb5.conf <<EOF
[libdefaults]
		default_realm = $default_realm
		kdc_timesync = 1
		ccache_type = 4
		forwardable = true
		proxiable = true
[realms]
		$default_realm = {
				kdc = $kdc_fqdn
				admin_server = $kadm_fqdn
		}
EOF

# create a new Kereros principal for the vm
kpw=$krb_admin_pw # used for password protection
FQDN=$(hostname -f)
kadmin -w $kpw -p gc/admin -q "addprinc -nokey host/$FQDN"
kadmin -w $kpw -p gc/admin -q "ktadd host/$FQDN"
kpw=''

cat >> $finalize_file <<EOF
kadmin -p gc/admin -q "delprinc -force host/$FQDN"
EOF

# enable GSSAPI authentication
sed -i \
	-e 's/^PasswordAuthentication/#PasswordAuthentication/g' \
	-e 's/^GSSAPIAuthentication/#GSSAPIAuthentication/g' \
	/etc/ssh/sshd_config
echo "GSSAPIAuthentication yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# appy sshd configuration chages
systemctl restart ssh

# set the default editor
echo "export EDITOR=vim" >> /etc/bash.bashrc
export EDITOR=vim

# set the prompt schema
echo 'export PS1="\[\e[01;32m\]\u@\h\[\e[0m\]:\[\e[01;34m\]\w\[\e[00m\]\$ "' >> /etc/bash.bashrc

# set grep coloring
echo 'alias grep="grep --color=auto"' >> /etc/bash.bashrc

# install necessary softwares
apt install -y $install_libs

# add user kanatatsu
git clone https://github.com/kanatatsu64/encpasswd.git /tmp/encpasswd
cd /tmp/encpasswd
make
cd
rm -rf /tmp/encpasswd
mkdir /home/$new_user
useradd -G sudo -s /bin/bash -p $(encpasswd "$user_pw" "$salt")  $new_user
chown $new_user.$new_user /home/$new_user

# configure ssh setting
mkdir /home/$new_user/.ssh
cat > /home/$new_user/.ssh/config <<EOF
Host gcvdi
	HostName desktop.main.gc
	User kanatatsu
	GSSAPIAuthentication yes
EOF
