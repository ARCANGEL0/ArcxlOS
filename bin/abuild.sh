#!/bin/bash

VERSION="v0.1.1"

FALSE="0"
TRUE="1"

SUCCESS="1337"
FAILURE="31337"

VERBOSE="/dev/null"

WHITE="$(tput bold ; tput setaf 7)"
GREEN="$(tput setaf 2)"
RED="$(tput bold; tput setaf 1)"
YELLOW="$(tput bold ; tput setaf 3)"
NC="$(tput sgr0)"


wprintf() {
    fmt=$1
    shift
    printf "%s${fmt}%s\n" "${WHITE}" "$@" "${NC}"

    return "${SUCCESS}"
}

warn()
{
    printf "%s[!] WARNING: %s%s\n" "${RED}" "${*}" "${NC}"

    return "${SUCCESS}"
}

err()
{
    printf "%s[-] ERROR: %s%s\n" "${RED}" "${*}" "${NC}"

    return "${SUCCESS}"
}

cri()
{
    printf "%s[-] CRITICAL: %s%s\n" "${RED}" "${*}" "${NC}"

    exit "${FAILURE}"
}


usage()
{
    printf "%s" "${WHITE}"
    cat <<EOF
Usage: $0 <arg> | <misc>
OPTIONS:
    -a <ARCH>: build.sh only one arch
ARCH:
    i686
    x86_64
MISC:
    -V: print version and exit
    -H: print help and exit
EOF
    printf "%s" "${NC}"

    exit "${SUCCESS}"
}

banner()
{
    printf "%s--==[ BlackArch build.sh Wrapper by nrz@nullsecurity.net ]==--%s\n" "${YELLOW}" "${NC}"

    return "${SUCCESS}"
}

check_env()
{
    return "${SUCCESS}"
}

check_argc()
{
    if [ ${#} -lt "1" ]; then
        usage
    fi

    return "${SUCCESS}"
}

check_args()
{
    return "${SUCCESS}"
}

build_arch()
{
    arch=${1}

    case "${arch}" in
        "i686")
            wprintf "[+] Setting i686 configuration..."
            sed -i 's/dual/i686/' build.sh
            sed -i 's/for arch in i686 x86_64\; do/for arch in i686\; do/' build.sh
            sed -i 's/run_once make_efi/#run_once make_efi/' build.sh
            sed -i 's/run_once make_efiboot/#run_once make_efiboot/' build.sh
            sed -i 's|archiso_sys64.cfg|archiso_sys32.cfg|' syslinux/archiso_sys_both_inc.cfg
            ;;
        "x86_64")
            wprintf "[+] Setting x86_64 configuration..."
            sed -i 's/dual/x86_64/' build.sh
            sed -i 's/for arch in i686 x86_64\; do/for arch in x86_64\; do/' build.sh
            sed -i 's|archiso_sys32.cfg|archiso_sys64.cfg|' syslinux/archiso_sys_both_inc.cfg
            ;;
    esac

    wprintf "[+] Done! Building ISO..."
    ./build.sh -v

    return "${SUCCESS}"
}

get_opts()
{
    while getopts a:vVH flags
    do
        case "${flags}" in
            a)
                optarg=${OPTARG}
                opt="arch"
                ;;
            v)
                VERBOSE="/dev/stdout"
                ;;
            V)
                printf "%s\n" "${VERSION}"
                exit "${SUCCESS}"
                ;;
            H)
                usage
                ;;
            *)
                err "WTF?! mount /dev/brain"
                ;;
        esac
    done

    return "${SUCCESS}"
}


main()
{
    banner
    check_argc ${*}
    get_opts ${*}
    check_args ${*}
    check_env

    if [ "${opt}" == "arch" ]; then
        build_arch "${optarg}"
    fi

    return "${SUCCESS}"
}


main ${*}

