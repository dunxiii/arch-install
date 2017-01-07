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
volumes[swap]=1G
volumes[root]=5G

pacstrap_packages+=(
    # Drivers
    xf86-input-synaptics

    # Desktop base
    arc-gtk-theme
    i3-wm
    i3lock
    polkit-gnome

    # Desktop apps
    gnome-disk-utility
    terminator

    # Fonts
    ttf-dejavu
    ttf-ubuntu-font-family

    # i3pystatus deps
    wireless_tools
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
    ttf-font-awesome
)

virtualbox_guest() {
pacstrap_packages+=(
    virtualbox-guest-dkms           # for LTS kernel
    #virtualbox-guest-modules-arch  # for normal kernel
    virtualbox-guest-utils
)

systemd_services+=(
    vboxservice.service
)
}

virtualbox_guest

configure_extra() {

echo -e "\nConfiguring extra"
echo -e "----------------------------------------"

# acpid
\cp -fb hosts/zenbook/templates/handler.sh "${MOUNT_POINT}/etc/acpi/"

# logind
echo -e "HandlePowerKey=ignore\nHandleLidSwitch=ignore" >> "${MOUNT_POINT}/etc/systemd/logind.conf"

# Iptables
cp hosts/zenbook/templates/iptables.rules "${MOUNT_POINT}/etc/iptables/"

}
