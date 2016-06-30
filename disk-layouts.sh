#!/usr/bin/env bash

btrfs_lvm_luks() {

    echo -e "\nPreparing devices"
    echo -e "----------------------------------------"

    # Vars
    DEV_BOOT=/dev/sda1
    DEV_CRYPT=/dev/sda2
    DEV_ROOT=/dev/mapper/vg-arch
    DEV_SWAP=/dev/mapper/vg-swap

    ## Make filesystems
    mkfs.fat -F32 "${DEV_BOOT}"
    mkfs.btrfs -qf "${DEV_ROOT}"

    ## Mount partitions
    mount "${DEV_ROOT}" "${MOUNT_POINT}"
    btrfs subvolume create "${MOUNT_POINT}/ROOT"

    umount "${DEV_ROOT}"
    mount "${DEV_ROOT}" "${MOUNT_POINT}" -o ssd,compress=lzo,noatime,subvol=ROOT

    btrfs subvolume create "${MOUNT_POINT}/home"
    btrfs subvolume create "${MOUNT_POINT}/tmp"
    btrfs subvolume create "${MOUNT_POINT}/.snapshots"

    mkdir "${MOUNT_POINT}/boot"
    mount "${DEV_BOOT}" "${MOUNT_POINT}/boot"

    mkdir -p "${MOUNT_POINT}/mnt/btrfs"
    mount "${DEV_ROOT}" "${MOUNT_POINT}/mnt/btrfs"

    ## Enable swap
    mkswap "${DEV_SWAP}"
    swapon "${DEV_SWAP}"

}

# This setup should have a more correct btrfs layout for rollbacks
# https://bbs.archlinux.org/viewtopic.php?id=194491
btrfs_luks() {

    echo -e "\nPreparing devices"
    echo -e "----------------------------------------"

    DEV_BOOT=/dev/sda1
    DEV_SWAP=/dev/sda2
    DEV_CRYPT=/dev/sda3
    DEV_ROOT=/dev/mapper/cryptroot

    mkfs.fat -F32 "${DEV_BOOT}"
    mkfs.btrfs -qf "${DEV_ROOT}"

    # TODO Maybe have @arch_home... test current first
    mount "${DEV_ROOT}" "${MOUNT_POINT}"
    btrfs subvolume create "${MOUNT_POINT}/@arch"
    btrfs subvolume create "${MOUNT_POINT}/@arch_snapshots"

    mkdir -p "${MOUNT_POINT}/.snapshots"
    mkdir -p "${MOUNT_POINT}/boot"

    umount "${DEV_ROOT}"
    mount "${DEV_ROOT}" "${MOUNT_POINT}" -o ssd,compress=lzo,noatime,subvol=arch
    mount "${DEV_ROOT}" "${MOUNT_POINT}/.snapshots" -o ssd,compress=lzo,noatime,subvol=arch_snapshots
    mount "${DEV_BOOT}" "${MOUNT_POINT}/boot/efi"

    mkdir -p "${MOUNT_POINT}/var/cache/pacman"

    # TODO Maybe add: /dev /proc /sys /run /mnt /media
    btrfs subvolume create "${MOUNT_POINT}/home"
    btrfs subvolume create "${MOUNT_POINT}/srv"
    btrfs subvolume create "${MOUNT_POINT}/tmp"
    btrfs subvolume create "${MOUNT_POINT}/var/abs"
    btrfs subvolume create "${MOUNT_POINT}/var/cache/pacman/pkg"
    btrfs subvolume create "${MOUNT_POINT}/var/tmp"

    # TODO Maybe add crypto keyfile here, test current first

    ## Enable swap
    # TODO
}
