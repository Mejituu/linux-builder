#!/usr/bin/env bash

# 这一步用于从脚本同目录下的 config 文件中获取要编译的内核版本号
LINUX_VERSION=$(grep 'Kernel Configuration' < config | awk '{print $3}')

# add deb-src to sources.list Ubuntu系统只需要把系统 apt 配置中的源码仓库注释取消掉即可
sed -i "/deb-src/s/# //g" /etc/apt/sources.list

# 安装依赖
apt update
apt full-upgrade -y
apt install -y wget git xz-utils rsync python3 build-essential bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves bison
apt build-dep -y linux

# 将目录更改为工作场所
cd ${GITHUB_WORKSPACE} || exit

# 下载内核源码
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${LINUX_VERSION}.tar.xz -O - | tar xJ
cd linux-${LINUX_VERSION} || exit

# 复制配置文件
cp ../config .config

# 禁用 DEBUG_INFO 以加速构建
scripts/config --disable DEBUG_INFO

#从内核 5.18+ 开始，还需要启用DEBUG_INFO_NONE
scripts/config --enable DEBUG_INFO_NONE

# 应用 patch.d/ 目录下的脚本，用于自定义对系统源码的修改
source ../patch.d/*.sh

# 构建 deb 包
# 获取系统的 CPU 核心数，将核心数X2设置为编译时开启的进程数，以加快编译速度
CPU_CORES=$(($(grep -c processor < /proc/cpuinfo)*2))
#make deb-pkg -j${CPU_CORES}
fakeroot make -j${CPU_CORES} bindeb-pkg LOCALVERSION=-mejituu KDEB_PKGVERSION=$(make kernelversion)-1 ARCH=x86_64

# 将 deb 包移动到 mejituu 目录
cd ..
rm -rf linux-${LINUX_VERSION}
mkdir mejituu
mv ./*.deb mejituu/
