#!/bin/bash

# ! This is just for testing !

swapoff --all
#umount --verbose --lazy "${MOUNT_POINT}"
umount --verbose --lazy /mnt
vgchange -an /dev/mapper/vg
vgremove /dev/mapper/vg --force
pvremove /dev/mapper/lvm --force
cryptsetup luksClose /dev/mapper/lvm
dd if=/dev/zero of=/dev/sda bs=512 count=1
