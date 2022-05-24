apt-get install openssh-server -y
echo "Port 22">>/etc/ssh/sshd_config
echo "PermitRootLogin yes">>/etc/ssh/sshd_config
echo "PasswordAuthentication yes">>/etc/ssh/sshd_config
service sshd restart
systemctl enable sshd.service
passwd=$1
echo root:${passwd}|chpasswd