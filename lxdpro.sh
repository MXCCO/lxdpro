#!/bin/bash

Green="\033[32m"
yellow="\033[33m"
Font="\033[0m"
Red="\033[31m"
Cyan='\033[0;36m'
Pe="\033[0;35m"




# 安装snap
snap_install(){
    if [[ -d '/snap' ]]
        then
            echo "snap已安装"
            
        else
            echo "未安装snap"
            echo "开始安装snap"
            echo `apt install snap -y`
            echo `apt install snapd -y`
            echo "snap安装完成"
    fi
}
# 安装LXD
lxd_install(){
    if [[ -d '/snap/lxd' ]]
        then
            echo "lxd已安装"
            
        else
            echo "未安装LXD"
            echo "开始安装LXD"
            echo `apt install snap -y`
            echo `snap install lxd`
            echo "LXD安装完成"
            echo "需要重启可执行后续脚本"
    fi
}

#容器名称
lxd_name(){
read -p "输入容器名称(只能英文数字且必须输入):" lxc_name
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
read -p "请输入磁盘类型(可选btrfs,LVM,ZFS 默认btrfs):" lxc_disk
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
head -p "请输入要创建的模板名称: " lxc_name
[ -z "$lxc_name" ] && 不能为空请重新输入&& sleep 3s && alone_lxc_Profiles
head -p "请输入关联此模板的网卡: " lxc_name_network
[ -z "$lxc_name_network" ] && 不能为空请重新输入; sleep 3s; alone_lxc_Profiles
head -p "请输入关联此模板的物理卷: " lxc_name_disk
[ -z "$lxc_name_disk" ] && 不能为空请重新输入; sleep 3s; alone_lxc_Profiles
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
[ -z "$lxc_name" ] && 不能为空请重新输入!; sleep 3s; alone_lxc
[ -z "$lxc_Profiles" ] && 不能为空请重新输入!; sleep 3s; alone_lxc

echo -e "开始创建容器                 ${yellow}[warnning]${Font}"
echo `lxc init images:debian/bullseye ${lxc_name} -p ${lxc_Profiles}`
echo -e "创建容器完成                 ${Green}[success]${Font}"
}








#创建容器
lxc_user_lxc()
{
echo "开始创建容器"
lxc init tuna-images:${lxc_os} ${lxc_name} -n ${lxc_name} -s ${lxc_name}>/dev/null 2>&1
} 

#创建简单硬盘
lxc_user_storage_create()
{
echo "开始创建物理卷 物理卷名: ${lxc_name}"
lxc storage create ${lxc_name} zfs>/dev/null 2>&1
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
read -p "请输入要删除的容器名称:" lxc_name
read -p "请输入要删除的容器网卡名称(默认与容器名相同):" network_lxc
read -p "请输入要删除的磁盘名称(默认与容器名相同):" storage_delete
read -p "请输入要删除的模板名称(默认与容器名相同):" profile_delete
[ -z "$network_lxc" ] && network_lxc="${lxc_name}"
[ -z "$storage_delete" ] && storage_delete="${lxc_name}"
[ -z "$profile_delete" ] && profile_delete="${lxc_name}"

}

#进入容器
lxd_exec_lxc()
{
read -p "请输入你要进去的容器名(exit可退出容器):" lxc_exec
lxc exec ${lxc_exec} /bin/bash
}

#容器列表
lxd_list_lxc()
{
lxc ls -c npc
}

#磁盘列表
lxd_list_disk()
{
lxc storage list
}

#网卡列表
lxd_list_network()
{
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
    1)  read -p "请输入容器名: " lxc_name
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
    1)  read -p "请输入容器名: " lxc_name
        echo -n `lxc stop ${lxc_name}>/dev/null 2>&1`
        [[ $? != 0 ]] && echo "容器已经是停止状态" || echo "容器停止成功"
    ;;
    2)  read -p "是否停止所有容器(y/n): " judge
        [[ $judge = y ]] && echo `lxc stop --all` || exit 0
        echo "成功停止所有容器,如有报错请注意提示个别容器无法启动"
    ;;
    3)  read -p "请输入容器名: " lxc_name
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
    1)  read -p "请输入容器名: " lxc_name
        echo -n `lxc restart ${lxc_name}>/dev/null 2>&1`
        [[ $? != 0 ]] && echo "容器重启失败" || echo "容器重启成功"
    ;;
    2)  read -p "是否停止所有容器(y/n): " judge
        [[ $judge = y ]] && echo `lxc restart --all` || exit 0
        echo "成功停止所有容器,如有报错请注意提示个别容器无法启动"
    ;;
    3)  read -p "请输入容器名: " lxc_name
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
lxc_peak=`lxc info ${lxc_name} | grep peak | awk '{print $3}'`
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
echo -e "4.Ubuntu 16.04"
echo -e "5.Ubuntu 18.04"
echo -e "6.Ubuntu 21.10"
echo -e "7.alpine 3.15"
echo -e "8.Archlinxe"
echo -e "9.OpenWrt 21.02"

while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-9]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done


if [[ ${choice} == 1 ]]; then
           lxc_os="e61699158f1a"
fi
if [[ ${choice} == 2 ]]; then
           lxc_os="69db22001a7a"
fi
if [[ ${choice} == 3 ]]; then
           lxc_os="3a4163222a99"
fi
if [[ ${choice} == 4 ]]; then
           lxc_os="181b0eb3695b"
fi
if [[ ${choice} == 5 ]]; then
           lxc_os="efe16ae6eadb"
fi
if [[ ${choice} == 6 ]]; then
           lxc_os="0c88d136b87b"
fi
if [[ ${choice} == 7 ]]; then
           lxc_os="f4d8c598cc24"
fi
if [[ ${choice} == 8 ]]; then
           lxc_os="80b50b0984eb"
fi
if [[ ${choice} == 9 ]]; then
           lxc_os="e2cce7a0a7ef"
fi
}

lxc_establish()
{
echo "请输入纯数字！"
read -p "请输入容器名称: " lxc_name
read -p "cpu限制核数: " lxc_cpu
read -p "运行内存限制(默认单位MB): " lxc_memory
read -p "硬盘大小限制(默认单位MB): " lxc_disk
read -p "网速限制(默认单位mbps): " lxc_rate

lxc_user_storage_create
lxc_user_network_create
lxc_user_lxc
lxc_user_cpu
lxc_user_memory
lxc_user_disk
lxc_user_network_rate
lxc_start
lxd_information

}



#root     3354620 3294044  0 13:48 pts/2    00:00:00 grep --color=auto 505423
#进程查找容器
lxd_lxc_pid()
{
read -p "请输入任务进程里面的PID: " lxc_pid

lxd_pid=`grep -lwm1 ${lxc_pid} /sys/fs/cgroup/pids/lxc.payload.*/*/*/tasks | sed 's/.*lxc\.payload\.//; s/\/.*//'`
if  [ $lxd_pid ]
    then
    echo -e "这PID进程属于 ${Red}$lxd_pid${Font} 容器"
    else
    echo -e "${Red}请输入正确的pid,或者此pid不是为常驻进程!${Font}"
    echo -e "如果无法查到容器,请使用 ${Red}kill${Font} 和 ${Red}killall${Font} 杀掉PID或者进程名"
fi
}





#一键创建容器选择
lxd_Create_selection()
{
echo "1.快速创建容器(网卡名称和物理卷名与容器名相同,物理卷默认为ZFS适合小白)"
echo "2.精确创建(单独创建物理卷,单独创建物理卷,单独创建模板写入前两者"
echo "再通过模板创建容器,可以自行选择物理卷类型与网关和ip)"

while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-2]$ ]]
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
}





# 创建系统容器
admin_cat2()
{
clear 
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2022.5.23"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.一键创建容器${Font}"
echo -e "          ${Green}2.创建物理卷${Font}"
echo -e "          ${Green}3.创建网卡${Font}"
echo -e "          ${Green}4.创建配置模板${Font}"
echo -e "          ${Green}5.创建容器${Font}"

while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-5]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
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

}




#删除系统容器

admin_cat3()
{
    clear 
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2022.5.23"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.一键删除${Font}"
echo -e "          ${Green}2.删除网络${Font}"
echo -e "          ${Green}3.删除磁盘${Font}"
echo -e "          ${Green}4.删除容器${Font}"
echo -e "          ${Green}5.删除容器配置模板${Font}"
while :; do echo
		read -p "请输入数字选择: " choice 
		if [[ ! $choice =~ ^[1-4]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done

case $choice in
    1)  lxd_delete_lxc
        lxc_stop
        lxc_delete
        lxc_yaf
        lxc_delete_network
        lxc_delete_storage
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
echo -e "更新时间: 2022.5.23"
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

while :; do echo
		read -p "请输入数字选择: " choice
		if [[ $choice -ge 1 ]] && [[ $choice -le 10 ]]
         then
				break
		 else
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		fi
done

case $choice in
    1)  lxd_lxc_start
    ;;
    2)  lxd_lxc_stop
    ;;
    3)  lxd_lxc_restart
    ;;
    4)  lxd_exec_lxc
    ;;
    5)  lxd_name
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
esac



}







#首页
front_page()
{
clear
echo -e "————————————————By'MXCCO———————————————"
echo -e "脚本地址: https://github.com/MXCCO/lxdpro"
echo -e "更新时间: 2022.5.23"
echo -e "———————————————————————————————————————"
echo -e "          ${Green}1.安装LXD${Font}"
echo -e "          ${Green}2.创建系统容器${Font}"
echo -e "          ${Green}3.删除系统容器${Font}"
echo -e "          ${Green}4.管理系统容器${Font}"


while :; do echo
		read -p "请输入数字选择: " choice
		if [[ ! $choice =~ ^[1-4]$ ]]
         then
				echo -ne "     ${Red}输入错误, 请输入正确的数字!${Font}"
		 else
				break   
		fi
done


case $choice in
    1)  snap_install
        lxd_install
    ;;
    2)  admin_cat2
    ;;
    3)  admin_cat3
    ;;
    4)  admin_cat4
    ;;
    *)  echo '你没有输入 1 到 4 之间的数字'
    ;;
esac
}


front_page
