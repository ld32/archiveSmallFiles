#!/bin/bash

usage() {
    echo "Usage: $0 <pass to check, for example: pass2>"; exit 1;
}

date
echo Running $0 $@ 

#set -x 

logDir=$1

if [ ! -f $logDir/folders.txt ]; then 
    echo Folder scan is not done yet!
    exit 1
fi 

sFolder=`head -n 1 $logDir/folders.txt`

cat $logDir/done.$logDir.*.txt $logDir/done.check.*.txt | sort | uniq > $logDir/done.all.txt 

grep -Fxv -f $logDir/done.all.txt $logDir/folders.txt > $logDir/notDoneFolders.txt 

grep -Fxv -f $logDir/folders.txt $logDir/done.all.txt  > $logDir/extraDoneFolders.txt

if [ -s $logDir/extraDoneFolders.txt ]; then 
    echo "There are folders in done.all.txt that are not in folders.txt"
    echo "Check $logDir/extraDoneFolders.txt for details"
else
    rm $logDir/extraDoneFolders.txt
fi

if [ -s $logDir/notDoneFolders.txt ]; then 
    echo "There are folders infolders.txt that are not in done.all.txt"
    echo "Check $logDir/notDoneFolders.txt for details"
else
    rm $logDir/notDoneFolders.txt
fi

echo "Actual folders: $(wc -l < $logDir/folders.txt)"

echo "Done folders: $(wc -l < $logDir/done.all.txt)"
[ -f $logDir/extraDoneFolders.txt ] && echo "Extra done folders: $(wc -l < $logDir/extraDoneFolders.txt)"


if [ -f $logDir/notDoneFolders.txt ]; then 
    echo "Not done folders: $(wc -l < $logDir/notDoneFolders.txt)"
    
    nextPass=pass$(( ${logDir#pass} + 1 ))

    if [ -f $logDir/$nextPass.folders.txt ]; then 
        echo "Next pass folders.txt already exists. It is renamed."
        mv $logDir/$nextPass.folders.txt $logDir/$nextPass.folders.txt.$(date '+%Y-%m-%d_%H-%M-%S_%4N')
    fi

    head -n 1 $logDir/folders.txt > $logDir/$nextPass.folders.txt

    cat $logDir/notDoneFolders.txt >> ${logDir/$pass/$nextPass}/folders.txt

    echo "Not done folders are saved to ${logDir/$logDir/$nextPass}/folders.txt."

    echo "You can run the next pass now: $nextPass"

fi 


