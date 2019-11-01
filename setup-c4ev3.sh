#!/bin/bash

#Created by Jakob Stickles
#Last updated 10/31/19
#Not tested a whole lot - if there are any issues, let me know!

if [[ ! $(sudo echo 0) ]]; then exit; fi
cd ~/

echo "<<<Setting up C4EV3>>>"

if ! dpkg -s libudev-dev git build-essential python pkg-config >/dev/null 2>&1; then
  echo "<<<Installing dependencies>>>"
  sudo apt update
  sudo apt install libudev-dev git build-essential python pkg-config -y 
  if [[ $? > 0 ]]; then
    echo "<<<Setup failed>>>"
    exit 
  fi
fi

if [ ! -f "buildroot-2019.08.1.tar.gz" ]; then
  echo "<<<Downloading buildroot>>>"
  wget "https://buildroot.org/downloads/buildroot-2019.08.1.tar.gz"
fi

if [ ! -d "buildroot-2019.08.1" ]; then
  echo "<<<Extracting buildroot>>>"
  tar xf "buildroot-2019.08.1.tar.gz"
fi

cd buildroot-2019.08.1
if [ ! -f "configs/c4ev3_defconfig" ]; then
  echo "<<<Creating config file>>>"
  echo 'BR2_arm=y
BR2_ARCH_HAS_TOOLCHAIN_BUILDROOT=y
BR2_ARCH="arm"
BR2_ENDIAN="LITTLE"
BR2_GCC_TARGET_ABI="aapcs-linux"
BR2_GCC_TARGET_CPU="arm926ej-s"
BR2_GCC_TARGET_FLOAT_ABI="soft"
BR2_GCC_TARGET_MODE="arm"
BR2_BINFMT_SUPPORTS_SHARED=y
BR2_READELF_ARCH_NAME="ARM"
BR2_BINFMT_ELF=y
BR2_ARM_CPU_HAS_ARM=y
BR2_ARM_CPU_HAS_THUMB=y
BR2_ARM_CPU_ARMV5=y
BR2_arm926t=y
BR2_TOOLCHAIN=y
BR2_TOOLCHAIN_USES_UCLIBC=y
BR2_TOOLCHAIN_BUILDROOT=y
BR2_TOOLCHAIN_BUILDROOT_VENDOR="c4ev3"
BR2_TOOLCHAIN_BUILDROOT_UCLIBC=y
BR2_TOOLCHAIN_BUILDROOT_LIBC="uclibc"
BR2_KERNEL_HEADERS_CUSTOM_TARBALL=y
BR2_KERNEL_HEADERS_CUSTOM_TARBALL_LOCATION="https://github.com/torvalds/linux/archive/v2.6.33-rc4.tar.gz"
BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_REALLY_OLD=y
BR2_PACKAGE_UCLIBC=y
BR2_TOOLCHAIN_BUILDROOT_WCHAR=y
BR2_USE_WCHAR=y
BR2_UCLIBC_INSTALL_UTILS=y
BR2_UCLIBC_TARGET_ARCH="arm"
BR2_GCC_VERSION_9_X=y
BR2_TOOLCHAIN_BUILDROOT_CXX=y
BR2_STATIC_LIBS=y' >configs/c4ev3_defconfig
fi

if [ ! -d "output/host/bin" ]; then
  echo "<<<Building toolchain>>>"
  make c4ev3_defconfig
  make toolchain
  echo export PATH=~/buildroot-2019.08.1/output/host/bin/:$PATH >> ~/.bashrc && . ~/.bashrc
fi
cd ..

mkdir -p c4ev3
cd c4ev3
if [ ! -d "ev3duder" ]; then
  echo "<<<Downloading ev3duder>>>"
  git clone "https://github.com/c4ev3/ev3duder"
  cd ev3duder
  sed -i 's+arm-linux-gnueabi-g+arm-c4ev3-linux-uclibcgnueabi-g+g' Makefile
  sed -i 's+-@mkdir+-@mkdir -p+g' Makefile
  sed -i 's+ln -s+ln -sfn+g' Makefile
  cd ..
fi

cd ev3duder
if [ ! "$(ls -A ~/c4ev3/ev3duder/EV3-API)" ]; then
  echo "<<<Downloading EV3-API>>>"
  git clone "https://github.com/c4ev3/EV3-API"
  echo "<<<Building EV3-API>>>"
  cd EV3-API/API/
  sed -i 's+C:/CSLite/bin/arm-none-linux-gnueabi-+arm-c4ev3-linux-uclibcgnueabi-+g' Makefile
  make
  cd ..
  cd ..
fi

if [ ! "$(ls -A ~/c4ev3/ev3duder/hidapi)" ]; then
  echo "<<<Downloading hidapi>>>"
  git clone "https://github.com/signal11/hidapi"
fi

if [ ! -f "ev3duder" ]; then
  echo "<<<Installing ev3duder>>>"
  make
  sudo make install
fi
cd ..

if [ ! -f "projects/ev3-test/main.cpp" ]; then
  echo "<<<Creating example project>>>"
  mkdir -p projects
  cd projects
  mkdir -p ev3-test
  cd ev3-test
  mkdir -p output
  echo '#include <ev3.h>
#include <string>

int main() {
  InitEV3();
  
  std::string greeting("Hello World!");
  
  LcdPrintf(1, "%s\n", greeting.c_str());
  Wait(2000);
  
  FreeEV3();
}' >main.cpp
  cd ..
  cd ..
fi

if [ ! -f "projects/ev3-test/bu.sh" ]; then
  echo "<<<Creating build/upload script>>>"
  cd projects
  cd ev3-test
  echo '#!/bin/bash
PNAME="${PWD##*/}"
if arm-c4ev3-linux-uclibcgnueabi-g++ *.cpp -std=c++17 -Wall -Wextra -pedantic-errors -lpthread -Os -o "output/$PNAME" -I$HOME/c4ev3/ev3duder/EV3-API/API/ $HOME/c4ev3/ev3duder/EV3-API/API/libev3api.a ; then
  echo "Build successful."

  echo "Upload via USB or WiFi [U/w]? "
  read method
  comm=""
  if [ "$method" == "w" ]; then
    echo "Enter the IP address of the EV3: "
    read ip
    comm="--tcp=$ip"
  else
    comm="--usb"
  fi

  cd output
  ev3 $comm up "$PNAME" "../prjs/SD_Card/$PNAME/$PNAME"
  ev3 $comm mkrbf "../prjs/SD_Card/$PNAME/$PNAME" "$PNAME.rbf"
  ev3 $comm up "$PNAME.rbf" "../prjs/SD_Card/$PNAME/$PNAME.rbf"
fi' >bu
  chmod u+x bu
fi

echo "<<<Done! Put all project files in a folder with the project name, then run the bu script in the same directory>>>"
