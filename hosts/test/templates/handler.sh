#!/bin/bash
# Default acpi script that takes an entry for all actions

case "$1" in
    button/lid)
        case "$3" in
            close)
                logger 'LID closed'
                CUR_USER=$(ps -o user --no-headers $(pgrep startx))
                DISPLAY=:0 su ${CUR_USER} -c "i3-exit.sh -s"
                ;;
            open)
                logger 'LID opened'
                ;;
        esac
    ;;
esac

# vim:set ts=4 sw=4 ft=sh et:
