#!/bin/bash
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM
#variables
scriptDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );

#source the function script
source "$scriptDir"/functions.sh
hash rsync lsof find xattr 2>/dev/null || echo "Requirements: rsync lsof find xattr"

[ -e "$scriptDir"/settings.conf ] && source "$scriptDir"/settings.conf||FINDOPTS=""


while getopts "ht:a:b:" option
do
     case $option in
         h)
             usage && exit
             ;;
         t)
             minfind="$OPTARG"
             ;;
         a)
             sourcedisk="${OPTARG%/}"
             ;;
	b)
             targetdisk="${OPTARG%/}"
             ;;

         ?)
             usage
	    exit 1
             ;;
     esac
done

[ -z "$sourcedisk" ] && exit 1
moveIdleFilesInPath "$sourcedisk" "$targetdisk"
