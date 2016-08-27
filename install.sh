#!/usr/bin/env bash
set -e

SECONDS=0

source ./hosts/zenbook.sh
source ./disk-layouts.sh

export HOSTNAME
export USER
export TIMEZONE
export KEYMAP
export LOCALE
export SHELL
export LC_ALL

unmount_devices() {

echo -e "\nUnmounting devices:"
echo -e "----------------------------------------"

umount --verbose --lazy "${MOUNT_POINT}" || true
swapoff --all

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
sed -i "/^#${LOCALE} UTF-8/s/^#//" /etc/locale.gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
locale-gen

# time
ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc --utc

# hostname
hostname "${HOSTNAME}"
echo "${HOSTNAME}" > /etc/hostname
sed -i "s/\(localhost$\)/\1 ${HOSTNAME}/" /etc/hosts

# CPU cores for compiling from AUR
sed -i "/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf
sed -i -re "s/(MAKEFLAGS=)[^=]*$/\1\"-j$(( $(nproc) + 1 ))\"/" /etc/makepkg.conf

# colored pacman output
sed -i "/^#Color/s/^#//" /etc/pacman.conf

# initramfs
sed -i "/^HOOKS=/s/block/block encrypt lvm2/g" /etc/mkinitcpio.conf
sed -i -re "s/(FILES=)[^=]*$/\1\"\/crypto_keyfile.bin\"/" /etc/mkinitcpio.conf

# initramfs
mkinitcpio -P

# sudo
echo "%sudo ALL=(ALL:ALL) ALL" | (EDITOR="tee -a" visudo)

ln -s /run/media/ /media

EOB

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

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<EOB

# Configure GRUB
sed -i -re 's,^(GRUB_CMDLINE_LINUX=)[^=]*$,\1"cryptdevice=UUID=$(blkid -s UUID -o value "${DEV_CRYPT}"):cryptroot",' /etc/default/grub
sed -i -re 's/(GRUB_CMDLINE_LINUX_DEFAULT=)[^=]*$/\1"quiet loglevel=3 acpi_osi="/' /etc/default/grub
sed -i -re 's/(GRUB_TIMEOUT=)[^=]*$/\10/' /etc/default/grub
sed -i '/^#GRUB_HIDDEN_TIMEOUT=/s/^#//' /etc/default/grub
sed -i -re 's/(GRUB_HIDDEN_TIMEOUT=)[^=]*$/\13/' /etc/default/grub
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

if [[ "${UEFI}" = false ]]; then
    grub-install /dev/sda
else
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
fi

grub-mkconfig -o /boot/grub/grub.cfg

EOB

}

create_user() {

echo -e "\nCreating user"
echo -e "----------------------------------------"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<EOB

groupadd sudo

useradd -m -G "${USER_GROUPS}" -s "${SHELL}" "${USER}"

EOB

}

configure_user_home() {

echo -e "\nConfiguring users home directory"
echo -e "----------------------------------------"

# Execute these commands as user
arch-chroot "${MOUNT_POINT}" /bin/bash -c "su - ${USER}" <<'EOB'

# Create default directories
xdg-user-dirs-update

# Extra directories
mkdir -p ~/{Bin,Git,Insync,.vim/undodir}

# Get dotfiles and scripts
git clone https://github.com/dunxiii/dotfiles.git ~/Git/dotfiles
git clone https://github.com/dunxiii/desktop-scripts.git ~/Git/desktop-scripts

# Deploy dotfiles
~/Git/dotfiles/install

# Switch git repos from https to ssh
cd ~/Git/dotfiles && git remote set-url origin git@github.com:dunxiii/dotfiles.git
cd ~/Git/desktop-scripts && git remote set-url origin git@github.com:dunxiii/desktop-scripts.git

# Install oh my zsh
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/Git/oh-my-zsh
ln -s ~/Git/oh-my-zsh ~/.oh-my-zsh

# Install vim-plug
curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

EOB

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<EOB

cd /home/${USER}/Git/desktop-scripts/
./install.sh

EOB

}

install_aur_packages() {

echo -e "\nInstalling AUR packages"
echo -e "----------------------------------------"

# Temporary sudoers
cp "${MOUNT_POINT}/etc/sudoers"{,.org}

# Disable compression of aur packages
sed -i -re "s/(PKGEXT=)[^=]*$/\1'.pkg.tar'/" "${MOUNT_POINT}/etc/makepkg.conf"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<'EOB'

# Workaround for aur package installation
echo "Defaults visiblepw" | (EDITOR="tee -a" visudo)
echo "%sudo   ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)

EOB

# AUR Helper: pacaur
arch-chroot "${MOUNT_POINT}" /bin/bash -c "su - ${USER}" <<EOB

    # Fix for cower
    gpg --recv-keys --keyserver hkp://pgp.mit.edu 1EB2638FF56C0C53

    source /etc/profile.d/perlbin.sh

    for pkg in ${pacaur_packages[@]}; do
        git clone "https://aur.archlinux.org/\${pkg}.git"
        cd "\${pkg}" && makepkg --noconfirm -sric
        cd .. && rm -rf "\${pkg}"
    done

    pacaur --noconfirm -y "${aur_packages[@]}"
EOB

# Empty pacaur cache
rm -rf "${MOUNT_POINT}/home/${USER}/.cache/pacaur/"

# Enable compression of aur packages
sed -i -re "s/(PKGEXT=)[^=]*$/\1'.pkg.tar.xz'/" "${MOUNT_POINT}/etc/makepkg.conf"

mv "${MOUNT_POINT}/etc/sudoers"{.org,}

}

enable_services() {

echo -e "\nEnabling services"
echo -e "----------------------------------------"

for pkg in "${systemd_services[@]}"; do
    arch-chroot "${MOUNT_POINT}" /bin/bash -c "systemctl enable ${pkg}"
done

}

cleanup() {

echo -e "\nCleanup files"
echo -e "----------------------------------------"

# Search for packages that are not longer required or dependencies
packages_to_clean=$(
    arch-chroot "${MOUNT_POINT}" /bin/bash -c 'pacman --query --quiet --unrequired --deps || true'
)

# Remove those packages
if [[ -n "${packages_to_clean}" ]]; then
    arch-chroot "${MOUNT_POINT}" /bin/bash -c \
        'pacman --noconfirm -Rs $( echo ${packages_to_clean} ) 2>/dev/null'
fi

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<EOB

echo "root:123" | chpasswd
echo "${USER}:123" | chpasswd

EOB

echo -e "\nYour system is now ready!"
echo -e "Password for root and ${USER} is: 123"
echo -e "Reboot into your new system"

}

main() {

    # Installation steps
    #-------------------
    unmount_devices
    "${DISK_LAYOUT}"
    update_mirrors
    install_packages
    configure_base
    install_python
    configure_extra
    install_bootloader
    create_user
    configure_user_home
    install_aur_packages
    enable_services
    cleanup

}

clear
main
echo -e "\nTotal time:"
echo -e "----------------------------------------"
echo -e "$((${SECONDS} / 60))m $((${SECONDS} % 60))s"

exit 0
