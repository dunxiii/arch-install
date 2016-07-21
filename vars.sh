#!/usr/bin/env bash
# vim: set foldmethod=marker:

JOBS=5

USER="jack"
HOSTNAME="zentux"
TIMEZONE="Europe/Stockholm"
KEYMAP="sv-latin1"
LOCALE="en_US.UTF-8"
LC_ALL="C"
SHELL=/usr/bin/zsh
UEFI=false
MOUNT_POINT=/mnt

#DISK_LAYOUT="btrfs_lvm_luks"
DISK_LAYOUT="btrfs_luks"

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
    btrfs-progs
    compton
    cups
    feh
    git
    grub
    i3-wm
    i3lock
    jq
    network-manager-applet
    networkmanager
    openssh
    parcellite
    pavucontrol
    polkit-gnome
    pulseaudio
    redshift
    reflector
    rofi
    scrot
    tlp
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
    #linux-headers
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
    ipcalc
    nfs-utils
    nmap
    pass
    remmina
    sshfs
    sshpass
    vagrant

    # Utilitys
    efibootmgr
    gparted
    ntfs-3g
    pv
    python-pip
    shellcheck
    subdownloader
    unrar
    unzip
)

pip_packages=(
    #setuptools
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
    chromium-pepper-flash
    gitkraken
    insync
    telegram-desktop-bin
    ttf-font-awesome
#    hunspell-sv
)

pacstrap_pre_packages=(
    virtualbox

    # if arch is run inside virtualbox
    virtualbox-guest-utils
)
# }}}

# Make systemd remeber display brightness after suspend
echo <<EOF > /usr/share/X11/xorg.conf.d/20-intel.conf
Section "Device"
    Identifier  "card0"
    Driver      "intel"
    Option      "Backlight"  "intel_backlight"
    BusID       "PCI:0:2:0"
EndSection
EOF
