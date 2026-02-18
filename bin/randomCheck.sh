#!/bin/bash

set -o pipefail  # Ensure pipe failures propagate properly, python need this to work.

usage() {
    echo "Usage: $0 <action: tar/zar> <Pass to check, for example: pass2><number Of Paths To Check, for example: 1000>"; exit 1;
}

date

#set -x 

echo Running $0 $@ 

action="$1" 
if [[ "$action" == zar* ]]; then 
        module load miniconda3
        conda activate zar 
fi 

pass="$2"

count="$3"

[[ ! -z "$3" && ! "$3" =~ ^[0-9]+$ ]] && { echo "Error: numberOfPathToCheck must be a number"; usage; }

sFolder=`head -n 1 $pass/folders.txt`

[[ "$sFolder" == *"TestingData"* ]] || [[ "$sFolder" == *snapshot* ]] || { echo "Error: source folder $1 does not contain .snapshot"; usage; } 

#export baseDir=${sFolder%/.snapshot*} #/n/groups/marks/projects

#export snapshotDir=${sFolder%_UTC/*}_UTC # /n/groups/marks/projects/.snapshot/groups_2025-06-17_23_00_04_UTC

dFolder=tarred

logDir=$pass

folders="$logDir/folders.txt"

export tmpDir="$logDir/tmp"

mkdir -p "$tmpDir"

echo > $logDir/randomCheck.log

mapfile -t selected_paths < <(shuf -n $count "$folders")

for sourceDir in "${selected_paths[@]}"; do
    rm -fr $tmpDir/* 2>/dev/null
    #sourceDir="$path" 
        # sourceDir=${path/$baseDir/$snapshotDir}
        # destDir="$dFolder${path#$sFolder}";

        # subDir=${path#$sFolder}
        # mkdir -p $tmpDir/$subDir

    #sourceDir="${path/$baseDir/$snapshotDir}"
    #echo "Processing: $sourceDir" 

    #if [ -d "$sourceDir" ]; then
        # if ! find "$sourceDir" -maxdepth 1 \( -type f -o -type l \) >/dev/null; then
        #    echo "1 No files in $sourceDir"
        #    continue 
        # fi 


         
        destDir="$dFolder${sourceDir#$sFolder}"; 

printf "%s\n" "Processing: $sourceDir vs $destDir"
        #subDir="${sourceDir#$sFolder}"
        #mkdir -p $tmpDir$subDir
        #cp $destDir/* "$tmpDir/$subDir" 2>/dev/null

        # if ! find "$tmpDir/$subDir" -maxdepth 1 \( -type f -o -type l \) >/dev/null; then
        #    echo "2 No files in $tmpDir/$subDir"
        #    continue 
        # fi 

        #echo "Checking: $path"

        if [[ "$action" == zar* ]]; then 
            # need more workers here
            find $tmpDir/$subDir -name "*.tar" -print0 | xargs -0 -P 4 -I {} sh -c 'echo unzar.py "$1"; echo rming "$1";' _ {}
        else 
            #find "$destDir" -maxdepth 1 -mindepth 1 -name "*.tar" -print0 | xargs -0 -P 4 -I {} sh -c '[[ "$1" == *.tar ]] && tar --exclude='*.md5sum' --overwrite -xf "$1" -C $tmpDir || cp $1 $tmpDir' _ {}

            # todo: need to try this code before using it for production
            find "$destDir" -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -print0 | xargs -0 -I {} sh -c '
                file="$1"; base="${file##*/}";
                if [[ "$file" == *.tar ]] && `tar -tf "$1" | grep -qxF "${base%.tar}.md5sum"`; then
                    echo untarring "$1" to "$2"
                    tar --exclude='*.md5sum' --overwrite -xf "$1" -C "$2"
                else
                    echo copying "$1" to "$2"
                    cp -a "$1" "$2/"
                fi
            ' _ {} $tmpDir

            #ls $tmpDir
        fi 

        find "$sourceDir" -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -printf "%f\t%s\n" | sort -n > $logDir/sourceDir.txt
        find "$tmpDir" -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -printf "%f\t%s\n" | sort -n > $logDir/tmpDir.txt
      
        # echo Source Directory: $sourceDir
        # cat sourceDir.txt

        # echo extracted Directory:
        # cat tmpDir.txt
        
      { diff <(cat $logDir/sourceDir.txt) <(cat $logDir/tmpDir.txt) && echo good: "$sourceDir" || echo "Mismatch found in $sourceDir"; } | tee -a $logDir/randomCheck.log 2>&1


    # else
    #     echo "Warning: $path does not exist."
    # fi

done

# grep "Mismatch found" randomCheck.log >/dev/null && echo "Some mismatches found. Check randomCheck.log" || echo "All checked directories match."

count1=$(grep -c '^good:' $logDir/randomCheck.log)

if [ "$count1" -lt "$count" ]; then
    echo "$count1 of $count good folders found. Check randomCheck.log"
else
    echo "All ($count1 of $count) checked directories match."
fi