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

cat $logDir/done.check.$logDir.*.txt | sort | uniq > $logDir/done.all.txt 

grep -Fxv -f $logDir/done.all.txt $logDir/folders.txt > $logDir/notDoneFolders.txt 

grep -Fxv -f $logDir/folders.txt $logDir/done.all.txt  > $logDir/extraDoneFolders.txt

if [ -s $logDir/extraDoneFolders.txt ]; then 
    echo "There are folders in done.all.txt that are not in folders.txt"
    echo "Check $logDir/extraDoneFolders.txt for details"
else
    rm $logDir/extraDoneFolders.txt
fi

if [ -s $logDir/notDoneFolders.txt ]; then 
    echo "There are folders in folders.txt that are not in done.all.txt"
    echo "Check $logDir/notDoneFolders.txt for details"
else
    rm $logDir/notDoneFolders.txt
fi

echo $logDir | tee -a summary 

echo "Archive checking results:" | tee -a summary

echo "Actual folders in $logDir/folders.txt: $(wc -l < $logDir/folders.txt)" | tee -a summary

echo "Done folders: $(wc -l < $logDir/done.all.txt)" | tee -a summary

[ -f $logDir/extraDoneFolders.txt ] && echo "Extra done folders: $(wc -l < $logDir/extraDoneFolders.txt)"


if [ -f $logDir/notDoneFolders.txt ]; then 
    echo "Not done folders: $(wc -l < $logDir/notDoneFolders.txt)"
    
    nextPass=pass$(( ${logDir#pass} + 1 ))

    if [ -f $nextPass/folders.txt ]; then 
        echo "Next pass folders.txt already exists. It is renamed."
        mv $nextPass/folders.txt $nextPass/folders.txt.$(date '+%Y-%m-%d_%H-%M-%S_%4N')
    fi

    if [ ! -d $nextPass ]; then 
        mkdir -p $nextPass
    fi

    # Check if the first row is the same
    first1=$(head -n 1 $logDir/folders.txt)
    first2=$(head -n 1 $logDir/notDoneFolders.txt)
    if [[ "$first1" != "$first2" ]]; then
        head -n 1 $logDir/folders.txt > $nextPass/folders.txt
    fi

    cat $logDir/notDoneFolders.txt >> $nextPass/folders.txt

    echo "Not done folders are saved to $nextPass/folders.txt."
    echo 
    echo "Please review logs and see what is the issue:" 
    echo "\$ cat $logDir/tarError*"
    echo
    echo "If there is permission issues, please run:" 
    echo "\$ sudoCorrectPermission.sh $nextPass 4"
    echo
    echo "Aftet that, you can run the next pass: $nextPass"
    echo "\$ checkArchives.sh tar local/sbatch $nextPass"

fi 

cat $logDir/done.check.$logDir.*.withCount | sort | uniq > $logDir/done.all.withCount

echo "Total number of original files:" | tee -a summary
awk '{sum += $1} END {printf "%'\''d\n", sum}' $logDir/done.all.withCount | tee -a summary

echo "Total number of files if we  untar all the data (should be the same as untarred file count):" | tee -a summary 
awk '{sum += $2} END {printf "%'\''d\n", sum}' $logDir/done.all.withCount | tee -a summary 

echo "Total number of files after tarring (should be the same the number of files in tarred folder in starfish):" | tee -a summary 
awk '{sum += $3} END {printf "%'\''d\n", sum}' $logDir/done.all.withCount | tee -a summary 


