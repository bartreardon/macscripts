#!/bin/bash

# Script to take an OS X partition, clean it up and prepare an image for use with System Image Utility

# Uesage - makeimage /path/to/partition
# Result - a file called system.dmg in the directory root.
# not sure what would happen if you forgot the command line argument...probably bad things. <- not any more :) BR 22-9-11
# Written by Bart Reardon 2011.

# example:
# sudo ./makeimage.sh /Volumes/partition

#check that we have an argument and that it points to a valid partition
correctUsage="USEAGE: ./makeimage.sh /Volumes/partition"

if [ $# -ne 1 ]
then
	echo $correctUsage
	exit 1
else
	if [ -d $1 ]
	then
		#probably a cleaner way to do this but meh
		if [ $1 == "/Volumes" -o $1 == "/Volumes/" -o $1 == "Volumes/" -o $1 == "Volumes" ]
		then
			echo "You need to specify a partition"
			echo $correctUsage
			exit 1
		fi
		
		echo "*** Specified $1"
		
		#strip trailing "/" if present
		lchr=$(echo ${1:(-1)})
		if [ $lchr == "/" ]
		then
			sourcePartition=$(echo $1 | sed 's/.$//')
		else
			sourcePartition=$1
		fi
		
		drive=`df | grep $sourcePartition | awk '{print $1}'`
		
		if [ ${#drive} -lt 1 ]
		then
			echo "Not a valid partition"
			echo $correctUsage
			exit 1
		fi
		
		echo "*** Using $drive"
	else
		echo "$1 is not a valid directory"
		echo $correctUsage
		exit 1
	fi
fi


echo "It's best to run this script as sudo."
echo "It will work if you don't but will prompt you for passwords along the way."

#drive=`df | grep $1 | awk '{print $1}'`
#echo "*** Using $drive\n"


#perform deep clean of the volume
echo "*** Performing a deep clean of the volume"
sudo rm -rf $sourcePartition/Users/*/Library/Caches/*
sudo rm -rf $sourcePartition/Library/Caches/*
sudo rm -rf $sourcePartition/System/Library/Extensions/Caches/*
sudo rm -rf $sourcePartition/System/Library/Extensions.mkext
sudo rm -rf $sourcePartition/System/Library/Caches/*
sudo rm -rf $sourcePartition/private/var/db/BootCache.playlist

#delete swap files and hybernation files
echo "*** Deleting swap and hibernation files"
sudo rm $sourcePartition/var/vm/s*

# This section for adding or deleting things to the partition before we make the image
# e.g. copy in any launchagents, touch a build file, modify user templates etc

#update the build file. create a new one if it doesn't exist
#buildFile="$sourcePartition/etc/build.txt"
#if [ -f $buildFile ]
#then
#	newBuild=$(awk '/Release: [0-9]+/ { printf "Release: %d\n", $2+1 }' < $buildFile)
#	echo "*** Mac OS X BOE $newBuild"
#	echo $newBuild > $buildFile
#else
#	echo "*** Mac OS X BOE Initial Build (edit /etc/build.txt to update). Using build number 100"
#	echo "Release: 100" > $buildFile
#fi

#copy over the dock and desktop prefrences from the mactemplate user to the default user template
# will add more in here as needed
#echo "*** Copying dock, desktop and pictures to default user template"
#sudo cp $sourcePartition/Users/mactemplate/Library/Preferences/com.apple.dock.* $sourcePartition/System/Library/User\ Template/English.lproj/Library/Preferences/
#sudo cp $sourcePartition/Users/mactemplate/Library/Preferences/com.apple.desktop.* $sourcePartition/System/Library/User\ Template/English.lproj/Library/Preferences/
#sudo cp $sourcePartition/Users/mactemplate/Pictures/*.jpg $sourcePartition/System/Library/User\ Template/English.lproj/Pictures/
#sudo cp $sourcePartition/Users/mactemplate/.anyconnect $sourcePartition/System/Library/User\ Template/English.lproj/


#unmount the drive then repair catalogue file
echo "*** Unmounting and doing a volume repair"
sudo diskutil unmount $sourcePartition/

# we need to use fsck instead of diskutil because the latter doesn't fix the problems with the catalog b-tree
sudo fsck_hfs -r $drive

#create disk image
echo "*** Making a block level copy and saving to /System.dmg"
sudo hdiutil create /System.dmg -format UDZO -nocrossdev -srcdevice $drive

#scan disk image
echo "*** Perform image scan so the image is restorable"
sudo asr imagescan --filechecksum --allowfragmentedcatalog -source /System.dmg
#sudo asr imagescan --filechecksum -source /$drive.dmg

#change the permissions on the System.dmg file
chmod 664 /System.dmg
echo "*** Permissions changed to 664"

#move the image to the desktop
mv /System.dmg ~/Desktop/ 
echo "*** Moved to ~/Desktop"

#re-mount the drive
echo "*** Re-mounting the drive"
sudo diskutil mount $drive

#image creation complete.
echo "**All done."
