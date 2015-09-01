#!/bin/bash

set -e
DRYRUN="true"
minfind=60
path=
verbose=0

function usage() {
	echo "$0" [ -t MIN_MINUTES] -a PATH_TO_DRAIN [-b PATH_TO_FILL]
}
function getFirstDrive() {
	#$1 is the pool. Like /mergerfsVol_with_fwfs
	echo -n $(xattr -l "$1"/.mergerfs|grep srcmounts|cut -d" " -f2|cut -d":" -f1)
}

function getPoolFromDrive() {
	drive="$1"
	echo -n "$(df -k|grep $(basename "$drive")|grep -v "$drive"|awk '{print $6}')"
}

function getDriveFromPath(){
	echo -n $(df "$1"|tail -n1|awk '{print $6}')
}
function getDriveWithMostFreeSpace() {
	#$1 is the pool. Like /mergerfsVol_with_fwfs
	diskToDrain="$1"
	if [[ -z "$2" ]]; then
		pool="$(getPoolFromDrive "$diskToDrain")"
	else
		pool="$2"
	fi
	free=0
	drives=$(xattr -l "$pool"/.mergerfs|grep srcmounts|cut -d" " -f2| sed 's/:/\n/g')
	while read drive;do
		if [[ $drive == $diskToDrain ]];then
			continue;
		fi
		currentFree=$(df -k "$drive"|awk '/[0-9]%/{print $(NF-2)}')
		
		if [[ $currentFree -gt $free ]];then
			mostFreeDrive="$drive"
			free=$currentFree
		fi	
	done <<<"$drives"
	echo -n "$mostFreeDrive"
}

function moveIdleFilesInPath() {
	oldpwd=$PWD
	sourceFolder="$1"

	if [[ -z $2 ]]; then
		targetFolderSet=0
		#df "$sourceFolder"|tail -n1|grep "$sourceFolder" > /dev/null||echo "Without target folder, the source folder needs to be the root of the drive." && exit 1 #make sure sourceFolder is at root of disk.
		if ! df "$sourceFolder"|tail -n1|grep "$sourceFolder" > /dev/null;then
			echo "Without target folder, the source folder needs to be the root of the drive."
			exit 1
		fi
	else
		targetFolderSet=1
		targetFolder="$2"

		if [[ ! -e "$targetFolder" ]]; then
			echo "Target folder does not exist."
			exit 1
		fi

	fi

	rootOfSource="$(getDriveFromPath "$sourceFolder")"
	if [[ -z "$POOL" ]]; then
		POOL="$(getPoolFromDrive "$rootOfSource")"
		if [[ $(echo "$POOL" |wc -l) -gt 1 ]]; then
			echo "More than one pool with this drive. Use POOL in settings to specify."
			exit 1
		fi
	fi
	echo "Entering $sourceFolder. Scanning. Standby."
	# cd "$sourceFolder" && find . "${FINDOPTS[@]}" -type f  -mmin +$minfind -print0 | while read -d "" path;do
	cd "$sourceFolder" && find . "${FINDOPTS[@]}" -type f -mmin +$minfind -printf "%C@ %p\n" |sort|cut -d ' ' -f2-| while read path;do
		[[ -e "$path" ]] || continue #rsync can take a long time and files can have been moved
		lsof "$path" &> /dev/null && continue # move along if the file is in use
		#
		filesize=$(du -k "$path"|awk '{print $1}')

		#if no targetFolder is set, then find the one with most free space.
		if [[ $targetFolderSet -eq 0 ]]; then
			targetFolder=$(getDriveWithMostFreeSpace "$rootOfSource" $POOL)
		fi

		freeSpaceOnTarget=$(df -k "$targetFolder"|awk '/[0-9]%/{print $(NF-2)}')
		if [[ $filesize -lt $freeSpaceOnTarget ]];then
			echo ""$path" "$targetFolder"/"
			if [[ $DRYRUN == "false" ]]; then
				ionice rsync --remove-source-files -Rha --progress "$path" "$targetFolder"/
			fi
			sleep .5
			# exit

		else
			echo "Not enough space on target."
			cd $oldpwd && exit 1
		fi
	done
	cd $oldpwd
};
