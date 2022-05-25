# 这是一个什么脚本？
<br>这是个能开系统容器的脚本,类似于虚拟机，俗称开“小鸡”,小白也能开小鸡,此脚本基于Ubuntu/Ddebian的snap安装,目前仅支持Ubuntu/Debian系统,其他系统看情况后续再做更新
<br>大部分VPS商的Ubuntu镜像包都有自带snap包和LXD可以无需在安装
# 为什么要写这个脚本？
<br>有天我在LOC的论坛上发现有找人合租VPS的意向,但是对方说只能用docker开车,我就翻了记录很多VPS合租都用docker,但是我更需要是一个独立的系统,所以萌生了写这个脚本。
```
wget -N --no-check-certificate https://raw.githubusercontent.com/MXCCO/lxdpro/main/lxdpro.sh && bash lxdpro.sh
```
<br>再次使用
```
bash lxdpro.sh
```

## 更新日志
<P>2022.5.25&nbsp;&nbsp;新增一键开启系统容器的SSH和修改SSH密码,优化容器信息页面</p>
<P>2022.5.23&nbsp;&nbsp;脚本完成，主体50％的功能</p>
<br>


## 脚本特点
* 1分钟内快速创建系统容器
* 每个小鸡拥有独立的环境
* 直接调用基于官方的apt和snap包安装,脚本没有一个调用wget和curl外部的安装包,放心使用
* 无需独立服务器也能开小鸡，大部分VPS都能开
* 支持对系统CPU、内存、磁盘大小限制
* 支持主流的系统创建，如Debian11,ubantu21，centos7,还有其他apine等
* 支持开公网IPV4和IPV6,但是需要一定的liunx知识,支持内网转发
* 发现高占用进程可以通过此脚本查找到指定小鸡
<br>
<br> ————实测甲骨文的2C2G60G能开30台1H512M1.5G的30台
<br> ————DigitalOcean的4C8G160G不吃满硬盘的情况能开135台1H512G2GSSD
<br> ————正常一般1C1G20GSSD的VPS能开15台左右
<br>
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/containers.small.png?raw=true" border="0">

## 什么是LXC
LXC 是 Linux 内核包含特性的用户空间接口。通过强大的 API 和简单的工具，它可以让 Linux 用户轻松创建和管理系统或应用程序容器。
<br>LXC 容器通常被认为介于 chroot 和成熟的虚拟机之间。LXC 的目标是创建一个尽可能接近标准 Linux 安装的环境，但不需要单独的内核。
<br>为什么不用Docker作为系统容器呢？Docker针对应用的部署做了优化，反映在其API，用户接口，设计原理及文档上面.而LXC仅仅关注容器作为一个轻量级的服务器。,docker底层就是LXC，是LXC的拓展可以理解为docker是lxc儿子,在LXC中可以使用docker.

## 什么是LXD
官方的介绍：
<br>LXD 是基于镜像的，并为大量的 Linux 发行版提供镜像。它为各种用例提供了灵活性和可扩展性，支持不同的存储后端和网络类型，并且可以选择安装在从单个笔记本电脑或云实例到完整服务器机架的硬件上。
<br>使用 LXD 时，您可以使用简单的命令行工具、直接通过 REST API 或使用第三方工具和集成来管理您的实例（容器和虚拟机）。LXD 为本地和远程访问实现了一个 REST API。
<br>LXD底层也是是LXC结合LXCFS,总结就是LXC的升级版
## LXD能实现什么
* 每个用户都有用了独立的系统以及所有权限，但不被允许之间操作宿主机
* 每个容器拥有可以在局域网内访问的独立IP地址，用户可以使用SSH方便地访问自己的“机器”
* 所有用户都可以使用所有的资源，包括CPU、GPU、硬盘、内存等
* 可以创建共享文件夹，将共用数据集、模型、安装文件等进行共享，减少硬盘浪费
* 可以安装图形化桌面进行远程操作
* 容器与宿主机使用同一个内核，性能损失小
* 轻量级隔离，每个容器拥有自己的系统互不影响
* 容器可以共享地使用宿主机的所有计算资源
## 脚本截图
<P>首页：</p>
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/LXD.PNG?raw=true">
<P>系统容器创建：</p>
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/LXD2.PNG?raw=true">
<P>管理容器页面：</p>
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/LXD3.PNG?raw=true">
<P>容器限制页面：</p>
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/LXD4.PNG?raw=true">
<P>容器信息页面：</p>
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/LXD5.PNG?raw=true">
<P>安装镜像选择页面：</p>
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/LXD6.PNG?raw=true">

## 实测
<br>这是我通过脚本开出来的小鸡 4H1G 8g硬盘 50M
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/LXD7.PNG?raw=true">
<br><img src="https://github.com/MXCCO/lxdpro/blob/main/%E6%88%AA%E5%9B%BE/LXD8.PNG?raw=true">


