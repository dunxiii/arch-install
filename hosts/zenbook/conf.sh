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
DEV_ROOT=/dev/vg/arch
DEV_SWAP=/dev/vg/swap

declare -A volumes
volumes[swap]=1G
volumes[arch]=5G

# {{{ Packages
pacstrap_packages+=(
    # Drivers
    xf86-input-synaptics

    # Desktop base
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
    #chromium
    gcolor2
    #gnome-calculator
    #gnome-disk-utility
    #gthumb
    #libreoffice-still
    #smplayer
    terminator
    #transmission-gtk
    #virtviewer
    #zathura-pdf-mupdf

    # Fonts
    ttf-dejavu
    ttf-ubuntu-font-family

    # i3pystatus deps
    wireless_tools

    # Sysadmin
    #remmina freerdp intltool
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
    #gitkraken
    #insync
    #telegram-desktop-bin
    #hunspell-sv
    #bcm20702a1-firmware
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
    pacstrap_packages+=(
        qt4
        vagrant
        virtualbox
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

#docker_host
#virtualbox_host
kvm_host

# {{{ Config functions
configure_extra() {

echo -e "\nConfiguring extra"
echo -e "----------------------------------------"

# acpid
mv "${MOUNT_POINT}/etc/acpi/handler.sh" "${MOUNT_POINT}/etc/acpi/handler.sh.org"
cp hosts/zenbook/templates/handler.sh "${MOUNT_POINT}/etc/acpi/"

# TLP
sed -i.org -e "s/radeon nouveau/radeon mei_me nouveau/" "${MOUNT_POINT}/etc/default/tlp"

# logind
echo -e "HandlePowerKey=ignore\nHandleLidSwitch=ignore" >> "${MOUNT_POINT}/etc/systemd/logind.conf"

# Iptables
cp hosts/zenbook/templates/iptables.rules "${MOUNT_POINT}/etc/iptables/"

# Make systemd remeber display brightness after suspend
#cp  hosts/zenbook/templates/20-intel.conf "${MOUNT_POINT}/usr/share/X11/xorg.conf.d/"

# Touchpad config
cp hosts/zenbook/templates/70-synaptics.conf "${MOUNT_POINT}/usr/share/X11/xorg.conf.d/"

# Touchpad auto disable
cp hosts/zenbook/templates/01-touchpad.rules "${MOUNT_POINT}/etc/udev/rules.d/"
sed -i -e "s/\[USER\]/${USER}/" "${MOUNT_POINT}/etc/udev/rules.d/01-touchpad.rules"

}
# }}}
