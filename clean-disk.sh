#!/bin/bash

# ! This is just for testing !

swapoff --all
#umount --verbose --lazy "${MOUNT_POINT}"
umount --verbose --lazy /mnt
vgchange -an /dev/mapper/vg
pvremove /dev/mapper/lvm --force --force
cryptsetup luksClose /dev/mapper/lvm
dd if=/dev/zero of=/dev/sda bs=512 count=1
