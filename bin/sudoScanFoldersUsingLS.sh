#!/bin/bash

set -uo pipefail  # Ensure pipe failures propagate properly, python need this to work.

set -e
#set -x

echo Running $0 $@ 

# make sure $3 is not empty and is a number
if [[ -z "$2" || ! "$2" =~ ^[0-9]+$ ]] || [[ -z "$3" || ! "$3" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <sourceDir> <nProcess> <realFolderCount: might from starfish>"
    exit 1
fi

[ -d "$1" ] || { echo "Source directory $1 does not exist."; exit 1; }

sDir=`realpath $1` # should looks like /n/data/someFolder/.snapshot/standby_data/251201

if [[ "$sDir" != *"TestingData"* ]]; then
  [[ "$sDir" != *"snapshot"* ]] && { echo "Source directory is not snapshot folder"; exit 1; }
  limit=200
  dDir=`basename $sDir`
else 
  limit=2
  dDir=`basename $sDir`
fi

logDir="pass1"

mkdir -p $logDir

nProc="$2"

folderCount="$3"

folders="$logDir/folders.txt"

if [ -f $folders ]; then 
  echo Folder file already exist. Do you want to rename it as: $folders.$(date '+%Y-%m-%d_%H-%M-%S_%4N')? 
  echo "Continue? (y/)"
  read -p "" xx </dev/tty;

  if [[ "$xx" == y ]]; then 
  
   mv $folders $folders.$(date '+%Y-%m-%d_%H-%M-%S_%4N') || exit 1
  else
   echo "Please backup or remove $folders and rerun the script."
   exit 1
  fi 
fi 

dFolderTmp=$(mktemp -d $logDir/tmp.XXXXXX)

tempFile=$(mktemp $logDir/tmpfile.XXXXXX)

#trap "pkill -f 'sleep'; pkill -f 'sudo -v'; rm -r $dFolderTmp $tempFile $tempFile.txt  $tempFile.*.err $tempFile.*.txt 2>/dev/null;" EXIT

#sudo ls -l "$sDir" 2>/dev/null | grep "^d" | awk -v dir="$sDir" '{print 0 "\t" dir "/" $9}' > $tempFile

sudo ls -lA "$sDir" 2>/dev/null | grep "^d" | awk -v dir="$sDir" '{for(i=9;i<=NF;i++) printf "%s%s", (i==9?"":OFS), $i; print ""}' | awk -v dir="$sDir" '{print 0 "\t" dir "/" $0}' > $tempFile
                
#sudo ls -l "$sDir" 2>/dev/null | grep "^d" | awk '{print 0 "\t" $sDir/$9}' > $tempFile
count=$(wc -l < "$tempFile")
if [ "$count" -le $limit ]; then 
#    cat "$tempFile" >> $tempFile.0.txt
#else
    for i in {1..10}; do 
        #set -x 
        echo "Working on ${i}th level..."
        [ -f "$tempFile" ] && rm "$tempFile"  
        sudo find "$sDir" -mindepth $i -maxdepth $i -type d 2>> $tempFile.0.err | while read -r dir; do  
          printf "%s\n" "Working on $dir"
          count=$(sudo ls -lA "$dir" 2>/dev/null | awk '!/^d/ && !/^total/ {print $9}' | wc -l)
          printf "%s\t%s\n" "$count" "$dir" >> "$tempFile"
        done
        [ -f $tempFile ] && x=$(wc -l < "$tempFile")  || x=0 
        
        [ "$x" -lt $limit ] || break

        [ -f "$tempFile" ] &&  cat "$tempFile" >> $tempFile.0.txt
        #sleep 2
    done 
fi 

#cat "$tempFile.0.txt"

echo "Finding all subfolders in parallel, limited to $nProc concurrent processes..."

if [ -f "$tempFile" ]; then 
  cat -n "$tempFile" 
  cut -d$'\t' -f2 "$tempFile" | tr '\n' '\0' | \
xargs -0 -P "$nProc" -I "{}" bash -c '
    printf "%s\n" "Processing $2";
    tmpFile=$(mktemp -p "$1" process_XXXXXX.out);
    errFile="${tmpFile%.out}.err";

    sudo find "$2" -type d -print0 2>> "$errFile" | while IFS= read -r -d "" dir; do
      printf "%s\n" "Working on directory: $dir";
	count=$(sudo ls -lA "$dir" 2>/dev/null | awk '\''!/^d/ && !/^total/ {print $9}'\'' | wc -l)
	printf "%s\t%s\n" "$count" "$dir" >> "$tmpFile"
    done
  ' _ "$dFolderTmp" "{}"
fi   

cat "$dFolderTmp"/*.out > "$tempFile.1.txt" 2>/dev/null || echo Too less folders
cat "$dFolderTmp"/*.err > "$tempFile.1.err" 2>/dev/null || true 

echo "Parallel scan is done"

cat  $tempFile.*.txt > $folders.withCount

sort -nr $folders.withCount > $folders.withCount.sorted

echo "$sDir" > $folders 

cat $folders.withCount.sorted | cut -d$'\t' -f2 >> $folders

cp $folders $folders.back 

count=$(wc -l < $folders)

#rows_per_job=100000

cat $tempFile.*.err >&2

echo "First 5 rows of $folders:": 
head -n 5 $folders

if [[ $count -ne $folderCount ]]; then
    echo "Error: Folder count mismatch. Expected $folderCount, acutal $count."
    echo "Please check the error file $tempFile.*.err for details."
    echo "The folder list is saved in $folders"
    #exit 1
else 
    echo "Folder count matches expected value: $folderCount. Total folders found: $count."
fi

if [[ $count -gt 10000 ]]; then 
  echo "Warning: Found $count folders, which is more than 10000. Let me split the folder list into 6 parts:"
  nJobs=6; #$(( (count + rows_per_job - 1) / rows_per_job ))

  for jIndex in $(seq 1 $nJobs); do
    echo $logDir/folders_part_$jIndex
    awk -v jIndex="$jIndex" -v nJobs="$nJobs" '( NR - 1 ) % nJobs == jIndex - 1' "$logDir/folders.txt" > "$logDir/folders_part_$jIndex"
  done
fi
count=$(sudo find "$sDir" -maxdepth 1 -type f -o -type l | wc -l)
printf "%s\t%s\n" "$count" "$sDir" >> $folders.withCount

echo "Total number of files (should be the same as the number of files in starfish):"
awk '{sum += $1} END {print sum}' $folders.withCount
