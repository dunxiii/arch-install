#!/usr/bin/env bash
# vim: set foldmethod=marker:

# {{{ Packages
pacstrap_packages+=(
    # Drivers
    libva-intel-driver
    libvdpau-va-gl
    mesa-libgl
    vulkan-intel
    xf86-video-intel
    intel-ucode

    # Desktop base
    #linux-headers # virtualbox?
    acpid
    atool # preview archive files
    bind-tools
    borg python-llfuse
    compton
    cups
    dosfstools
    dunst
    efibootmgr
    expect
    feh
    git
    gparted
    grub
    htop
    ipcalc
    jq # i3 script deps
    ncdu
    networkmanager
    nfs-utils
    nmap
    ntfs-3g
    ntp
    openssh
    parcellite
    pavucontrol
    pulseaudio
    python-pip
    ranger
    reflector
    redshift python-gobject
    rofi
    rsync
    scrot
    sshfs
    unrar
    unzip
    gvim
    wavemon
    wget
    wpa_supplicant
    xclip
    xcursor-vanilla-dmz
    xorg-server
    xorg-server-utils
    xorg-xev
    xorg-xinit
    xorg-xprop
    yajl expac # pacaur deps
    zsh
    zsh-completions
    zsh-syntax-highlighting
)

aur_packages+=(
    #gitkraken
    #insync
    #telegram-desktop-bin
    #hunspell-sv
    #bcm20702a1-firmware
    pepper-flash
    udftools
)
# }}}
# {{{ Services
systemd_services+=(
    acpid.service
    NetworkManager.service
    ntpd.service
    iptables.service
    sshd.service
)
# }}}

virtualbox_guest() {
pacstrap_packages+=(
    # Virtualbox guest
    virtualbox-guest-modules-arch
    virtualbox-guest-utils
)

systemd_services+=(
    vboxservice.service
)
}

virtualbox_guest
