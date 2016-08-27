#!/usr/bin/env bash
# vim: set foldmethod=marker:

USER="jack"
USER_GROUPS="sudo,vboxusers,docker,lp"
HOSTNAME="zentux"
TIMEZONE="Europe/Stockholm"
KEYMAP="sv-latin1"
LOCALE="en_US.UTF-8"
LC_ALL="C"
SHELL=/usr/bin/zsh
UEFI=false
VM=true
MOUNT_POINT=/mnt

DISK_LAYOUT="lvm_luks"
#DISK_LAYOUT="btrfs_lvm_luks"
#DISK_LAYOUT="btrfs_luks"

# {{{ Packages
pacstrap_packages=(
    # Drivers
    libva-intel-driver
    libvdpau-va-gl
    mesa-libgl
    vulkan-intel
    xf86-input-synaptics
    xf86-video-intel

    # Desktop base
    acpid
    borg python-llfuse
    compton
    connman
    cups
    dosfstools
    dunst
    expect
    feh
    git
    grub
    i3-wm
    i3lock
    jq
    linux-headers
    linux-lts
    linux-lts-headers
    openssh
    parcellite
    pavucontrol
    polkit-gnome
    ppp
    pulseaudio
    redshift
    reflector
    rofi
    rsync
    scrot
    tlp
    wpa_supplicant
    xclip
    xcursor-vanilla-dmz
    xdg-user-dirs
    xorg-server
    xorg-server-utils
    xorg-utils
    xorg-xinit
    zsh
    zsh-completions
    zsh-syntax-highlighting

    # Bluetooth
    blueman
    bluez
    # TODO test if firmware is needed
    #bluez-firmware
    bluez-utils
    pulseaudio-bluetooth

    # Desktop apps
    chromium
    gcolor2
    gnome-calculator
    gnome-disk-utility
    gthumb
    htop
    libreoffice-still
    ncdu
    neovim
    ranger
    smplayer
    terminator
    transmission-gtk
    virtviewer
    zathura-pdf-mupdf

    # Fonts
    ttf-dejavu
    ttf-ubuntu-font-family

    # i3pystatus deps
    wireless_tools

    # virtualbox and denpendencies
    qt4
    virtualbox

    # if arch is run inside virtualbox
    #virtualbox-guest-modules-arch
    #virtualbox-guest-utils

    # redshift-gtk deps
    python-gobject

    # remmina copy paste fix
    intltool

    # Sysadmin
    bind-tools
    docker
    ipcalc
    nfs-utils
    nmap
    pass
    remmina freerdp
    sshfs
    sshpass
    vagrant

    # Utilitys
    efibootmgr
    gparted
    ntfs-3g
    python-pip
    unrar
    unzip
)

pip_packages=(
    basiciw
    colour
    i3ipc
    i3pystatus
    netifaces
    psutil
)

pacaur_packages=(
    cower
    pacaur
)

aur_packages=(
    #chromium-pepper-flash
#    gitkraken
    #insync
    #telegram-desktop-bin
    ttf-font-awesome
#    hunspell-sv
    #bcm20702a1-firmware
)
# }}}
# {{{ Services
systemd_services=(
    acpid.service
    bluetooth.service
    connman.service
    docker.service
    iptables.service
    sshd.service
    tlp.service
)
# }}}
# {{{ Config functions
configure_extra() {

echo -e "\nConfiguring extra"
echo -e "----------------------------------------"

arch-chroot "${MOUNT_POINT}" /bin/bash -e <<'EOB'

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
sed -i '/^#HandlePowerKey/s/^#//' /etc/systemd/logind.conf
sed -i '/^#HandleLidSwitch=/s/^#//' /etc/systemd/logind.conf

sed -i -re 's/(HandlePowerKey=)[^=]*$/\1ignore/' /etc/systemd/logind.conf
sed -i -re 's/(HandleLidSwitch=)[^=]*$/\1ignore/' /etc/systemd/logind.conf

# users-dirs
for dir in DESKTOP TEMPLATES MUSIC VIDEOS; do
    sed -i -re "/${dir}/s/^/#/" /etc/xdg/user-dirs.defaults
done

# Base iptables file
cp /etc/iptables/{empty,iptables}.rules

# Make systemd remeber display brightness after suspend
echo <<EOF > /usr/share/X11/xorg.conf.d/20-intel.conf
Section "Device"
    Identifier  "card0"
    Driver      "intel"
    Option      "Backlight"  "intel_backlight"
    BusID       "PCI:0:2:0"
EndSection
EOF

EOB

}
# }}}
