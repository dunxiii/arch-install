#!/usr/bin/env bash
# vim: set foldmethod=marker:

USER="jack"
USER_GROUPS="wheel,lp"
HOSTNAME="zentux"
TIMEZONE="Europe/Stockholm"
KEYMAP="sv-latin1"
LOCALE="en_US.UTF-8"
SHELL=/usr/bin/zsh
DEV=/dev/sda
DEV_BOOT=${DEV}1
DEV_CRYPT=${DEV}2
DEV_ROOT=/dev/vg/root
DEV_SWAP=/dev/vg/swap

declare -A volumes
volumes[swap]=8G
volumes[root]=20G
volumes[home]=380G

# {{{ Packages
pacstrap_packages+=(
    # Drivers
    xf86-input-synaptics

    # Desktop base
    arc-gtk-theme
    i3-wm
    i3lock
    polkit-gnome
    tlp

    # Bluetooth
    #blueman
    #bluez
    # TODO test if firmware is needed
    #bluez-firmware
    #bluez-utils
    #pulseaudio-bluetooth

    # Desktop apps
    chromium
    gcolor2
    gnome-calculator
    gnome-disk-utility
    gthumb
    libreoffice-still
    smplayer
    speedtest-cli
    terminator
    transmission-gtk
    virt-viewer
    youtube-dl
    zathura-pdf-mupdf

    # Fonts
    ttf-dejavu
    ttf-ubuntu-font-family

    # i3pystatus deps
    wireless_tools

    # Sysadmin
    remmina freerdp intltool
)

pip_packages+=(
    basiciw
    colour
    i3ipc
    i3pystatus
    netifaces
    psutil
)

aur_packages+=(
    #bcm20702a1-firmware
    #gitkraken
    #hunspell-sv
    #telegram-desktop-bin
    insync
    openfortivpn
    ttf-font-awesome
)
# }}}
# {{{ Services
systemd_services+=(
    #bluetooth.service
    tlp.service
)
# }}}

docker_host() {
    pacstrap_packages+=(
        docker
    )
    systemd_services+=(
        docker.service
    )
    USER_GROUPS="${USER_GROUPS},docker"
}
virtualbox_host() {
    virtualbox_host=false
    pacstrap_packages+=(
        qt4
        vagrant
        virtualbox # Newer virtualbox is broken with i3,
        # workaround in configure_extra below
    )
}
kvm_host() {
    pacstrap_packages+=(
        bridge-utils
        dnsmasq
        ebtables
        openbsd-netcat
        qemu-headless
        virt-manager
    )
    systemd_services+=(
        libvirtd.service
    )
    USER_GROUPS="${USER_GROUPS},kvm,libvirt"
}

docker_host
virtualbox_host
kvm_host

# {{{ Config functions
configure_extra() {

echo -e "\nConfiguring extra"
echo -e "----------------------------------------"

# acpid
\cp -fb hosts/zenbook/templates/handler.sh "${MOUNT_POINT}/etc/acpi/"

# TLP
sed -i.org -e "s/radeon nouveau/radeon mei_me nouveau/" "${MOUNT_POINT}/etc/default/tlp"

# logind
echo -e "HandlePowerKey=ignore\nHandleLidSwitch=ignore" >> "${MOUNT_POINT}/etc/systemd/logind.conf"

# Iptables
cp hosts/zenbook/templates/iptables.rules "${MOUNT_POINT}/etc/iptables/"

# Make systemd remeber display brightness after suspend
cp hosts/zenbook/templates/20-intel.conf "${MOUNT_POINT}/usr/share/X11/xorg.conf.d/"

# Touchpad config
cp hosts/zenbook/templates/70-synaptics.conf "${MOUNT_POINT}/etc/X11/xorg.conf.d/"

# Touchpad auto disable
cp hosts/zenbook/templates/01-touchpad.rules "${MOUNT_POINT}/etc/udev/rules.d/"
sed -i -e "s/\[USER\]/${USER}/" "${MOUNT_POINT}/etc/udev/rules.d/01-touchpad.rules"

# Systemd files
cp hosts/zenbook/templates/systemd/* "${MOUNT_POINT}/etc/systemd/system/"

# Enable said services later
for service in hosts/zenbook/templates/systemd/*.service; do
    systemd_services+=(
        "${service}"
    )
done

# Pacman hooks
mkdir -p "${MOUNT_POINT}/etc/pacman.d/hooks"
cp hosts/zenbook/templates/hooks/* "${MOUNT_POINT}/etc/pacman.d/hooks/"

# TODO run in chroot
if [[ "${virtualbox_host}" == true ]]; then
    wget http://download.virtualbox.org/virtualbox/5.0.30/VirtualBox-5.0.30-112061-Linux_amd64.run
    chmod +x VirtualBox-5.0.30-112061-Linux_amd64.run
    ./VirtualBox-5.0.30-112061-Linux_amd64.run
    rm VirtualBox-5.0.28-111378-Linux_amd64.run
    wget http://download.virtualbox.org/virtualbox/5.0.30/Oracle_VM_VirtualBox_Extension_Pack-5.0.30-112061.vbox-extpack
    VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack-5.0.30-112061.vbox-extpack
fi

}
# }}}
