# Some diffirent setups

## LVM on LUKS

With this setup the layout will be:

    /dev/sda1 ESP
    /dev/sda2 Linux filesystem

### Partition disk

Use cfdisk or any other modern partitioning tool.

    sda1 ESP 8M (EFI System)
    sda2 Linux filesystem 100%FREE

### Encrypt partiton

    cryptsetup luksFormat /dev/sda2
    cryptsetup open --type luks /dev/sda2 lvm

### Setup LVM

    pvcreate /dev/mapper/lvm
    vgcreate vg /dev/mapper/lvm
    lvcreate -L 8G vg -n swap
    lvcreate -L 120G vg -n arch

### Install system

From scripts folder
- Configure: vars.sh
- Run: install.sh
- Default password for user and root are: 123
- Reboot and start using the system

## Btrfs on LVM on LUKS

With this setup the layout will be:

    /dev/sda1 ESP
    /dev/sda2 Linux filesystem

### Partition disk

Use cfdisk or any other modern partitioning tool.

    sda1 ESP 512M (EFI System)
    sda2 Linux filesystem 100%FREE

### Encrypt partiton

    cryptsetup luksFormat /dev/sda2
    cryptsetup open --type luks /dev/sda2 lvm

### Setup LVM

    pvcreate /dev/mapper/lvm
    vgcreate vg /dev/mapper/lvm
    lvcreate -L 8G vg -n swap
    lvcreate -L 120G vg -n arch

### Install system

From scripts folder
- Configure: vars.sh
- Run: install.sh
- Default password for user and root are: 123
- Reboot and start using the system

## Btrfs on LUKS

With this setup the layout will be:

    /dev/sda1 ESP                 unencrypted /boot/efi
    /dev/sda2 Linux filesystem    plain encrypted (SWAP)
    /dev/sda3 Linux filesystem    LUKS /

### Partition disk

Use cfdisk or any other modern partitioning tool.

    sda1 ESP 512M (EFI System)
    sda2 Linux filesystem 8192M
    sda3 Linux filesystem 100%FREE

### Encrypt partiton

    cryptsetup luksFormat /dev/sda3
    cryptsetup open /dev/sda3 cryptroot

### Install system

From scripts folder
- Configure: vars.sh
- Run: install.sh
- Default password for user and root are: 123
- Reboot and start using the system
