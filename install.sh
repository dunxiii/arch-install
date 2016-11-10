#!/usr/bin/env bash
set -e

# TODO Ask user for cryptphrase
# TODO Ask user for pw, for user and root
# TODO If partitions exist, what do we do?
# TODO Dualboot flow

SECONDS=0

source ./hosts/base.sh
#source ./hosts/test/conf.sh
#source ./hosts/zentux/conf.sh

export HOSTNAME
export USER
export TIMEZONE
export KEYMAP
export LOCALE
export SHELL
export LC_ALL

prepare_disk() {

echo -e "\nPreparing devices"
echo -e "----------------------------------------"

# Make disk GPT
parted --script ${DEV} mklabel gpt

# Partition for ESP
parted --script ${DEV} mkpart ESP fat32 1MiB 513MiB
parted --script ${DEV} set 1 boot on
mkfs.fat -F32 "${DEV_BOOT}"

# Partition for data
parted --script ${DEV} mkpart primary 513MiB 100%
parted --script ${DEV} set 2 lvm on

# Encrypt data partition
echo -n "test" | cryptsetup -y luksFormat ${DEV_CRYPT} -

# Open encrypted disk
echo -n "test" | cryptsetup open --type luks ${DEV_CRYPT} lvm -d -

# Create Volume Group on disk
vgcreate vg /dev/mapper/lvm

# Create Logical Vomlumes
for i in "${!volumes[@]}"; do

    if [[ "${i}" == swap ]]; then
    	lvcreate -L "${volumes[$i]}" vg -n "${i}"
    else
    	lvcreate -L "${volumes[$i]}" vg -n "${i}"

        # Make filesystems
        mkfs.ext4 "/dev/vg/${i}"

    fi

done

# Mount root
mount "${DEV_ROOT}" "${MOUNT_POINT}"

# Make directory for ESP
mkdir -p "${MOUNT_POINT}/boot/efi"

# Mount ESP
mount "${DEV_BOOT}" "${MOUNT_POINT}/boot/efi"

# Crypt file to not have to give passphrase two times
dd bs=512 count=4 if=/dev/urandom of="${MOUNT_POINT}/crypto_keyfile.bin"
chmod 000 "${MOUNT_POINT}/crypto_keyfile.bin"
echo -n "test" | cryptsetup luksAddKey "${DEV_CRYPT}" "${MOUNT_POINT}/crypto_keyfile.bin" -d -

# Enable swap
mkswap "${DEV_SWAP}"
swapon "${DEV_SWAP}"

}

update_mirrors() {

echo -e "\nUpdating mirrors"
echo -e "----------------------------------------"

pacman -Syy

pacman --noconfirm -S reflector

reflector --sort score --threads 5 -a 10 -c SE -c DK -c NO -c FI -n 15 --save /etc/pacman.d/mirrorlist

pacman -Syy

}

install_packages() {

echo -e "\nInstalling packages"
echo -e "----------------------------------------"

pacstrap "${MOUNT_POINT}" base base-devel "${pacstrap_packages[@]}"

}

configure_base() {

echo -e "\nConfiguring base"
echo -e "----------------------------------------"

genfstab -U "${MOUNT_POINT}" >> "${MOUNT_POINT}/etc/fstab"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<'EOB'

    # locale & keymap
    echo "en_US.UTF-8 UTF-8"    >> /etc/locale.gen
    echo "LANG=${LOCALE}"       >  /etc/locale.conf
    echo "KEYMAP=${KEYMAP}"     >  /etc/vconsole.conf
    locale-gen

    # time
    ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    ntpd -qg
    hwclock --systohc --utc

    # hostname
    hostname "${HOSTNAME}"
    echo "${HOSTNAME}" > /etc/hostname
    sed -i "s/\(localhost$\)/\1 ${HOSTNAME}/" /etc/hosts

    # CPU cores for compiling from AUR
    sed -i -re "/^#MAKEFLAGS/a MAKEFLAGS=\"-j$(( $(nproc) + 1 ))\"" /etc/makepkg.conf

    # colored pacman output
    sed -i "/^#Color/a Color" /etc/pacman.conf

    # initramfs
    sed -i -re "/^HOOKS=/s/block/block encrypt lvm2/g"          /etc/mkinitcpio.conf
    sed -i -re "s/(FILES=)[^=]*$/\1\"\/crypto_keyfile.bin\"/"   /etc/mkinitcpio.conf

    # disable coredump
    sed -i -re "/^#Storage/a Storage=none" /etc/systemd/coredump.conf

    # initramfs
    mkinitcpio -P

    # Allow users in wheel to run sudo, without password
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)

EOB

cp templates/*.target "${MOUNT_POINT}/etc/systemd/system/"
cp templates/*.service "${MOUNT_POINT}/etc/systemd/system/"

for service in templates/*.service; do
    systemd_services+=(
        $(basename "${service}")
    )
done

}

install_python() {

echo -e "\nInstalling python packages"
echo -e "----------------------------------------"

for pkg in "${pip_packages[@]}"; do
    arch-chroot "${MOUNT_POINT}" /bin/bash -c "LC_ALL=en_US.utf8 pip3 install ${pkg}"
done

}

install_bootloader() {

echo -e "\nInstalling bootloader"
echo -e "----------------------------------------"

UUID=$(blkid -s UUID -o value "${DEV_CRYPT}")

cp templates/grub "${MOUNT_POINT}/etc/default/grub"
cp templates/custom.cfg "${MOUNT_POINT}/boot/grub/"

sed -i -e "s,\[DEV_CRYPT\],${UUID}," "${MOUNT_POINT}/etc/default/grub"
sed -i -e "s,\[DEV_CRYPT\],${UUID}," "${MOUNT_POINT}/boot/grub/custom.cfg"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<EOB

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub

    grub-mkconfig -o /boot/grub/grub.cfg

EOB

}

create_creation() {

echo -e "\nCreating user"
echo -e "----------------------------------------"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<EOB

    useradd -m -G "${USER_GROUPS}" -s "${SHELL}" "${USER}"

    echo "root:123" | chpasswd
    echo "${USER}:123" | chpasswd

EOB

}

configure_user_home() {

echo -e "\nConfiguring users home directory"
echo -e "----------------------------------------"

# Execute these commands as user
arch-chroot "${MOUNT_POINT}" /bin/bash -c "su - ${USER}" <<'EOB'

    # Get scripts
    git clone https://github.com/dunxiii/desktop-scripts.git ~/Git/desktop-scripts

    # Switch git repo from https to ssh
    cd ~/Git/desktop-scripts && git remote set-url origin git@github.com:dunxiii/desktop-scripts.git

    # Setup user
    ~/Git/desktop-scripts/setup-user.sh

EOB

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<EOB

    /home/${USER}/Git/desktop-scripts/install.sh

EOB

}

install_aur_packages() {

echo -e "\nInstalling AUR packages"
echo -e "----------------------------------------"

# Disable compression of aur packages
sed -i -re "s/(PKGEXT=)[^=]*$/\1'.pkg.tar'/" "${MOUNT_POINT}/etc/makepkg.conf"

# AUR Helper: pacaur
arch-chroot "${MOUNT_POINT}" /bin/bash -c "su - ${USER}" <<EOB

    cd Downloads

    for pkg in cower pacaur; do
    	curl -o PKGBUILD "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=\${pkg}"
    	makepkg PKGBUILD --skippgpcheck > /dev/null
    	sudo pacman -U \${pkg}*.pkg.tar --noconfirm
    done

    cd .. && rm -rf Downloads/*

    pacaur --noconfirm -y "${aur_packages[@]}" > /dev/null
EOB

# Empty pacaur cache
rm -rf "${MOUNT_POINT}/home/${USER}/.cache/pacaur/"

# Enable compression of aur packages
sed -i -re "s/(PKGEXT=)[^=]*$/\1'.pkg.tar.xz'/" "${MOUNT_POINT}/etc/makepkg.conf"

}

enable_services() {

echo -e "\nEnabling services"
echo -e "----------------------------------------"

for service in "${systemd_services[@]}"; do
    arch-chroot "${MOUNT_POINT}" /bin/bash -c "systemctl enable ${service}"
done

# And we are done
umount -l "${MOUNT_POINT}"

}

finish() {

echo -e "\nYour system is now ready!"
echo -e "----------------------------------------"
echo -e "Password for root and ${USER} is: 123"
echo -e "Reboot into your new system"

}

main() {

    prepare_disk
    update_mirrors
    install_packages
    configure_base
    install_python
    configure_extra # Found in host file
    install_bootloader
    create_creation
    configure_user_home
    install_aur_packages
    enable_services
    finish

}

main
echo -e "\nTotal time:"
echo -e "----------------------------------------"
echo -e "$((${SECONDS} / 60))m $((${SECONDS} % 60))s"

exit 0
