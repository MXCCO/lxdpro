apt-get install openssh-server -y
sudo sed -i "s/^#\?Port.*/Port $1/g" /etc/ssh/sshd_config;
sudo sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config;
sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config;
service sshd restart
systemctl enable sshd.service>/dev/null 2>&1
passwd=$2
echo root:${passwd}|chpasswd
