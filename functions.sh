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

function getDriveWithMostFreeSpace() {
	#$1 is the pool. Like /mergerfsVol_with_fwfs
	diskToDrain="$1"
	if [[ -z $POOL ]]; then
		pool="$getPoolFromDrive "$diskToDrain""
	else
		pool="$POOL"
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
		df "$sourceFolder"|tail -n1|grep "$sourceFolder" > /dev/null||echo "Without target folder, the source folder needs to be the root of the drive." && exit 1 #make sure sourceFolder is at root of disk.
	else
		targetFolderSet=1
		targetFolder="$2"
	fi
	echo "entering $sourceFolder. Target is $targetFolder"
	cd "$sourceFolder" && find . "${FINDOPTS[@]}" -type f  -mmin +$minfind -print0 | while read -d "" path;do
		[[ -e "$path" ]] || continue #rsync can take a long time and files can have been moved
		lsof "$path" &> /dev/null && continue # move along if the file is in use
		filesize=$(du -k "$path"|awk '{print $1}')

		if [[ $targetFolderSet -eq 0 ]]; then
			targetFolder=$(getDriveWithMostFreeSpace "$sourceFolder")
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
			echo "Not enough space."
			cd $oldpwd && exit 1
		fi
	done
	cd $oldpwd
};
