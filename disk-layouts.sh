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

    DEV_BOOT=/dev/sda1
    DEV_SWAP=/dev/sda2
    DEV_CRYPT=/dev/sda3
    DEV_ROOT=/dev/mapper/cryptroot

    if [[ ! "${1}" = POST ]]; then

        echo -e "\nPreparing devices"
        echo -e "----------------------------------------"

        mkfs.fat -F32 "${DEV_BOOT}"
        mkfs.btrfs -qf "${DEV_ROOT}"

        mount "${DEV_ROOT}" "${MOUNT_POINT}"
        btrfs subvolume create "${MOUNT_POINT}/@arch"
        btrfs subvolume create "${MOUNT_POINT}/@arch_snapshots"

        umount "${DEV_ROOT}"
        mount "${DEV_ROOT}" "${MOUNT_POINT}" -o ssd,noatime,subvol=@arch

        mkdir -p "${MOUNT_POINT}/.snapshots"
        mkdir -p "${MOUNT_POINT}/boot/efi"

        mount "${DEV_ROOT}" "${MOUNT_POINT}/.snapshots" -o ssd,noatime,subvol=@arch_snapshots
        mount "${DEV_BOOT}" "${MOUNT_POINT}/boot/efi"

        mkdir -p "${MOUNT_POINT}/var/cache/pacman"

        btrfs subvolume create "${MOUNT_POINT}/home"
        btrfs subvolume create "${MOUNT_POINT}/srv"
        btrfs subvolume create "${MOUNT_POINT}/tmp"
        btrfs subvolume create "${MOUNT_POINT}/var/abs"
        btrfs subvolume create "${MOUNT_POINT}/var/cache/pacman/pkg"
        btrfs subvolume create "${MOUNT_POINT}/var/tmp"

        # Crypt file to not have to give passphrase two times
        dd bs=512 count=4 if=/dev/urandom of="${MOUNT_POINT}/crypto_keyfile.bin"
        chmod 000 "${MOUNT_POINT}/crypto_keyfile.bin"
        cryptsetup luksAddKey "${DEV_CRYPT}" "${MOUNT_POINT}/crypto_keyfile.bin"

    else

        echo -e "\nPreparing devices finishing up"
        echo -e "----------------------------------------"

        # Enable swap
        sed -i "/swap/s/^# //" "${MOUNT_POINT}/etc/crypttab"
        sed -i "/swap/s/sdx4/${DEV_SWAP/*\//}/" "${MOUNT_POINT}/etc/crypttab"

        echo "/dev/mapper/swap	none      	swap      	defaults  	0 0" >> "${MOUNT_POINT}/etc/fstab"

        sed -i -re "s/(FILES=)[^=]*$/\1\"\/crypto_keyfile\.bin\"/" "${MOUNT_POINT}/etc/mkinitcpio.conf"
    fi
}
