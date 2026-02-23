#!/bin/bash

function processFolder() {
    #set -x 

    local sDir="$1"

    #sourceDir=${sourceDir/$baseDir/$snapshotDir}
    echo Processing: $sDir
    grep -qxF "$1" "$logDir"/done.chown.$pass.$2.$folderFile.txt 2>/dev/null && echo done earlier && return 
    
    
    local dDir="$dFolder${sDir#$sFolder}"; 

    #local owner=$(stat -c '%U:%G' "$sDir")
    local owner=$(stat -c '%u:%g' "$sDir")
    sudo chmod g+rwx "$dDir" && sudo chown $owner "$dDir"
    find  "$dDir" -maxdepth 1 -maxdepth 1 -type f | xargs -I {} -P 1 bash -c '
        sudo chmod ug+rw "$1"
        sudo chown "$2" "$1"
    ' _ "{}" "$owner"
    #ls -l "$dDir"
    printf "%s\n" "$1" >> "$logDir"/done.chown.$pass.$2.$folderFile.txt
}
export -f processFolder

# script is sourced, so only source the bash functions
#[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return  

usage() {
    echo "Usage: $0 <pass, for example: pass1> <part, for eample 1. There are totally 6 parts.>"; exit 1;
}

date
echo Running $0 $@ 

set -x 

export pass="$1"

export nJobs="$3" 

export folderFile="folders_part_$2"

sFolder=`head -n 1 $pass/$folderFile`

export sFolder=${sFolder%/}

dFolder=tarred

export logDir=$pass

mkdir -p $dFolder $logDir

export dFolder=`realpath $dFolder` 

if [ ! -f $logDir/$folderFile ]; then 
    echo "Error: $folderFile does not exist. Please run the script with pass1 or create $folderFile."
    exit 1
fi

echo star time $(date)

cat $logDir/$folderFile | xargs -P $nJobs -I "{}" bash -c '
    #source $1;
    processFolder "$1" 0
' __ "{}"

echo end time $(date) 


