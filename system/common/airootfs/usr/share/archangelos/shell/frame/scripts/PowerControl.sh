#!/usr/bin/env bash

case "$1" in
    shutdown)
        (setsid bash -c 'systemctl poweroff' &>/dev/null &);;
    reboot)
        (setsid bash -c 'systemctl reboot' &>/dev/null &);;
    logout)
        (setsid bash -c 'hyprctl dispatch "hl.dsp.exit()" >/dev/null 2>&1 || loginctl terminate-session "${XDG_SESSION_ID:-self}"' &>/dev/null &);;
    *)
        exit 1
        ;;
esac