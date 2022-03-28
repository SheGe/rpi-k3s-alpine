#!/bin/sh
set -e
export INSTALL_K3S_SKIP_START="true"

install_k3s(){
  K3S_SCRIPT="/tmp/k3os_install.sh"
  wget -qO ${ROOTFS_PATH}${K3S_SCRIPT} https://get.k3s.io
  chroot_exec chmod 755 $K3S_SCRIPT
  # echo "Setting k3s log location to $K3S_LOG_DIR"
  # sed -i "s;LOG_FILE=/var/log/\${SYSTEM_NAME}.log;LOG_FILE=/data/var/log/\${SYSTEM_NAME}.log;g" ${ROOTFS_PATH}/${K3S_SCRIPT}
  echo "Installing k3os..."
  chroot_exec $K3S_SCRIPT
  echo "Done"
  chroot_exec rm -f $K3S_SCRIPT
  install ${INPUT_PATH}/k3s_init_rc ${ROOTFS_PATH}/etc/init.d/k3s
  chroot_exec chmod 755 /etc/init.d/k3s
  echo "Installed custom k3s init script"

}

check_abs_path(){
  CHAR=$(echo $1 | cut -c1)
  if [ $CHAR == "/" ]
  then
    True
  else
    echo "$1 is not an absolute path"
    False
  fi
}

map_to_data(){
  DATA_DIR="/data"
  for SRC_PATH in "$@"
  do
    # SRC_PATH should be absolute or this will exit
    if ! check_abs_path $SRC_PATH
    then
      exit 1
    fi
    rm -rf ${ROOTFS_PATH}${SRC_PATH}
    echo "Running 'mkdir -p ${DATAFS_PATH}${SRC_PATH}'"
    mkdir -p ${DATAFS_PATH}${SRC_PATH}
    ln -fs ${DATA_DIR}${SRC_PATH} ${ROOTFS_PATH}${SRC_PATH} && echo "Created symlink from ${DATA_DIR}${SRC_PATH} to ${ROOTFS_PATH}${SRC_PATH}"
  done
}
  
install_extras(){
  PKG="$@"
  echo "Installing $PKG..."
  chroot_exec apk add --no-cache $PKG
  echo "Done"
}

bind_mount(){
  for path in "$@"
  do
    SRC=$path
    if check_abs_path $path
    then
      exit 1
    fi
    FULL_SRC=${ROOTFS_PATH}${path}
    DST=/data${path}
    FULL_DST=${DATAFS_PATH}${path}
    echo "Creating bind mount for $path..."
    if [ -z $path ] || [ ! -d $FULL_SRC ]
    then
      echo "SRC=$SRC, FULL_SRC=$FULL_SRC"
      echo "ls -l $FULL_SRC:"
      ls -l $FULL_SRC
      echo "ERROR: bind_mount missing SRC (destination is created on /data)"
      exit 1
    fi
    echo "Copying contents from $FULL_SRC to $FULL_DST..."
    mkdir -p $FULL_DST
    cp -a $FULL_SRC $FULL_DST
    echo "Done"

    echo "Creating bind mount: $SRC will be mounted at $DST"
    echo "$DST   $SRC    none    defaults,bind       0 0" >> ${ROOTFS_PATH}/etc/fstab.update
    done
}

main(){
  # map_to_data /var/lib/rancher /var/lib/kubelet /var/log 
  install_k3s
  # map_to_data /etc/rancher
  install_extras nfs-utils openssh-client-common
  chroot_exec rc-update add cgroups default
  bind_mount /var/lib /var/log /etc/rancher
  install -D ${INPUT_PATH}/bind_mount.sh ${ROOTFS_PATH}/sbin/bindmounts
  sed -i 's;# make sure /data is mounted;/sbin/bindmounts' ${ROOTFS_PATH}/etc/init.d/data_prepare
}

if [ ! -z $ROOTFS_PATH ] && [ ! -z $DATAFS_PATH ]
then
  main
else
    echo "ROOTFS_PATH and DATAFS_PATH are not set - this is not meant to be run outside image buliding"
    exit 1
fi
