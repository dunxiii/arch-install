#!/bin/bash
set -e

SECONDS=0

source ./vars.sh

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

# TODO finish
# TODO rename, make another for other setup?

prepare_devices() {

echo -e "\nPreparing devices"
echo -e "----------------------------------------"

## Make filesystems
mkfs.fat -F32 "${DEV_BOOT}"
mkfs.btrfs -f "${DEV_ROOT}"

## Mount partitions
mount "${DEV_ROOT}" "${MOUNT_POINT}"
btrfs subvolume create "${MOUNT_POINT}/ROOT"

umount "${DEV_ROOT}"
mount "${DEV_ROOT}" "${MOUNT_POINT}" -o ssd,compress=lzo,noatime,subvol=ROOT

btrfs subvolume create "${MOUNT_POINT}/home"
btrfs subvolume create "${MOUNT_POINT}/tmp"

mkdir "${MOUNT_POINT}/{boot,home,tmp}"

mount "${DEV_BOOT}" "${MOUNT_POINT}/boot"
mount "${DEV_ROOT}" "${MOUNT_POINT}" -o ssd,compress=lzo,noatime,subvol=home
mount "${DEV_ROOT}" "${MOUNT_POINT}" -o ssd,compress=lzo,noatime,subvol=tmp

## Enable swap
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

install_base() {

echo -e "\nInstalling base packages"
echo -e "----------------------------------------"

pacstrap "${MOUNT_POINT}" base base-devel btrfs-progs

}

configure_base() {

echo -e "\nConfiguring base"
echo -e "----------------------------------------"

# fstab
genfstab -U "${MOUNT_POINT}" >> "${MOUNT_POINT}/etc/fstab"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<'EOF'

locale

# locale & keymap
sed -i "/^#${LOCALE} UTF-8/s/^#//" /etc/locale.gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
locale-gen

# time
ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc --utc

# hostname
echo "${HOSTNAME}" > /etc/hostname
sed -i "s/\(localhost$\)/\1 ${HOSTNAME}/" /etc/hosts

# CPU cores for compiling from AUR
sed -i "/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf
sed -i -re "s/(MAKEFLAGS=)[^=]*$/\1\"-j${JOBS}\"/" /etc/makepkg.conf

# colored pacman output
sed -i "/^#Color/s/^#//" /etc/pacman.conf

# initramfs
sed -i "/^HOOKS=/s/block/block encrypt lvm2/g" /etc/mkinitcpio.conf

# BTRFS fix
sed -i "/^HOOKS=/s/fsck/btrfs/g" /etc/mkinitcpio.conf

# initramfs
mkinitcpio -p linux

# sudo
chmod u+w /etc/sudoers
sed -i "/^# %sudo   ALL=(ALL) ALL/s/^# //" /etc/sudoers
chmod u-w /etc/sudoers

EOF

}

install_extra() {

echo -e "\nInstalling extra packages"
echo -e "----------------------------------------"

pacstrap "${MOUNT_POINT}" "${pacstrap_packages[@]}"
arch-chroot "${MOUNT_POINT}" /bin/bash -c "pip3 install ${pip_packages[@]}"

}

configure_extra() {

echo -e "\nConfiguring extra"
echo -e "----------------------------------------"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<'EOF'

# TLP
sed -i -re 's/(RUNTIME_PM_DRIVER_BLACKLIST=)[^=]*$/\1"radeon mei_me nouveau"/' "/etc/default/tlp"

# acpi
declare -A ACPI_HANDLER_VALUE=(
    ["Default acpi"]='user=$(ps -o user --no-headers $(pgrep startx))'
    ["LID closed"]='DISPLAY=:0 su $user -c \"i3-exit.sh -l\"'
    ["i3-exit.sh"]='systemctl suspend'
    ["LID opened"]='DISPLAY=:0 su $user -c \"xset dpms force on\"'
)

for line in "${!ACPI_HANDLER_VALUE[@]}"; do
    gawk -i inplace '{print} /'"${line}"'/{ print substr($0,1,match($0,/[^[:space:]]/)-1) "'"${ACPI_HANDLER_VALUE[${line}]}"'" }' "/etc/acpi/handler.sh"
done

# logind
for line in "HandlePowerKey" "HandleLidSwitch="; do
    sed -i '/^#'${line}'/s/^#//' /etc/systemd/logind.conf
done

declare -A ASSING_VALUE=(
    ["HandlePowerKey"]="ignore"
    ["HandleLidSwitch"]="ignore"
)

for line in ${!ASSING_VALUE[@]}; do
    sed -i -re 's/('${line}'=)[^=]*$/\1'${ASSING_VALUE[${line}]}'/' /etc/systemd/logind.conf
done

# users-dirs
for dir in DESKTOP TEMPLATES MUSIC VIDEOS; do
    sed -i -re "/${dir}/s/^/#/" /etc/xdg/user-dirs.defaults
done

ln -s /run/media /media

EOF

}

install_bootloader() {

echo -e "\nInstalling bootloader"
echo -e "----------------------------------------"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<'EOF'

# Install GRUB as bootloader
#grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-install /dev/sda
sed -i -re 's/(GRUB_CMDLINE_LINUX_DEFAULT=)[^=]*$/\1"quiet loglevel=3 acpi_osi="/' /etc/default/grub

# Configure GRUB
sed -i -re 's,^(GRUB_CMDLINE_LINUX=)[^=]*$,\1"cryptdevice=UUID=$(blkid -s UUID -o value "${DEV_CRYPT}"):lvm",' /etc/default/grub
sed -i -re 's/(GRUB_TIMEOUT=)[^=]*$/\10/' /etc/default/grub
sed -i '/^#GRUB_HIDDEN_TIMEOUT=/s/^#//' /etc/default/grub
sed -i -re 's/(GRUB_HIDDEN_TIMEOUT=)[^=]*$/\13/' /etc/default/grub

# Make config
grub-mkconfig -o /boot/grub/grub.cfg

EOF

}

create_user() {

echo -e "\nCreating user"
echo -e "----------------------------------------"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<'EOF'

groupadd sudo

useradd -m -G sudo -s $(which zsh) "${USER}"

[[ $(which virtualbox 2>/dev/null) ]] && gpasswd -a "${USER}" vboxusers

EOF

}

configure_user_home() {

echo -e "\nConfiguring users home directory"
echo -e "----------------------------------------"

# Execute these commands as user
arch-chroot "${MOUNT_POINT}" /bin/bash -c "su - ${USER}" <<'EOF'

# Create default directories
xdg-user-dirs-update

# Extra directories
mkdir -p ~/{Bin,Git,Insync,.vim/undodir}

# Get dotfiles
git clone https://github.com/dunxiii/dotfiles.git ~/Git/dotfiles

# Swhitch dotfiles from https to ssh
cd ~/Git/dotfiles && git remote set-url origin git@github.com:dunxiii/dotfiles.git

# Install oh my zsh
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/Git/oh-my-zsh
cp -r ~/Git/oh-my-zsh ~/.zshrc

# Install vim-plug
curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

EOF

}

install_aur_packages() {

echo -e "\nInstalling AUR packages"
echo -e "----------------------------------------"

# USER need to source vars
cp ./vars.sh "${MOUNT_POINT}/home/${USER}/"
cp ./vars.sh "${MOUNT_POINT}/root/"

# TODO: test and remove -x
arch-chroot "${MOUNT_POINT}" /bin/bash -ex <<'EOF'

# TODO: remove??
#source ~/vars.sh

# Temporary sudoers
cp /etc/sudoers{,.org}
chmod u+w /etc/sudoers
echo "Defaults visiblepw" >> /etc/sudoers
echo "%sudo   ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod u-w /etc/sudoers

# AUR Helper: pacaur
su -s /bin/bash - ${USER} <<'EOC'

    # Fix for cower
    gpg --recv-keys --keyserver hkp://pgp.mit.edu 1EB2638FF56C0C53

    source /etc/profile.d/perlbin.sh
    source ~/vars.sh

    for pkg in "${pacaur_packages[@]}"; do
        git clone "https://aur.archlinux.org/${pkg}.git"
        cd "${pkg}" && makepkg --noconfirm -sric
        cd .. && rm -rf "${pkg}"
    done

    pacaur --noconfirm -y "${aur_packages[@]}"
EOC

mv /etc/sudoers{.org,}

EOF

}

enable_services() {

echo -e "\nEnabling services"
echo -e "----------------------------------------"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<EOF

systemctl enable NetworkManager.service
systemctl enable acpid.service
systemctl enable sshd.service
systemctl enable tlp

EOF

}

cleanup() {

echo -e "\nCleanup files"
echo -e "----------------------------------------"

rm -rf "${MOUNT_POINT}/root/*.sh"
rm -rf "${MOUNT_POINT}/home/${USER}/*.sh"

#arch-chroot "${MOUNT_POINT}" /bin/bash -c 'pacman -Rs $(pacman -Qqtd) 2>/dev/null' || true

echo -e "Your system is now ready!"
echo -e "Now set password for root and ${USER}"
echo -e "And then just reboot into your new system"

}

echo -e "\n"

unmount_devices
prepare_devices
#update_mirrors
#install_base
#configure_base
#install_extra
#configure_extra
#install_bootloader
#create_user
#configure_user_home
#install_aur_packages
#enable_services
#cleanup

echo -e "\nTotal time:"
echo -e "----------------------------------------"
echo -e "$((${SECONDS} / 60))m $((${SECONDS} % 60))s"

exit 0
