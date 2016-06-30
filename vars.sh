#!/usr/bin/env bash

JOBS=5

USER="jack"
HOSTNAME="zentux"
TIMEZONE="Europe/Stockholm"
KEYMAP="sv-latin1"
LOCALE="en_US.UTF-8"
LC_ALL="C"
SHELL=/usr/bin/zsh

MOUNT_POINT=/mnt
DEV_BOOT=/dev/sda1
DEV_CRYPT=/dev/sda2
DEV_ROOT=/dev/mapper/vg-arch
DEV_SWAP=/dev/mapper/vg-swap

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
    arandr
    btrfs-progs
    compton
    cups
    feh
    firewalld
    git
    grub
    i3-wm
    i3lock
    network-manager-applet
    networkmanager
    openssh
    parcellite
    pavucontrol
    polkit-gnome
    pulseaudio
    redshift
    reflector
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
    vim
    virtualbox
    virtviewer
    zathura-pdf-mupdf

    # Fonts
    ttf-dejavu
    ttf-ubuntu-font-family

    # i3pystatus deps
    wireless_tools

    # virtualbox deps
    linux-headers
    qt4

    # redshift-gtk deps
    python-gobject

    # Sysadmin
    bind-tools
    ipcalc
    nfs-utils
    nmap
    pass
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
    basiciw
    colour
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
    remmina-git
    rofi-git
    ttf-font-awesome
#    hunspell-sv
)
