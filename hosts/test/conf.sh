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
volumes[arch]=3G

pacstrap_packages+=(
    # Drivers
    xf86-input-synaptics

    # Desktop base
    i3-wm
    i3lock
    polkit-gnome

    # Desktop apps
    gnome-disk-utility
    terminator

    # Fonts
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

configure_extra() {

echo -e "\nConfiguring extra"
echo -e "----------------------------------------"

# acpid
mv "${MOUNT_POINT}/etc/acpi/handler.sh" "${MOUNT_POINT}/etc/acpi/handler.sh.org"
cp hosts/zenbook/templates/handler.sh "${MOUNT_POINT}/etc/acpi/"

# logind
echo -e "HandlePowerKey=ignore\nHandleLidSwitch=ignore" >> "${MOUNT_POINT}/etc/systemd/logind.conf"

# Iptables
cp hosts/zenbook/templates/iptables.rules "${MOUNT_POINT}/etc/iptables/"

}
