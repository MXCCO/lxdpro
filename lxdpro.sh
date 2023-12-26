#!/usr/bin/env bash


Green="\033[32m"
yellow="\033[33m"
Font="\033[0m"
Red="\033[31m"
Cyan='\033[0;36m'
Pe="\033[0;35m"

# blue=$(tput setaf 4)
# normal=$(tput sgr0)


lxd_install_mod=("wget" "curl" "sudo" "jq" "ipcalc")
for lxd_install_mod in "${lxd_install_mod[@]}"
do
    command -V $lxd_install_mod >/dev/null 2>&1
    if [ $? -ne 0 ];
    then
    apt -y install $lxd_install_mod
    fi
done




#报错检测
snap_detect(){
    lxd_lxc_detect=$(lxc list -f csv)
    if [ $? -ne 0 ]
    then
    echo "lxd已安装但是无法使用，请尝试重启"
    exit 0
    elif [[ "$lxd_lxc_detect" =~ "snap-update-ns failed with code1".* ]]
    then
    systemctl restart apparmor
    snap restart lxd
    else
    echo "环境没问题"
    exit 0
    fi
    
}
# 安装snap
snap_install(){
    lxd_snap=`dpkg -l |awk '/^[hi]i/{print $2}' | grep -ow snap`
    lxd_snapd=`dpkg -l |awk '/^[hi]i/{print $2}' | grep -ow snapd`
    if [[ "$lxd_snap" =~ ^snap.* ]]&&[[ "$lxd_snapd" =~ ^snapd.* ]]
    then
    echo "snap已安装"
    lxd_install

    else
    echo "开始安装snap"
    apt -y install sudo 
    sudo apt -y update
    sudo apt -y install snap
    sudo apt -y install snapd
    lxd_install
    fi
}

lxc_list_ipv6_1()
{
ipv6_network_name=$(ls /sys/class/net/ | grep -v "`ls /sys/devices/virtual/net/`")
ipv6_name=$(curl -s -6 ip.sb -m 2 2> /dev/null )
# ifconfig ${ipv6_network_name} | awk '/inet6/{print $2}'
ip_network_gam=$(ip -6 addr show ${ipv6_network_name} | grep -E "${ipv6_name}/64|${ipv6_name}/80|${ipv6_name}/96|${ipv6_name}/112" | grep global | awk '{print $2}' 2> /dev/null)

if [ -n "$ip_network_gam" ];
    then
        read -p "检测到你有一个公网ipv6的网段可以开ipv6实例,是否开启？(如果服务商上游禁止路由那ipv6可能无法使用,默认关闭) [Y/n] :" ipv6_lxc
        [ -z "${ipv6_lxc}" ] && ipv6_lxc="n"

fi
}



lxc_list_ipv6_2()
{
if [[ $ipv6_lxc == [Yy] ]]; then
    if ! grep "net.ipv6.conf.${ipv6_network_name}.proxy_ndp = 1" /etc/sysctl.conf  >/dev/null
    then
        echo "net.ipv6.conf.${ipv6_network_name}.proxy_ndp = 1">>/etc/sysctl.conf
        sysctl -p
    fi
    if ! grep "net.ipv6.conf.all.forwarding = 1" /etc/sysctl.conf  >/dev/null
    then
        echo "net.ipv6.conf.all.forwarding = 1">>/etc/sysctl.conf
        sysctl -p
    fi
    if ! grep "net.ipv6.conf.all.proxy_ndp=1" /etc/sysctl.conf  >/dev/null
    then
        echo "net.ipv6.conf.all.proxy_ndp=1">>/etc/sysctl.conf
        sysctl -p
    fi
        ipv6_lala=$(ipcalc ${ip_network_gam} | grep "Prefix:" | awk '{print $2}')
        randbits=$(od -An -N2 -t x1 /dev/urandom | tr -d ' ')
        lxc_ipv6="${ipv6_lala%/*}${randbits}"
        lxc config device add $lxc_name eth1 nic nictype=routed parent=${ipv6_network_name} ipv6.address=${lxc_ipv6}
fi
}





# 安装LXD
lxd_install(){
    test -s /etc/sysctl.d/99-lxd.conf || cat << EOF >/etc/sysctl.d/99-lxd.conf
fs.aio-max-nr = 524288
fs.inotify.max_queued_events = 1048576
fs.inotify.max_user_instances = 1048576
fs.inotify.max_user_watches = 1048576
kernel.dmesg_restrict = 1
kernel.keys.maxbytes = 2000000
kernel.keys.maxkeys = 2000
net.core.bpf_jit_limit = 3000000000
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv6.neigh.default.gc_thresh3 = 8192
vm.max_map_count = 262144
EOF
    snap_core22=`snap list core22`
    snap_lxd=`snap list lxd`
    if [[ "$snap_core22" =~ core22.* ]]&&[[ "$snap_lxd" =~ lxd.* ]]
    then
    echo "lxd已安装"
    snap_detect
    exit 0
    else
    echo "开始安装LXD"
    sudo snap install core
    sudo snap install lxd
    snap set lxd lxcfs.pidfd=true
    snap set lxd lxcfs.loadavg=true
    snap set lxd lxcfs.cfs=true
    echo "LXD安装完成"        
    echo "需要重启才能使用后续脚本"
    echo "重启后请再次执行步骤1确认问题"
    stty erase '^H' && read -p "需要重启VPS后，才能开启LXD，是否现在重启 ? [Y/n] :" yn
    [ -z "${yn}" ] && yn="y"
    if [[ $yn == [Yy] ]]; then
    echo -e " ${Green}[提示]${Font} VPS 重启中..."
    reboot
    fi
    exit 0
    fi
}

#容器名称
lxd_name(){
read -p "输入容器名称(只能英文数字且必须输入):" lxc_name
if [ -z "$lxc_name" ];
    then
    echo "名称不能为空"
    exit 0
fi
}

#网络选择
lxd_network()
{
read -p "输入网卡名称(默认与容器名相同):" network_lxc
read -p "请输入ipv4网关(默认10.10.10.1):" network_ipv4_gateway
read -p "请输入ipv4地址范围(默认10.10.10.1/24):" network_ipv4_address
read -p "请输入ipv6地址范围(如ipv6/64 默认随机):" network_ipv6_address
}

#为空
lxd_default()
{
[ -z "$network_lxc" ] && network_lxc="${lxc_name}"
[ -z "$network_ipv4_gateway" ] && network_ipv4_gateway="10.10.10.1"
[ -z "$network_ipv4_address" ] && network_ipv4_address="10.10.10.1/24"
[ -z "$network_ipv6_address" ] && network_ipv6_address="auto"
[ -z "$lxc_disk" ] && lxc_disk="btrfs"
[ -z "$lxc_disk_size" ] && lxc_disk_size="2048"
[ -z "$lxc_cpu" ] && lxc_cpu="1"
[ -z "$lxc_ram" ] && lxc_ram="1024"
[ -z "$lxc_cpu_performance" ] && lxc_cpu_performance="100"
[ -z "$lxc_rate" ] && lxc_rate="1000"


}
# 创建网卡
lxd_network_create()
{

echo -e "正在创建网卡                 ${yellow}[warnning]${Font}"
echo -n `lxc network create $network_lxc>/dev/null 2>&1`
cat <<EOF | lxc network edit $network_lxc

{
"config": {
"ipv4.address": "${network_ipv4_address}",
"ipv4.dhcp": "true",
"ipv4.dhcp.gateway": "${network_ipv4_gateway}",
"ipv4.firewall": "true",
"ipv4.nat": "true",
"ipv4.routing": "true",
"ipv6.address": "${network_ipv6_address}",
"ipv6.dhcp": "true",
"ipv6.dhcp.stateful": "true",
"ipv6.firewall": "false",
"ipv6.nat": "true",
"ipv6.routing": "true"
},
"description": "",
"name": "lxcbr",
"type": "bridge",
"used_by": null,
"managed": true,
"status": "Created",
"locations": [
"none"
    ]}
EOF

echo -e "网卡创建完成                 ${Green}[success]${Font}"
}





#物理卷选择界面
lxd_disk(){
read -p "请输入磁盘类型(可选btrfs,lvm,zfs 默认btrfs):" lxc_disk
read -p "请输入纯数字磁盘空间大小(默认2048,单位MB):" lxc_disk_size
}




#开始创建磁盘
lxd_disk_cerat()
{
echo -e "开始创建磁盘                 ${yellow}[warnning]${Font}"
echo -n `lxc storage create ${lxc_name} ${lxc_disk} size=${lxc_disk_size}MB>/dev/null 2>&1`
echo -e "磁盘创建完成                 ${Green}[success]${Font}"
}





#Profiles
lxd_limits()
{
read -p "请输入容器配置的模板名称:" lxc_name_profile
read -p "指定的ipv4地址(必须输入与网关同一网段的ip): " lxc_network_ipv4
read -p "输入指定的ipv6地址(必须输入与ipv6范围同网段的ip): " lxc_network_ipv6
read -p "请输入cpu的核心数限制(默认1核,请输入纯数字):" lxc_cpu
read -p "请输入运行内存限制(请输入纯数字,单位MB):" lxc_ram
read -p "请输入cpu占用百分比限制(请输入纯数字,不限制为100 默认100 单位%):" lxc_cpu_performance
read -p "请输入网速限制(请输入纯数字,默认1000 单位mbps):" lxc_rate

}
lxd_limits_profile()
{
echo -e "开始写入配置模板             ${yellow}[warnning]${Font}"
echo `lxc profile create $lxc_name_profile >/dev/null 2>&1`
cat <<EOF | lxc profile edit ${lxc_name_profile}
{
  "config": {
    "limits.cpu": "${lxc_cpu}",
    "limits.memory": "${lxc_ram}MB",
    "limits.cpu.allowance": "${lxc_cpu_performance}ms/100ms",
    "limits.memory.swap": "false"
  },
  "description": "Default LXD profile",
  "devices": {
    "eth0": {
      "name": "eth0",
      "ipv4.address": "${lxc_network_ipv4}",
      "ipv6.address": "${lxc_network_ipv6}",
      "limits.max": "${lxc_rate}Mbit",
      "network": "${network_lxc}",
      "type": "nic"
    },
    "root": {
      "path": "/",
      "pool": "${lxc_name}",
      "type": "disk"
    }
  },
  "name": "${lxc_name}",
  "used_by": [

  ]
}
EOF
echo -e "写入配置模板完成             ${Green}[success]${Font}"
}

#开始创建容器
lxd_lxc_create()

{
echo -e "开始创建容器                 ${yellow}[warnning]${Font}"
echo `lxc init tuna-images:${lxc_os} ${lxc_name} -p ${lxc_name}`
echo -e "创建容器完成                 ${Green}[success]${Font}"
}






#独立模板创建
alone_lxc_Profiles()
{
clear
read -p "请输入要创建的模板名称: " lxc_name
read -p "请输入关联此模板的网卡: " lxc_name_network
read -p "请输入关联此模板的物理卷: " lxc_name_disk
if [ -z "$lxc_name" -o -z "$lxc_name_network" -o -z "$lxc_name_disk" ];then
        echo "不能为空请重新输入"
        sleep 3s
        alone_lxc_Profiles
fi
lxd_limits
echo -e "开始写入配置模板             ${yellow}[warnning]${Font}"
echo `lxc profile create $lxc_name >/dev/null 2>&1`
cat <<EOF | lxc profile edit ${lxc_name}
{
  "config": {
    "limits.cpu": "${lxc_cpu}",
    "limits.memory": "${lxc_ram}MB",
    "limits.cpu.allowance": "${lxc_cpu_performance}ms/100ms",
    "limits.memory.swap": "false"
  },
  "description": "Default LXD profile",
  "devices": {
    "eth0": {
      "name": "eth0",
      "limits.max": "${lxc_rate}Mbit",
      "network": "${lxc_name_network}",
      "type": "nic"
    },
    "root": {
      "path": "/",
      "pool": "${lxc_name_disk}",
      "type": "disk"
    }
  },
  "name": "${lxc_name}",
  "used_by": [

  ]
}
EOF
echo -e "写入配置模板完成             ${Green}[success]${Font}"
}

#独立网卡创建
alone_lxc_network()
{
clear
read -p "输入网卡名称(默认lxdpro):" network_lxc
read -p "请输入ipv4网关(默认10.10.10.1):" network_ipv4_gateway
read -p "请输入ipv4地址范围(默认10.10.10.1/24):" network_ipv4_address
read -p "请输入ipv6地址范围(如ipv6/64 默认随机):" network_ipv6_address
[ -z "$network_lxc" ] && network_lxc="lxdpro"
[ -z "$network_ipv4_gateway" ] && network_ipv4_gateway="10.10.10.1"
[ -z "$network_ipv4_address" ] && network_ipv4_address="10.10.10.1/24"
[ -z "$network_ipv6_address" ] && network_ipv6_address="auto"
lxd_network_create
}

#独立物理卷创建
alone_lxc_disk()
{
clear
read -p "请输入要创建的物理卷名称: " lxc_name
if [ -z "$lxc_name" ];then
    echo "不能为空请重新输入！！"
    sleep 3s
    alone_lxc_disk
fi
lxd_disk
[ -z "$lxc_disk" ] && lxc_disk="btrfs"
[ -z "$lxc_disk_size" ] && lxc_disk_size="2048"
lxd_disk_cerat
}


#单独创建容器
alone_lxc()
{
clear
read -p "请输入要创建的容器名称：" lxc_name
read -p "输入需要与此容器关联的模板名称：" lxc_Profiles
if [ -z "$lxc_name" -o -z "$lxc_Profiles" ];then
        echo "不能为空请重新输入!"
        sleep 3s
        alone_lxc
fi
echo -e "开始创建容器                 ${yellow}[warnning]${Font}"
echo `lxc init images:debian/bullseye ${lxc_name} -p ${lxc_Profiles}`
echo -e "创建容器完成                 ${Green}[success]${Font}"
}








#创建容器
lxc_user_lxc()
{
echo "开始创建容器"
lxc init tuna-images:${lxc_os} ${lxc_name} -n ${lxc_name} -s ${lxc_name}>/dev/null 2>&1
if [ $? -ne 0 ];then
lxc network delete ${lxc_name}
lxc storage delete ${lxc_name}
echo -e "${Green}创建失败了！请尝试重新创建${Font}"
fi
} 

#创建简单硬盘
lxc_user_storage_create()
{
echo "开始创建物理卷 物理卷名: ${lxc_name}"
lxc storage create ${lxc_name} btrfs size=${lxc_disk}MB >/dev/null 2>&1
}


#创建简单硬盘---kvm
lxc_user_storage_create_kvm()
{
echo "开始创建物理卷 物理卷名: ${lxc_name}"
lxc storage create ${lxc_name} lvm size=${lxc_disk}MB >/dev/null 2>&1
}

#创建简单网卡
lxc_user_network_create()
{
echo "开始创建网卡 网卡名: ${lxc_name}"
lxc network create ${lxc_name} -t bridge>/dev/null 2>&1
}
#CPU核心数限制
lxc_user_cpu()
{
lxc config set ${lxc_name} limits.cpu ${lxc_cpu}
}

#CPU限制
lxc_user_cpu_allowance()
{
lxc config set ${lxc_name} limits.cpu.allowance ${lxc_cpu_allowance}
}
#CPU优先级
lxc_user_cpu_priority()
{
lxc config set ${lxc_name} limits.cpu.priority ${lxc_cpu_priority}
}


#运行内存限制
lxc_user_memory()
{
lxc config set ${lxc_name} limits.memory ${lxc_memory}MB
}
#硬盘限制
lxc_user_disk()
{
lxc config device set ${lxc_name} root size=${lxc_disk}MB
}



#网速限制
lxc_user_network_rate()
{
lxc config device set ${lxc_name} eth0 limits.max ${lxc_rate}Mbit
}

#下载流量
lxc_user_network_ingress()
{
lxc config device set ${lxc_name} eth0 limits.ingress ${lxc_rate}Mbit
}

#上传限制
lxc_user_network_egress()
{
lxc config device set ${lxc_name} eth0 limits.egress ${lxc_rate}Mbit
}

#网速优先级
lxc_user_network_priority()
{
lxc config device set ${lxc_name} eth0 ${network_priority}
}

#硬盘优先级
lxc_user_disk.priority()
{
lxc config device set ${lxc_name} root limits.disk.priority ${disk.priority}
}

#硬盘IO限制
lxc_user_disk_io()
{
lxc config device set ${lxc_name} root limits.max ${lxc_io}iops
}

#CPU软限制
lxc_user_cpu_allowance()
{
lxc config set ${lxc_name} limits.cpu.allowance ${lxc_cpu_allowance}%
}


#查询实例是否存在
lxd_jq_cunzai()
{
jq_lxc_ls=$(curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/instances | jq .metadata | jq -r .[])
if echo "${jq_lxc_ls}" | grep -w "/1.0/instances/${lxc_name}" &>/dev/null;
then
    i=0
else
    echo -e "${Red}未查找到当前实例，请重新输入!${Font}"
    exit 0
fi
} 

#jq实例列表
lxd_jq_ls()
{
clear
jq_list_name=$(curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/instances | jq .metadata | jq -r .[]  | sed 's/\/1.0\/instances\///g')
jq_list_name=(${jq_list_name})
jq_statuscode=([103]=${Green}运行${Font} [102]=${yellow}停止${Font} [112]=${Red}异常${Font})   
i=0
if [ -z "${jq_list_name[${i}]}" ];
then
    i=0
else
    echo "实例列表："
fi
while :
do
    lxc_jq_cpu=$(curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/instances/${jq_list_name[${i}]} | jq .metadata | jq .expanded_config |  jq -r .'["limits.cpu"]')
    lxc_jq_memory=$(curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/instances/${jq_list_name[${i}]} | jq .metadata | jq .expanded_config |  jq -r .'["limits.memory"]')
    lxc_jq_statuscode=$(curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/instances/${jq_list_name[${i}]} | jq .metadata | jq -r .'["status_code"]')
    if [[ $lxc_jq_cpu = "null" ]];
    then
        lxc_jq_cpu="未限制"
    fi
    if [[ $lxc_jq_memory = "null" ]];
    then
        lxc_jq_cpu="未限制"
    fi
    if [ -z "${jq_list_name[${i}]}" ];
    then    
        break
    else
        echo -e "容器名: ${Green}${jq_list_name[${i}]}${Font}   CPU: ${Green}${lxc_jq_cpu}${Font} 核心  内存: ${Green}${lxc_jq_memory}${Font}   状态: ${jq_statuscode[${lxc_jq_statuscode}]}  "
        ((i++))
    fi
    
done

}
#dhclient





#停止容器
lxc_stop()
{
echo -n `lxc stop ${lxc_name} -f>/dev/null 2>&1`
echo -e "容器已停止                   ${Green}[success]${Font}"
}
#删除容器
lxc_delete()
{
echo -e "正在删除容器                 ${yellow}[warnning]${Font}"
echo -n `lxc delete ${lxc_name}>/dev/null 2>&1`
sleep 10s
echo -e "容器已删除                   ${Green}[success]${Font}"
}
#删除模板
lxc_yaf()
{
echo -n `lxc profile delete ${profile_delete}>/dev/null 2>&1`
echo -e "配置模板已删除               ${Green}[success]${Font}"
}
#删除网卡
lxc_delete_network()
{
echo -n `lxc network delete ${network_lxc}>/dev/null 2>&1`
echo -e "网卡已删除                   ${Green}[success]${Font}"
}
#删除磁盘
lxc_delete_storage()
{
echo -n `lxc storage delete ${storage_delete}>/dev/null 2>&1`
echo -e "磁盘已删除                   ${Green}[success]${Font}"
}
#启动容器
lxc_start()
{
echo -e "正在启动容器                 ${yellow}[warnning]${Font}"
echo -n `lxc start ${lxc_name}>/dev/null 2>&1`
echo -e "容器启动成功                 ${Green}[success]${Font}"
}


#一键删除容器
lxd_delete_lxc()
{
lxd_jq_ls
lxd_name
lxd_jq_cunzai
read -p "请输入要删除的容器网卡名称(直接回车键，默认与容器名相同):" network_lxc
read -p "请输入要删除的磁盘名称(直接回车键，默认与容器名相同):" storage_delete
read -p "请输入要删除的模板名称(直接回车键，默认与容器名相同):" profile_delete
[ -z "$network_lxc" ] && network_lxc="${lxc_name}"
[ -z "$storage_delete" ] && storage_delete="${lxc_name}"
[ -z "$profile_delete" ] && profile_delete="${lxc_name}"

}

#进入容器
lxd_exec_lxc()
{
lxd_jq_ls
read -p "请输入你要进去的容器名(exit可退出容器):" lxc_exec
lxc exec ${lxc_exec} /bin/bash
}

#容器列表
lxd_list_lxc()
{
clear
lxc ls -c npc
}

#磁盘列表
lxd_list_disk()
{
clear
lxc storage list
}

#网卡列表
lxd_list_network()
{
clear
lxc network list
}

#详细创建容器






#启动容器
lxd_lxc_start()
{
clear
echo -e "1.启动指定容器"
echo -e "2.启动所有容器"
while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-2]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    1)  lxd_name
        echo -n `lxc start ${lxc_name}>/dev/null 2>&1`
        [[ $? != 0 ]] && echo "容器器正在运行中,无需启动" || echo "容器启动成功"
    ;;
    2)  read -p "是否启动所有(y/n): " judge
        [[ $judge = y ]] && echo `lxc start --all` || exit 0
        echo "成功启动所有容器,如有报错请注意提示个别容器无法启动"
    ;;
esac
}

#停止容器
lxd_lxc_stop()
{
clear
echo -e "1.停止指定容器"
echo -e "2.停止所有容器"
echo -e "3.强制停止指定容器"
echo -e "4.强制停止所有容器"
while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-2]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    1)  lxd_jq_ls
        read -p "请输入容器名: " lxc_name
        echo -n `lxc stop ${lxc_name}>/dev/null 2>&1`
        [[ $? != 0 ]] && echo "容器已经是停止状态" || echo "容器停止成功"
    ;;
    2)  read -p "是否停止所有容器(y/n): " judge
        [[ $judge = y ]] && echo `lxc stop --all` || exit 0
        echo "成功停止所有容器,如有报错请注意提示个别容器无法启动"
    ;;
    3)  lxd_jq_ls
        read -p "请输入容器名: " lxc_name
        echo -n `lxc stop -f ${lxc_name}>/dev/null 2>&1`
        [[ $? != 0 ]] && echo "容器已经是停止状态" || echo "容器停止成功"
    ;;
    4)  read -p "是否强制停止所有容器(y/n): " judge
        [[ $judge = y ]] && echo `lxc stop -f --all` || exit 0
        echo "成功停止所有容器,如有报错请注意提示个别容器无法启动"
    ;;
esac
}



#重启容器
lxd_lxc_restart()
{

clear
echo -e "1.重启指定容器"
echo -e "2.重启所有容器"
echo -e "3.强制重启指定容器"
echo -e "4.强制重启所有容器"
while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-2]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    1)  lxd_jq_ls
        lxd_name
        echo -n `lxc restart ${lxc_name}>/dev/null 2>&1`
        [[ $? != 0 ]] && echo "容器重启失败" || echo "容器重启成功"
    ;;
    2)  read -p "是否停止所有容器(y/n): " judge
        [[ $judge = y ]] && echo `lxc restart --all` || exit 0
        echo "成功停止所有容器,如有报错请注意提示个别容器无法启动"
    ;;
    3)  lxd_name
        echo -n `lxc restart -f ${lxc_name}>/dev/null 2>&1`
        [[ $? != 0 ]] && echo "容器重启失败" || echo "容器重启成功"
    ;;
    4)  read -p "是否强制停止所有容器(y/n): " judge
        [[ $judge = y ]] && echo `lxc restart -f --all` || exit 0
        echo "成功重启所有容器,如有报错请注意提示个别容器无法启动"
    ;;
esac

}






#对容器进行限制
lxc_limit()
{
clear
echo -e "1.限制CPU数量"
echo -e "2.软限制CPU性能"
echo -e "3.硬限制CPU性能"
echo -e "4.运行内存限制"
echo -e "5.限制网速"
echo -e "6.限制硬盘IO"
echo -e "7.设置CPU优先级"
echo -e "8.设置网络优先级"
echo -e "9.设置硬盘优先级"
echo -e "0.返回首页"

while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[0-9]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done



case $choice in
    0)  front_page
    ;;
    1)  read -p "请输入要限制的容器: " lxc_name
        read -p "请输入要限制的CPU内核数: " lxc_cpu
        lxc_user_cpu
    ;;
    2)  read -p "请输入要限制的容器: " lxc_name
        read -p "请输入你要限制CPU的性能百分比(例如50%):" lxc_cpu_allowance
        lxc_user_cpu_allowance
    ;;
    3)  read -p "请输入要限制的容器: " lxc_name
        read -p "请输入你要限制CPU运行时间比(例如25ms/100ms)" lxc_cpu_allowance
        lxc_user_cpu_allowance
    ;;
    4)  read -p "请输入要限制的容器: " lxc_name
        read -p "请输入你要限制的运行内存(单位:MB或者GB,不能有小数点,例如512MB,5GB):" lxc_memory
        lxc config set ${lxc_name} limits.memory ${lxc_memory}
    ;;
    5)  read -p "请输入要限制的容器: " lxc_name
        read -p "请选择要限制的选项(1.上传 2.下载 3.全部): " xuanxiang
        if [[ ${xuanxiang} == 1 ]];then
            read -p "限制多少速度(单位:mbps不需要再填写): " lxc_rate
            lxc_user_network_egress
            exit 0
        fi
        if [[ ${xuanxiang} == 2 ]];then
            read -p "限制多少速度(单位:mbps不需要再填写): " lxc_rate
            lxc_user_network_ingress
            exit 0
        fi
        if [[ ${xuanxiang} == 3 ]];then
            read -p "限制多少速度(单位:mbps不需要再填写): " lxc_rate
            lxc_user_network_rate
            exit 0
        fi
    ;;
    6)  read -p "请输入要限制的容器: " lxc_name
        read -p "输入你要限制的IO(单位iops,无需再输入): "
        lxc_user_disk_io
    ;;
    7)  read -p "请输入要限制的容器: " lxc_name
        read -p "请输入该容器的的CPU优先级(数字0-10之间): " lxc_cpu_priority
        lxc_user_cpu_priority
    ;;
    8)  read -p "请输入要限制的容器: " lxc_name
        read -p "请输入该容器的的网速优先级(数字0-10之间): " network_priority
        lxc_user_network_priority
    ;;
    9)  read -p "请输入要限制的容器: " lxc_name
        read -p "请输入该容器的的硬盘优先级(数字0-10之间): " disk.priority
        lxc_user_disk.priority
    ;;
esac
}




#容器信息
lxd_information()
{
lxc_current=`lxc info ${lxc_name} | grep current | awk '{print $3}'`
lxc_peak=`lxc info ${lxc_name} | grep 'Memory (peak):' | awk '{print $3}'`
lxc_received=`lxc info ${lxc_name} | grep -A 13 eth0 | grep 'Bytes received:' | awk '{print $3}'`
lxc_sent=`lxc info ${lxc_name} | grep -A 13 eth0 | grep 'Bytes sent:' | awk '{print $3}'`
lxc_PID=`lxc info ${lxc_name} | grep PID: | awk '{print $2}'`
lxc_Created=`lxc info ${lxc_name} | grep Created: | awk '{print ($2,$3)}'`
lxc_Status=`lxc info ${lxc_name} | grep Status: | awk '{print $2}'`
lxc_disk=`lxc info ${lxc_name} | grep root: | awk '{print $2}'`
lxc_inet6=`lxc info ${lxc_name} | grep inet6 | awk '{print $2}'`
lxc_inet4=`lxc info ${lxc_name} | grep inet | grep -v inet6 | awk '{print $2}'`
lxc_cpu=`lxc config show ${lxc_name} | grep 'limits.cpu:' | awk '{print $2}' | tr -cd "[0-9]"`
lxc_memory=`lxc config show ${lxc_name} | grep 'limits.memory:' | awk '{print $2}'`
lxc_image_os=`lxc config show ${lxc_name} | grep 'image.description:' | awk '{ $1=""; print $0 }'`
lxc_architecture=`lxc config show ${lxc_name} | grep 'architecture:' | grep -v 'image.architecture:' | awk '{print $2}'`
lxc_architecture_a=`lxc config show ${lxc_name} | grep 'image.architecture:' | awk '{print $2}'`
lxc_profiles=`lxc config show ${lxc_name} | grep -A 1 'profiles:' | grep '-' | awk '{print $2}'`
if [ -z "$lxc_cpu" ];then
    lxc_cpu=`lxc profile show ${lxc_name} | grep 'limits.cpu:' | awk '{print $2}' | tr -cd "[0-9]"`
fi
if [ -z "$lxc_memory" ];then
    lxc_memory=`lxc profile show ${lxc_name} | grep 'limits.memory:' | awk '{print $2}'`
fi
clear
echo -e "${Cyan}容器名: ${Font}${yellow}${lxc_name}${Font}"
echo -e "${Cyan}创建时间: ${Font}${yellow}${lxc_Created}${Font}"
echo -e "${Cyan}进程PID: ${Font}${yellow}${lxc_PID}${Font}"
echo -e "${Cyan}容器状态: ${Font}${yellow}${lxc_Status}${Font}"
echo -e "${Cyan}系统名称: ${Font}${yellow}${lxc_image_os}${Font}"
echo -e "${Cyan}系统架构: ${Font}${yellow}${lxc_architecture} ${lxc_architecture_a}${Font}"
echo -e "${Cyan}所属模板: ${Font}${yellow}${lxc_profiles}${Font}"
echo -e "${Cyan}CPU核数: ${Font}${yellow}${lxc_cpu}${Font}"
echo -e "${Cyan}总内存限制: ${Font}${yellow}${lxc_memory}${Font}"
echo -e "${Cyan}正在使用内存: ${Font}${yellow}${lxc_current}${Font}"
echo -e "${Cyan}巅峰使用内存: ${Font}${yellow}${lxc_peak}${Font}"
echo -e "${Cyan}硬盘使用情况: ${Font}${yellow}${lxc_disk}${Font}"
echo -e "${Cyan}流量传入: ${Font}${yellow}${lxc_received}${Font}"
echo -e "${Cyan}流量传出: ${Font}${yellow}${lxc_sent}${Font}"
echo -e "${Cyan}IPV4地址: ${Font}\n${yellow}${lxc_inet4}${Font}"
echo -e "${Cyan}IPV6地址: ${Font}\n${yellow}${lxc_inet6}${Font}"
}

#echo " 容器名   使用内存        ipv4地址                        ipv6地址"
#echo `lxc ls  -c nm46 | grep ${lxc_name}`

# lxc ls  -c nm46 | grep nl6 | awk '{print $9}'
# lxc ls  -c npmMD46CNs

# ps -ef | grep 3346539

#详细创建容器
lxc_detailed_creation()
{
        lxd_name
        lxd_network
        lxd_disk
        lxd_limits
        lxd_default
        lxd_network_create
        lxd_disk_cerat
        lxd_limits_profile
        lxd_lxc_create
        lxc_start
        lxd_information
}




#快速创建
lxc_system()
{
echo `lxc remote add tuna-images https://mirrors.tuna.tsinghua.edu.cn/lxc-images/ --protocol=simplestreams --public>/dev/null 2>&1`
echo "输入你需要创建的容器镜像"
echo -e "1.Centos7"
echo -e "2.Debian10"
echo -e "3.Debian11"
echo -e "4.Debian12"
echo -e "5.Ubuntu 16.04"
echo -e "6.Ubuntu 18.04"
echo -e "7.Ubuntu 20.04"
echo -e "8.Ubuntu 22.04"
echo -e "9.alpine 3.17"
echo -e "10.Archlinxe"
echo -e "11.OpenWrt 21.02"
echo -e "12.Fedora 38"
echo -e "13.Kali"

while :; do echo
		read -p "请输入数字选择: " choice
		if [ $choice -ge 1 -a $choice -le 13 ]
            then
				break
		else
			echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"   
		fi
done


if [[ ${choice} == 1 ]]; then
           lxc_os="centos/7"
fi
if [[ ${choice} == 2 ]]; then
           lxc_os="debian/10"
fi
if [[ ${choice} == 3 ]]; then
           lxc_os="debian/11"
fi
if [[ ${choice} == 4 ]]; then
           lxc_os="debian/12"
fi
if [[ ${choice} == 5 ]]; then
           lxc_os="ubuntu/16.04"
fi
if [[ ${choice} == 6 ]]; then
           lxc_os="ubuntu/18.04"
fi
if [[ ${choice} == 7 ]]; then
           lxc_os="ubuntu/20.04"
fi
if [[ ${choice} == 8 ]]; then
           lxc_os="ubuntu/22.04"
fi
if [[ ${choice} == 9 ]]; then
           lxc_os="alpine/3.17"
fi
if [[ ${choice} == 10 ]]; then
           lxc_os="archlinux"
fi
if [[ ${choice} == 11 ]]; then
           lxc_os="openwrt/22.03"
fi
if [[ ${choice} == 12 ]]; then
           lxc_os="Fedora/38"
fi
if [[ ${choice} == 13 ]]; then
           lxc_os="Kali"
fi
}


#虚拟机
lxc_system_kvm()
{
echo `lxc remote add tuna-images https://mirrors.tuna.tsinghua.edu.cn/lxc-images/ --protocol=simplestreams --public>/dev/null 2>&1`
echo "输入你需要创建的虚拟机镜像"
echo -e "1.Centos7"
echo -e "2.Debian10"
echo -e "3.Debian11"
echo -e "4.Debian12"
echo -e "5.Ubuntu 16.04"
echo -e "6.Ubuntu 18.04"
echo -e "7.Ubuntu 20.04"
echo -e "8.Ubuntu 22.04"
echo -e "9.alpine 3.17"
echo -e "10.Archlinxe"
echo -e "11.OpenWrt 22.03"
echo -e "12.Fedora 38"
echo -e "13.Kali"

while :; do echo
		read -p "请输入数字选择: " choice
		if [ $choice -ge 1 -a $choice -le 13 ]
            then
				break
		else
			echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"   
		fi
done


if [[ ${choice} == 1 ]]; then
           lxc_os="centos/7/cloud --vm"
fi
if [[ ${choice} == 2 ]]; then
           lxc_os="debian/10/cloud --vm"
fi
if [[ ${choice} == 3 ]]; then
           lxc_os="debian/11/cloud --vm"
fi
if [[ ${choice} == 4 ]]; then
           lxc_os="debian/12/cloud --vm"
fi
if [[ ${choice} == 5 ]]; then
           lxc_os="ubuntu/16.04/cloud --vm"
fi
if [[ ${choice} == 6 ]]; then
           lxc_os="ubuntu/18.04/cloud --vm"
fi
if [[ ${choice} == 7 ]]; then
           lxc_os="ubuntu/20.04/cloud --vm"
fi
if [[ ${choice} == 8 ]]; then
           lxc_os="ubuntu/22.04/cloud --vm"
fi
if [[ ${choice} == 9 ]]; then
           lxc_os="alpine/3.17/cloud --vm"
fi
if [[ ${choice} == 10 ]]; then
           lxc_os="archlinux/cloud --vm"
fi
if [[ ${choice} == 11 ]]; then
           lxc_os="openwrt/22.03 --vm"
fi
if [[ ${choice} == 12 ]]; then
           lxc_os="Fedora/38/cloud --vm"
fi
if [[ ${choice} == 13 ]]; then
           lxc_os="Kali/cloud --vm"
fi
}





#容器创建
lxc_establish()
{
echo -e "${Red}容器名称不能以数字开头！${Font}"
lxd_name
echo -e "${Red}以下内容请输入纯数字！${Font}"
read -p "cpu限制核数: " lxc_cpu
read -p "运行内存限制(默认单位MB): " lxc_memory
read -p "硬盘大小限制(默认单位MB): " lxc_disk
read -p "网速限制(默认单位mbps): " lxc_rate
lxc_list_ipv6_1

lxc_user_storage_create
lxc_user_network_create
lxc_user_lxc
lxc_user_cpu
lxc_user_memory
lxc_user_disk
lxc_user_network_rate
ipAddr=$(lxc network get ${lxc_name} ipv4.address)
lxc_to_ip=${ipAddr%.*}.$((RANDOM%255+1))
lxc config device set ${lxc_name} eth0 ipv4.address=${lxc_to_ip} >/dev/null 2>&1
lxc_list_ipv6_2
lxc_start
lxd_information
# lxc_ipv4=$(lxc info jp5 | grep inet | grep -v inet6 | awk '{print $2}' | grep "/24" | sed 's/\/..//')
test -s /usr/lxdprolist && sed -i '/'${lxc_name}'/d' /usr/lxdprolist && echo "${lxc_name} ${lxc_to_ip}" >/usr/lxdprolist || echo "${lxc_name} ${lxc_to_ip}" >> /usr/lxdprolist
}



#虚拟机创建
lxc_establish_kvm()
{
echo -e "${Red}虚拟机名称不能以数字开头！${Font}"
read -p "请输入虚拟机名称: " lxc_name
echo -e "${Red}以下内容请输入纯数字！${Font}"
read -p "cpu限制核数: " lxc_cpu
read -p "运行内存限制(默认单位MB): " lxc_memory
read -p "硬盘大小限制(默认单位MB): " lxc_disk
read -p "网速限制(默认单位mbps): " lxc_rate
read -p "是否允许更换内核(例如装加速,和一键DD) [Y/n] :" yn
[ -z "${yn}" ] && yn="y"
lxc_user_storage_create_kvm
lxc_user_network_create
lxc_user_lxc
lxc_delete_img=`lxc storage info $lxc_name | grep -A1 'images' | grep '-'  | awk '{print $2}'`
echo `lxc image delete $lxc_delete_img`
lxc_user_cpu
lxc_user_memory
lxc_user_disk
lxc_user_network_rate
if [[ $yn == [Yy] ]]; then
echo `lxc config set $lxc_name security.secureboot=false`
fi
lxc_start
lxd_information
}


#一键开启容器SSH
lxc_root_passwd(){
echo "正在查询容器系统镜像"
lxd_IMGE=("Ubuntu" "Debian" "Centos" "Alpine")
lxc_root_install=$(curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/instances/${lxc_name} | jq .metadata | jq .expanded_config |  jq -r .'["image.os"]')
# lxc_root_install=`lxc config show ${lxc_name} | grep 'image.os:' | awk '{ $1=""; print $0 }'| awk '{gsub(/^\s+|\s+$/, "");print}'| awk '{gsub(/ /,"")}1'`
#lxc_root_install=`lxc file pull ${lxc_name}/etc/os-release - | head -1 | awk -F'"' '{i = 1; while (i <= NF) {if ($i ~/=$/) print $(i+1);i++}}'| cut -d' ' -f1` 

if echo "${lxd_IMGE[@]}" | grep -w "${lxc_root_install}" &>/dev/null;
then
    i=0
else
    echo "当前仅支持Ubuntu Debian Centos Alpine,其他系统请进入容器自行安装"
    exit 0
fi
if [ "${lxc_root_install}" = "${lxd_IMGE[0]}" ];
then
    lxc_aaa="apt -y install"
    lxc_bbb="bash"
    lxc_ccc="systemctl enable sshd.service>/dev/null 2>&1"
    lxc_ddd="apt -y"
fi
if [ "${lxc_root_install}" = "${lxd_IMGE[1]}" ];
then
    lxc_aaa="apt -y install"
    lxc_bbb="bash"
    lxc_ccc="systemctl enable sshd.service>/dev/null 2>&1"
    lxc_ddd="apt -y"
fi
if [ "${lxc_root_install}" = "${lxd_IMGE[2]}" ];
then
    lxc_aaa="yum -y install"
    lxc_bbb="bash"
    lxc_ccc="systemctl enable sshd.service>/dev/null 2>&1"
    lxc_ddd="yum -y"
fi
if [ "${lxc_root_install}" = "${lxd_IMGE[3]}" ];
then
    lxc_aaa="apk add -f"
    lxc_bbb="sh"
    lxc_ccc="apk add openrc --no-cache && rc-update add sshd"
    lxc_ddd="apk -y"
fi
echo "$lxc_aaa"
read -p "SSH端口(默认22): " lxc_ssh_port
read -p "SSH密码(默认随机): " lxc_ssh_passwd
if [ -z "$lxc_ssh_port" ];then
lxc_ssh_port="22"
fi
if [ -z "$lxc_ssh_passwd" ];then
key="0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
num=${#key}
for i in {1..8}
do 
    index=$[RANDOM%num]
    lxc_ssh_passwd=$lxc_ssh_passwd${key:$index:1}
done
fi

cat << EOF >/root/root.sh
#!/usr/bin/env ${lxc_bbb}
sed -i "s/^#\?Port.*/Port ${lxc_ssh_port}/g" /etc/ssh/sshd_config;
sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config;
sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config; 
service sshd restart
${lxc_ccc}
echo root:${lxc_ssh_passwd} | chpasswd root
EOF
lxc file push /root/root.sh ${lxc_name}/root/
lxc exec ${lxc_name} -- ${lxc_ddd} update
lxc exec ${lxc_name} -- ${lxc_aaa} wget
lxc exec ${lxc_name} -- ${lxc_aaa} openssh-server
lxc exec ${lxc_name} -- ${lxc_bbb} root.sh
echo -e "已将${yellow}${lxc_name}${Font}容器SHH端口设置为 ${Red}${lxc_ssh_port}${Font} SSH密码为 ${Red}${lxc_ssh_passwd}${Font}"
}




#root     3354620 3294044  0 13:48 pts/2    00:00:00 grep --color=auto 505423
#进程查找容器
lxd_lxc_pid()
{
read -p "请输入任务进程里面的PID: " lxc_pid

# lxd_pid=`grep -lwm1 ${lxc_pid} /sys/fs/cgroup/pids/lxc.payload.*/*/*/tasks | sed 's/.*lxc\.payload\.//; s/\/.*//'`
lxc_pid=$(ps -ef | grep ${lxc_pid} | grep "1000000"  | awk '{print $3}' 2>/dev/null)
lxc_pid=$(ps -ef | grep "${lxc_pid}" | grep "/sbin/init" |  awk '{print $3}' 2>/dev/null)
lxc_pid=$(ps -ef | grep "${lxc_pid}" | grep "/var/snap/lxd/common/lxd/containers" | awk '{print $11}' 2>/dev/null)    
if  [[ -z "${lxc_pid}" ]]
    then
    echo -e "${Red}请输入正确的pid,或者此pid不是为常驻进程!${Font}"
    echo -e "如果无法查到容器,请使用 ${Red}kill${Font} 和 ${Red}killall${Font} 杀掉PID或者进程名"
    else
    echo -e "这PID进程属于 ${Red}$lxc_pid${Font} 容器"
fi
}





#一键创建容器选择
lxd_Create_selection()
{
echo "1.快速创建容器(网卡名称和物理卷名与容器名相同,物理卷默认为btrfs适合小白)"
echo "2.精确创建容器(单独创建物理卷,单独创建物理卷,单独创建模板写入前两者"
echo "再通过模板创建容器,可以自行选择物理卷类型与网关和ip)"
echo "----------------------------------------------------------------------------"
echo "3.快速创建虚拟机(创建kvm虚拟机,需要母鸡支持虚拟化,物理卷默认为LVM,请注意"
echo -e "${Red}由于独立操作环境对于配置要求相对于容器较高,并且物理卷将直接占用母鸡空间,请合理分配好硬盘空间${Font}"
echo -e "${Red}为了稳定性,硬盘建议给够10GB,不然会出现很多问题!${Font})"
while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-3]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

if [[ ${choice} == 1 ]]; then
        lxc_system
        lxc_establish
        exit 0
fi

if [[ ${choice} == 2 ]]; then
        lxc_system
        lxc_detailed_creation
        exit 0
fi
if [[ ${choice} == 3 ]]; then
        lxc_qume=`egrep -c '(vmx|svm)' /proc/cpuinfo`
        if [ $lxc_qume -eq 0 ]; then
        echo -e " ${Red}你得服务器不支持虚拟化,无法使用！${Font}"
        exit 0
        fi
        dpkg --status qemu >/dev/null 2>&1
        s_dpkg=$?
        if [ $s_dpkg != 0 ]
        then
        apt install qemu
        fi
        lxc_system_kvm
        lxc_establish_kvm
        exit 0
fi
}


#获取网卡名和地址
network_lxd_lxc_forward()
{
ipcalc_install=$(command -V ipcalc)
if [ $? -ne 0 ];
    then
    apt -y install ipcalc
fi
jq_install=$(command -V jq)
if [ $? -ne 0 ];
    then
    apt -y install jq
fi

# hah=$(curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/networks | jq .metadata | jq -r .[] )
# hah=$(echo $hah | sed 's/\/1.0\/networks\///g')
# hah=($hah)

# curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/networks/${i} | jq .metadata | jq '.["used_by"]' | jq -r .[]

lxc_network_forward=$(cat /usr/lxdprolist | grep "${lxc_name}" | awk {'print $2'})
if [ -z "$lxc_network_forward" ];then
i=0
while :
do
    XIAOZI=$(lxc network list -f json | jq .[$i] | jq '.used_by' | jq -r .[] 2>/dev/null)
    # if [ $? -ne 0 ];
    # then
    #     echo "获取网卡失败请重新尝试1"
    #     break
    # fi
    if [ "${XIAOZI}" == "/1.0/instances/${lxc_name}" ];
    then
        lxd_ipt_on=$(lxc network list -f json | jq .[$i] | jq '.config' | jq -r '.["ipv4.address"]' 2>/dev/null)
        lxd_network_name=$(lxc network list -f json | jq .[$i] |  jq -r '.["name"]' 2>/dev/null)
        break 
    else
        ((i++))
    fi
    sleep 2
done
ip_ipcalc=$(ipcalc ${lxd_ipt_on} | grep "HostMin" | awk '{print $2}')
i=1
while :
do  
    lxc_network_forward=$(lxc info ${lxc_name} | grep -w "inet" | awk '{print$2}' | sed -n ''$i'p' |  sed 's/\/..//')
    if [ -z "${lxc_network_forward}" ];
    then
        echo "获取网卡失败请重新尝试2"
        break
    else
        ip_ipcalc_a=$(ipcalc ${lxc_network_forward} | grep "HostMin" | awk '{print $2}')
    fi

    if [ "${ip_ipcalc_a}" = "${ip_ipcalc}" ];
    then
        break 
    else
        ((i++))
    fi
    sleep 2
done
test -s /usr/lxdprolist && sed -i '/'${lxc_name}'/d' /usr/lxdprolist && echo "${lxc_name} ${lxc_network_forward}" >/usr/lxdprolist || echo "${lxc_name} ${lxc_network_forward}" >> /usr/lxdprolist
fi
}



#容器端口转发
lxd_forward_port_create()
{
clear
lxd_name
network_ip=`curl -s -4 ip.sb`
if [[ -z "${network_ip}" ]]
then
    echo "无法判断你的公网ip,请手动输入"
    read -p "请你输入你的公网ip: " network_ip
    [[ -z "${network_ip}" ]] && lxd_forward_port
else
    echo -e "${Red}${network_ip}${Font}"
    read -p "是否为你的公网ip(y,n): " lxc_ip_a
fi
case $lxc_ip_a in 
	[yY])
		
		;;
	[nN])
		read -p "请你输入你的公网ip: " network_ip
		;;
	*)
		echo "请输入正确选项"
        exit 0
esac

if [[ -z "${network_ip}" ]] 
then
    echo "不能为空重新输入"
    sleep 3s
    lxd_forward_port
fi

echo -e "${yellow}端口可选单个端口多个端口,也可以指定一个范围,单端口直接输入端口号就行了${Font}"
echo -e "${yellow}多端口之间用英文逗号相隔如 80,8888;端口范围为起始端口例如 10010-10019 当然也可以组合使用如 1022,10010-10019${Font}"
echo -e "${yellow}母鸡端口和容器端口填法一致,母鸡的第一端口对应容器第一个端口,第二个对应第二个,以此类推${Font}"
read -p "请输入你母鸡的端口: " listen_port
read -p "请输入你的容器的端口: " target_address
network_lxd_lxc_forward

# lxc_network_forward=`lxc config show ${lxc_name} | grep 'network:' | awk '{print $2}'`
# if [ -z "$lxc_network_forward" ];then
#     lxc_network_forward=`lxc profile show ${lxc_name} | grep -A 0 'network:' | awk '{print $2}'`
# fi
# lxc_networok_ip=`lxc info ${lxc_name} | sed -n '/eth0:/,/inet:/p' | grep 'inet' | awk '{print $2}'| sed 's/.\{3\}$//'`
lxc network forward create ${lxd_network_name} ${network_ip}>/dev/null 2>&1
lxc network forward port add ${lxd_network_name} ${network_ip} tcp ${listen_port} ${lxc_network_forward} ${target_address}
if [ $? -ne 0 ];
    then
        echo "端口转发添加失败,请尝试重新添加"
    else
        echo "端口转发添加完成"
fi
}



#删除端口转发
lxd_forward_port_delete()
{
clear
lxd_name
network_ip=`curl -4 ip.sb`
if [[ -z "${network_ip}" ]]
then
    echo "无法判断你的公网ip,请手动输入"
    read -p "请你输入你的公网ip: " network_ip
    [[ -z "${network_ip}" ]] && lxd_forward_port
else
    echo -e "${Red}${network_ip}${Font}"
    read -p "是否为你的公网ip(y,n): " lxc_ip_a
fi
case $lxc_ip_a in 
	[yY])
		
		;;
	[nN])
		read -p "请你输入你的公网ip: " network_ip
		;;
	*)
		echo "请输入正确选项"
        exit 0
esac

if [[ -z "${network_ip}" ]] 
then
    echo "不能为空重新输入"
    sleep 3s
    lxd_forward_port
fi
read -p "请输入删除母鸡的端口或者端口范围: " listen_port
if [ -z "$lxc_network_forward" ];then
    lxc_network_forward=`lxc profile show ${lxc_name} | grep -A 0 'network:' | awk '{print $2}'`
fi
lxc network forward port remove ${lxc_network_forward} ${network_ip} tcp ${listen_port}
}

#查看端口转发

lxc_cat_forward()
{
clear
lxd_name
network_ip=`curl -4 ip.sb`
if [[ -z "${network_ip}" ]]
then
    echo "无法判断你的公网ip,请手动输入"
    read -p "请你输入你的公网ip: " network_ip
    [[ -z "${network_ip}" ]] && lxd_forward_port
else
    echo -e "${Red}${network_ip}${Font}"
    read -p "是否为你的公网ip(y,n): " lxc_ip_a
fi
case $lxc_ip_a in 
	[yY])
		
		;;
	[nN])
		read -p "请你输入你的公网ip: " network_ip
		;;
	*)
		echo "请输入正确选项"
        exit 0
esac

if [[ -z "${network_ip}" ]] 
then
    echo "不能为空重新输入"
    sleep 3s
    lxd_forward_port
fi
if [ -z "$lxc_network_forward" ];then
    lxc_network_forward=`lxc profile show ${lxc_name} | grep -A 0 'network:' | awk '{print $2}'`
fi
lxc_networok_ip=`lxc info ${lxc_name} | sed -n '/eth0:/,/inet:/p' | grep 'inet' | awk '{print $2}'| sed 's/.\{3\}$//'`
printf "%0s %15s %13s %15s\n" 类型 公网端口 内网端口 内网地址
lxc network forward show ${lxc_network_forward} ${network_ip} | grep -B 3 ${lxc_networok_ip} | awk '{print $2}'| awk '{printf "%s     " ,$1}'| sed 's/tcp/\ntcp/g' | grep tcp
}
#备份容器
lxc_backup()
{
read -p "请输入要备份的容器名: " lxc_name
read -p "请输入需要备份到目录的绝对路径地址(例如/root): " path
echo -e "正在备份容器中...."
lxc export ${lxc_name} ${path}/${lxc_name} --compression none>/dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "备份完成,你的文件保存在 ${Red}${path}/${lxc_name}${Font}"
else
echo -e "${Red}备份失败请检查容器是否存在,或者路径是否填写正确${Font}"
exit 0
fi
}
#导入容器
lxc_import()
{
read -p "请输入备份文件的绝对路径(例如/root/文件名): " path
read -p "请输入新的磁盘大小限制(需要填写单位,GB或者MB)" lxc_disk_size
lxc_name=${path##*/}
lxc network create ${lxc_name} -t bridge>/dev/null 2>&1
lxc storage create ${lxc_name} btrfs size=${lxc_disk_size}>/dev/null 2>&1
lxc import ${path} ${lxc_name} -s ${lxc_name} 2>/root/lxc-export
lxc_profile=`cat /root/lxc-export | grep "Failed importing backup: Failed loading profiles for instance: Failed loading profile" | awk '{print $13}' | tr -cd "[0-9][a-z][A-Z]"`
lxc profile create ${lxc_profile}>/dev/null 2>&1
cat <<EOF | lxc profile edit ${lxc_profile}>/dev/null 2>&1
    {
    "config": {
    },
    "description": "Default LXD profile",
    "devices": {
    "eth0": {
      "name": "eth0",
      "network": "${lxc_name}",
      "type": "nic"
    },
    "root": {
      "path": "/",
      "pool": "${lxc_name}",
      "type": "disk"
    }
    },
    "name": "${lxc_name}",
    "used_by": []
    }
EOF
lxc import ${path} ${lxc_name} -s ${lxc_name} 2>/root/lxc-export
if [ $? -eq 0 ];then
    echo "容器导入成功！"
    exit 0
    else
    LXC_FILE="/root/lxc-export"
    LXC_STR="Failed importing backup: Failed loading profiles for instance: Failed loading profile"
    LXC_STR2="Storage pool not found: Storage pool not found"
    LXC_STR3="Error: Create instance from backup: Cannot restore volume, already exists on target"
    if grep "${LXC_STR}" ${LXC_FILE} >/dev/null;then
    lxc_profile=`cat /root/lxc-export | grep "Failed importing backup: Failed loading profiles for instance: Failed loading profile" | awk '{print $13}' | tr -cd "[0-9][a-z][A-Z]"`
    echo "导入容器失败！请尝试创建名为${lxc_profile}的模板"
    exit 0
    fi
    if grep "${LXC_STR2}" ${LXC_FILE} >/dev/null;then
    echo "导入容器失败！你输入的磁盘大小有误！"
    exit 0
    fi
    if grep "${LXC_STR3}" ${LXC_FILE} >/dev/null;then
    echo "导入失败出现同名容器,请先删除"
    exit 0
    fi
    echo "容器导入失败！"
fi
}
# ipAddr=lxc network get jp5 ipv4.address
# lxc_to_ip=${ipAddr%.*}.$((RANDOM%255+1))
# lxc config device set ${lxc_name} eth0 ipv4.address=${lxc_to_ip}
#ipt端口转发
lxd_iptables_port_create()
{
lxd_jq_ls
lxd_name
lxd_jq_cunzai
read -p "请输入实例SSH或者远程桌面端口(回车默认22端口):  " ssh_port_a
if [ -z "$ssh_port_a" ];
    then
    ssh_port_a="22"
fi
if [ $ssh_port_a -ge 0 ] && [ $ssh_port_a -le 65536 ];
    then
        i=0
    else
        echo "你输入不在端口范围内"
fi
read -p "请输入母鸡连接小鸡的SSH或者远程的端口(回车默认随机端口):  " ssh_port_b
if [ -z "$ssh_port_b" ];
    then
    ssh_port_b=$(expr $RANDOM % 65536 + 10000)
fi
if [ $ssh_port_b -ge 0 ] && [ $ssh_port_b -le 65536 ];
    then
        i=0
    else
        echo "你输入不在端口范围内"
fi
read -p "请输入小鸡的端口范围(中间用英文':'间隔开例如10000:10010): " ssh_port_c
        echo "正在为你创建转发...."
        if [[ $ssh_port_c =~ ^[0-9]+\:[0-9]+$ ]]; 
        then
        iptables_install=$(command -V iptables >/dev/null 2>&1)
        if [ $? -ne 0 ];
        then
        apt -y install iptables
        fi
        netfilter_persistent_install=$(command -V netfilter-persistent >/dev/null 2>&1)
        if [ $? -ne 0 ];
        then
        apt -y install netfilter-persistent
        fi
        if [ -f /etc/iptables/rules.v4 ];
        then
            i=0
        else
            echo "未发现ipt配置文件,开始为你创建配置文件,请全部选择yes!"
            sleep 5
            apt -y install iptables-persistent
        fi
        network_lxd_lxc_forward
        iptables -t nat -A PREROUTING -p tcp --dport ${ssh_port_b} -j DNAT --to-destination ${lxc_network_forward}:${ssh_port_a} 2>/dev/null
        iptables -t nat -A PREROUTING -p tcp -m multiport --dport ${ssh_port_c} -j DNAT --to-destination ${lxc_network_forward} 2>/dev/null
        if [ $? -eq 0 ];
            then
                echo "开启成功"
                echo "SSH端口或者远程端口: ${ssh_port_b}"
                echo "开放的端口为: ${ssh_port_c}"
                netfilter-persistent save >/dev/null 2>&1
                cat << EOF >>/usr/lxdpro_ipt
容器名:  ${lxc_name}   内网ip: ${lxc_network_forward}  SSH端口: ${ssh_port_b}  开放端口范围： ${ssh_port_c}
EOF
            else
                echo "添加失败了,请尝试重新添加"
        fi

    else
        echo "输入不符合规范"
fi
}
#删除ipt转发
lxd_iptables_port_delete()
{
lxd_jq_ls
netfilter-persistent save >/dev/null 2>&1
echo -e "${Red}请注意！这将删除容器的所有转发！${Font}"
lxd_name
lxd_jq_cunzai
echo "在为你删除实例的转发...."
network_lxd_lxc_forward
sed -i '/'${lxc_network_forward}'/d' /etc/iptables/rules.v4 >/dev/null 2>&1
netfilter-persistent reload >/dev/null 2>&1
if [ $? -ne 0 ];
then
    echo "删除失败,请重新尝试！"
    exit 0
fi
sed -i '/'${lxc_network_forward}'/d' /usr/lxdpro_ipt >/dev/null 2>&1
echo "该实例的所有端口转发已经删除"
}


lxd_iptables_port_cat()
{
clear
cat /usr/lxdpro_ipt 2>/dev/null
if [ $? -ne 0 ];
then
    echo "当前没有为实例添加端口转发!"
fi
}

#删除前自动删除转发
lxdpro_delete_ipt_list()
{
    lxdpro_delete_ipt=$(grep "$lxc_name" /usr/lxdpro_ipt | awk {'print $4'} | sort -n | uniq)
    lxdpro_delete_ipt=($lxdpro_delete_ipt)
    for delete_ipt in ${lxdpro_delete_ipt[@]};
    do
    sed -i '/'${delete_ipt}'/d' /etc/iptables/rules.v4 >/dev/null 2>&1
    sed -i '/'${delete_ipt}'/d' /usr/lxdpro_ipt >/dev/null 2>&1
    done
    netfilter-persistent reload >/dev/null 2>&1

}




#自动定时备份
lxc_corn_time()
{
clear
echo "1.分钟"
echo "2.小时"
echo "3.天"
while :; do echo
        read -p "请输入定时任务的时间隔单位: " lxc_time
        if [[ ! $lxc_time =~ ^[1-3]$ ]]
        then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		else
				break   
		fi
done
#分钟
if [ ${lxc_time} -eq 1 ];then
read -p "每隔多少分钟备份一次: " lxc_time
read -p "请输入要备份的容器名: " lxc_name
read -p "请输入需要备份到目录的绝对路径地址(例如/root): " path
cat << EOF >/etc/cron.d/lxc_backups
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
EOF
sed -i '4,$d' /etc/cron.d/lxc_backups
echo "*/${lxc_time} * * * * root /snap/bin/lxc export ${lxc_name} ${path}/${lxc_name} --compression none" >>/etc/cron.d/lxc_backups
time=`date -d "${lxc_time} minute" +%Y-%m-%d_%X`
echo "设置成功！文件自动备份在 ${path} 目录下,下次自动备份日期为: ${time}"
exit 0
fi
#小时
if [ ${lxc_time} -eq 2 ];then
read -p "每隔多少小时备份一次: " lxc_time
read -p "请输入要备份的容器名: " lxc_name
read -p "请输入需要备份到目录的绝对路径地址(例如/root): " path
cat << EOF >/etc/cron.d/lxc_backups
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
EOF
sed -i '4,$d' /etc/cron.d/lxc_backups
echo "* */${lxc_time} * * * root /snap/bin/lxc export ${lxc_name} ${path}/${lxc_name} --compression none" >>/etc/cron.d/lxc_backups
time=`date -d "${lxc_time} hours" +%Y-%m-%d_%X`
echo "设置成功！文件自动备份在 ${path} 目录下,下次自动备份日期为: ${time}"
exit 0
fi
#天
if [ ${lxc_time} -eq 3 ];then
read -p "每隔多少天备份一次: " lxc_time
read -p "请输入要备份的容器名: " lxc_name
read -p "请输入需要备份到目录的绝对路径地址(例如/root): " path
cat << EOF >/etc/cron.d/lxc_backups
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
EOF
sed -i '4,$d' /etc/cron.d/lxc_backups
echo "* * */${lxc_time} * * root /snap/bin/lxc export ${lxc_name} ${path}/${lxc_name} --compression none" >>/etc/cron.d/lxc_backups
time=`date -d "${lxc_time} days" +%Y-%m-%d_%X`
echo "设置成功！文件自动备份在 ${path} 目录下,下次自动备份日期为: ${time}"
exit 0
fi
}

#定时所有
lxc_corn_time_all()
{
clear
echo "1.分钟"
echo "2.小时"
echo "3.天"
while :; do echo
        read -p "请输入定时任务的时间隔单位: " lxc_time
        if [[ ! $lxc_time =~ ^[1-3]$ ]]
        then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		else
				break   
		fi
done
#分钟
if [ ${lxc_time} -eq 1 ];then
read -p "每隔多少分钟备份一次: " lxc_time
read -p "请输入需要备份到目录的绝对路径地址(例如/root): " path
cat << EOF >/etc/cron.d/lxc_backups
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
EOF
for lxc_name in $(lxc ls -c n -f csv)
do
echo "*/${lxc_time} * * * * root /snap/bin/lxc export ${lxc_name} ${path}/${lxc_name} --compression none" >>/etc/cron.d/lxc_backups
done
time=`date -d "${lxc_time} minute" +%Y-%m-%d_%X`
echo "设置成功！文件自动备份在 ${path} 目录下,下次自动备份日期为: ${time}"
exit 0
fi
#小时
if [ ${lxc_time} -eq 2 ];then
read -p "每隔多少小时备份一次: " lxc_time
read -p "请输入需要备份到目录的绝对路径地址(例如/root): " path
cat << EOF >/etc/cron.d/lxc_backups
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
EOF
for lxc_name in $(lxc ls -c n -f csv)
do
echo "* */${lxc_time} * * * root /snap/bin/lxc export ${lxc_name} ${path}/${lxc_name} --compression none" >>/etc/cron.d/lxc_backups
done
time=`date -d "${lxc_time} hours" +%Y-%m-%d_%X`
echo "设置成功！文件自动备份在 ${path} 目录下,下次自动备份日期为: ${time}"
exit 0
fi
#每天
if [ ${lxc_time} -eq 3 ];then
read -p "每隔多少天备份一次: " lxc_time
read -p "请输入需要备份到目录的绝对路径地址(例如/root): " path
cat << EOF >/etc/cron.d/lxc_backups
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
EOF
for lxc_name in $(lxc ls -c n -f csv)
do
echo "* * */${lxc_time} * * root /snap/bin/lxc export ${lxc_name} ${path}/${lxc_name} --compression none" >>/etc/cron.d/lxc_backups
done
time=`date -d "${lxc_time} days" +%Y-%m-%d_%X`
echo "设置成功！文件自动备份在 ${path} 目录下,下次自动备份日期为: ${time}"
exit 0
fi

} 





lxc_corn()
{
clear
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2023.12.26     版本: v0.2.3"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.定时备份指定容器${Font}"
echo -e "          ${Green}2.定时备份所有容器${Font}"
echo -e "          ${Green}3.删除所有定时${Font}"

while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-3]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    1)  lxc_corn_time
    ;;
    2)  lxc_corn_time_all
    ;;
    3)  rm -f /etc/cron.d/lxc_backups
        echo "定时任务已删除"
    ;;
esac
}




# 创建系统容器
admin_cat2()
{
command -V lxc >/dev/null 2>&1
if [ $? -eq 0 ];then

clear 
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2023.12.26     版本: v0.2.3"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.一键创建容器${Font}"
echo -e "          ${Green}2.创建物理卷${Font}"
echo -e "          ${Green}3.创建网卡${Font}"
echo -e "          ${Green}4.创建配置模板${Font}"
echo -e "          ${Green}5.创建容器${Font}"
echo -e "          ${Green}0.返回首页${Font}"



while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[0-5]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    0)  front_page
    ;;
    1)  lxd_Create_selection
    ;;
    2)  alone_lxc_disk
    ;;
    3)  alone_lxc_network
    ;;
    4)  alone_lxc_Profiles
    ;;
    5)  alone_lxc
    ;;
esac
else 
echo -e "     ${Red}请先安装LXD!${Font}"
sleep 5s
front_page
fi
}




#删除系统容器

admin_cat3()
{
    clear 
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2023.12.26     版本: v0.2.3"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.一键删除${Font}"
echo -e "          ${Green}2.删除网络${Font}"
echo -e "          ${Green}3.删除磁盘${Font}"
echo -e "          ${Green}4.删除容器${Font}"
echo -e "          ${Green}5.删除容器配置模板${Font}"
echo -e "          ${Green}0.返回首页${Font}"
while :; do echo
		read -p "请输入数字选择: " choice 
		if [[ ! $choice =~ ^[0-5]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    0)  front_page
    ;;
    1)  lxd_delete_lxc
        lxdpro_delete_ipt_list
        lxc_stop
        lxc_delete
        lxc_yaf
        lxc_delete_network
        lxc_delete_storage
        sed -i '/'${lxc_name}'/d' /usr/lxdprolist  >/dev/null 2>&1
    ;;
    2)  read -p "请输入要删除的容器网卡名称:" network_lxc
        lxc_delete_network
    ;;
    3)  read -p "请输入要删除的磁盘名称:" storage_delete
        lxc_delete_storage
    ;;
    4)  read -p "请输入要删除的容器名称:" lxc_name
        lxc_stop
        lxc_delete
    ;;
    5)  read -p "请输入要删除的模板名称:" profile_delete
        lxc_yaf
    ;;

esac
}





#管理系统容器
admin_cat4()
{
clear 
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2023.12.26     版本: v0.2.3"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.启动容器${Font}"
echo -e "          ${Green}2.停止容器${Font}"
echo -e "          ${Green}3.重启容器${Font}"
echo -e "          ${Green}4.进入指定容器${Font}"
echo -e "          ${Green}5.查看容器信息${Font}"
echo -e "          ${Green}6.查看容器列表${Font}"
echo -e "          ${Green}7.查看磁盘列表${Font}"
echo -e "          ${Green}8.查看网卡列表${Font}"
echo -e "          ${Green}9.对容器进行限制${Font}"
echo -e "          ${Green}10.通过进程PID查找容器${Font}"
echo -e "          ${Green}11.一键开启容器SSH${Font}"
echo -e "          ${Green}0.返回首页${Font}"

while :; do echo
		read -p "请输入数字选择: " choice
		if [[ $choice -ge 0 ]] && [[ $choice -le 11 ]]
         then
				break
		 else
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		fi
done

case $choice in
    0)  front_page
    ;;
    1)  lxd_jq_ls
        lxd_lxc_start
    ;;
    2)  lxd_jq_ls
        lxd_lxc_stop
    ;;
    3)  lxd_jq_ls
        lxd_lxc_restart
    ;;
    4)  lxd_exec_lxc
    ;;
    5)  lxd_jq_ls
        lxd_name
        lxd_jq_cunzai
        echo -e "${Green}稍等一下，正在获取容器信息!${Font}"
        lxd_information
    ;;
    6)  lxd_list_lxc
    ;;
    7)  lxd_list_disk
    ;;
    8)  lxd_list_network
    ;;
    9)  lxc_limit
    ;;
    10) lxd_lxc_pid
    ;;
    11) lxd_jq_ls
        lxd_name
        lxc_root_passwd
    ;;
esac
}


admin_cat5()
{
clear 
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2023.12.26     版本: v0.2.3"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.创建端口转发${Font}"
echo -e "          ${Green}2.删除端口转发${Font}"
echo -e "          ${Green}3.查看容器端口转发${Font}"
echo -e "          ${Green}0.返回首页${Font}"




while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[0-3]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    0)  front_page
    ;;
    # 1)  lxd_forward_port_create
    1)  lxd_iptables_port_create
    ;;
    # 2)  lxd_forward_port_delete
    2)  lxd_iptables_port_delete
    ;;
    # 3)  lxc_cat_forward
    3)  lxd_iptables_port_cat
    ;;
esac
}

admin_cat6()
{
clear
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2023.12.26     版本: v0.2.3"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.备份容器${Font}"
echo -e "          ${Green}2.导入备份${Font}"
echo -e "          ${Green}3.定时备份容器${Font}"


while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-7]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    1)  lxc_backup
    ;;
    2)  lxc_import
        #lxc_import2
    ;;
    3)  lxc_corn
    ;;
esac
}

admin_cat7()
{
clear
cat << EOF >/etc/cron.d/lxc_telegram_bot
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
EOF
echo "1.分钟"
echo "2.小时"
echo "3.天"
while :; do echo
        read -p "请选择定时任务的时间隔单位: " lxc_time
        if [[ ! $lxc_time =~ ^[1-3]$ ]]
        then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		else
				break   
		fi
done
case $lxc_time in
    1)  read -p "每隔多少分钟提醒一次: " lxc_time
        echo "*/${lxc_time} * * * * root /usr/bin/bash /var/log/lxc_telegram.sh" >>/etc/cron.d/lxc_telegram_bot
    ;;
    2)  read -p "每隔多少小时提醒一次: " lxc_time
        echo "* */${lxc_time} * * * root /usr/bin/bash /var/log/lxc_telegram.sh" >>/etc/cron.d/lxc_telegram_bot
    ;;
    3)  read -p "每隔多少天提醒一次: " lxc_time
        echo "* * */${lxc_time} * * root /usr/bin/bash /var/log/lxc_telegram.sh" >>/etc/cron.d/lxc_telegram_bot
    ;;
esac
echo "tg搜索@getuseridbot 获取id"
read -p "请输入账号id: " tg_id
echo "tg搜索@BotFather 输入/newbot 创建机器人获取token"
read -p "请输入机器人token API: " tg_bot_token
cat << EOF > /var/log/lxc_telegram.sh
#!/bin/bash
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
rm -f /var/log/lxc_bot.log
for para in \$(/snap/bin/lxc ls -c nu -f compact | grep -E '([1-9][0-9][0-9][0-9][0-9][0-9]*)' | awk '{print \$1}')
do
echo "名称: \${para}">> /var/log/lxc_bot.log
echo "类型: CPU占用高">> /var/log/lxc_bot.log
echo "状态: \$(/snap/bin/lxc info \${para} | grep Status: | awk '{print \$2}')">> /var/log/lxc_bot.log
echo "">> /var/log/lxc_bot.log
done
if [[ ! -n \${para} ]];then 
echo eixt
else
message_text="
⚠️警告！有容器占用大量资源
——————————————— 
\$(cat /var/log/lxc_bot.log)
——————————————— "   #通知内容
MODE='HTML' 
URL="https://api.telegram.org/bot${tg_bot_token}/sendMessage"
curl -s -o /dev/null -X POST \$URL -d chat_id=${tg_id} -d text="\${message_text}" 
fi
rm -f /var/log/lxc_bot.log
for para in \$(/snap/bin/lxc ls -c ns -f compact | grep "STOPPED" | awk '{print \$1}')
do
echo "名称: \${para}">> /var/log/lxc_bot.log
echo "离线时间: \$(/snap/bin/lxc info \${para} | grep 'Last Used:' | awk '{print \$3,\$4}')">> /var/log/lxc_bot.log
echo "">> /var/log/lxc_bot.log
done
if [[ ! -n \${para} ]];then 
echo eixt
else
message_text="
⚠️警告！有容器停止了
——————————————— 
\$(cat /var/log/lxc_bot.log)
——————————————— "   #通知内容
MODE='HTML' 
URL="https://api.telegram.org/bot${tg_bot_token}/sendMessage"
curl -s -o /dev/null -X POST \$URL -d chat_id=${tg_id} -d text="\${message_text}" 
fi
EOF
}



admin_cat8()
{
echo "正在检查python...."
# apt -y upgrade python3
s_py=$(python3 -V)
echo $s_py >/dev/null 2>&1
if [ $? -ne 0 ]
    # then
    #     echo "python3已安装"
    then
        apt -y install python3
fi
sdd=`python3 -V | awk '{print $2}'`
if [[ "$sdd" < "3.7.0" ]]
    # then
    #     echo "python版本没问题"
    then
        apt -y upgrade python3
fi

#         apt -y upgrade python3
pip3 -V >/dev/null 2>&1
#echo $s_pip >/dev/null 2>&1
s_pip=$?
if [ $s_pip != 0 ]
    # then
    #     echo "pip3已安装"
    then
        apt -y install python3-pip
    else
        echo "没问题啦"
fi
# s_pip
# if $? != 0
#     then
#         apt -y install pthon3-pip
pip3 show python-telegram-bot >/dev/null 2>&1
#echo $s_tg >/dev/null 2>&1
s_tg=$?
if [ $s_tg != 0 ]
    # then
    #     echo "环境已安装"
    then
        pip3 install python-telegram-bot[ext]
fi
echo "tg搜索@getuseridbot 获取id"
read -p "请输入账号id: " tg_id
echo "tg搜索@BotFather 输入/newbot 创建机器人获取token"
read -p "请输入机器人token API: " tg_bot_token
mkdir "/usr/lxdpro"
wget https://raw.githubusercontent.com/MXCCO/lxdpro/main/lxdtgbot.py -O /usr/lxdpro/lxdtgbot.py && chmod +x /usr/lxdpro/lxdtgbot.py
cat << EOF > /etc/systemd/system/lxdbot.service

[Unit]
Description=Test Service
After=multi-user.target

[Service]
user=root
Type=idle
ExecStart=/usr/bin/python3 /usr/lxdpro/lxdtgbot.py ${tg_id} ${tg_bot_token}

[Install]
WantedBy=multi-user.target
EOF
chmod +x /etc/systemd/system/lxdbot.service
sudo systemctl daemon-reload
sudo systemctl start lxdbot.service
sudo systemctl enable lxdbot.service
echo "机器人已部署,请在tg上看是否成功"
}






#首页
front_page()
{
clear
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2023.12.26     版本: v0.2.3"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.安装LXD${Font}"
echo -e "          ${Green}2.创建系统容器${Font}"
echo -e "          ${Green}3.删除系统容器${Font}"
echo -e "          ${Green}4.管理系统容器${Font}"
echo -e "          ${Green}5.容器端口转发${Font}"
echo -e "          ${Green}6.备份和导入容器${Font}"
echo -e "          ${Green}7.tg机器人提醒${Font}"
echo -e "          ${Green}8.tg机器人管理面板${Font}"
echo -e "          ${Green}9.更新脚本${Font}"



while :; do echo
		read -p "请输入数字选择: " choice
		if [ $choice -ge 1 -a $choice -le 9 ]
            then
				break
		else
			echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"   
		fi
done

case $choice in
    1)  snap_install
        sleep 4s
        front_page
    ;;
    2)  admin_cat2
    ;;
    3)  admin_cat3
    ;;
    4)  admin_cat4
    ;;
    5)  admin_cat5
    ;;
    6)  admin_cat6
    ;;
    7)  admin_cat7
    ;;
    8)  admin_cat8
    ;;
    9)  wget -N --no-check-certificate https://raw.githubusercontent.com/MXCCO/lxdpro/main/lxdpro.sh
        chmod +x lxdpro.sh
        echo "更新完成3秒后执行新脚本"
        sleep 3s
        ./lxdpro.sh
    ;;
esac
}


front_page



# curl -s --unix-socket /var/snap/lxd/common/lxd/unix.socket lxd/1.0/networks/us77 | jq '.|.metadata|.config' | jq -r '.["ipv4.address"]'
