#!/bin/bash

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM
export TOP_PID=$$
#variables
scriptDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );

#source the function script
source "$scriptDir"/functions.sh
hash rsync ionice lsof find xattr 2>/dev/null || echo "Requirements: rsync lsof find xattr"

[ -e "$scriptDir"/settings.conf ] && source "$scriptDir"/settings.conf||FINDOPTS=(-not -path "./staticfolder/*")
while getopts "ht:a:b:" option
do
    case $option in
        h)
            usage && exit
        ;;
        t)
            minfind="$OPTARG" #in minutes how long time files must be to be processed.
        ;;
        a)
            sourcePath="${OPTARG%/}"
        ;;
        b)
            targetPath="${OPTARG%/}"
        ;;

        ?)
            usage
            exit 1
        ;;
    esac
done

[ -z "$sourcePath" ] && exit 1
moveIdleFilesInPath "$sourcePath" "$targetPath"
