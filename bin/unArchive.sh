#!/bin/bash

set -o pipefail  # Ensure pipe failures propagate properly, python need this to work.

usage() {
    echo "Usage: $0 <action: tar/zar> <numberOfPathToCheck> [destinationFolder]"; exit 1;
}


function processFolder() {

    #set -x 

    local sPath="$1"

    grep -qxF "$1" "$logDir"/done.$2.txt 2>/dev/null && echo done earlier && return 

    #find "$sPath" -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -printf "%f\n" > sourceDir.txt

    #local sPath=$sDir/"${sPath0#$sFolder/}"
    local dPath=$dFolder/${sPath#$sFolder/} 
    
    if [ -d "$sPath" ]; then
        
        mkdir -p $dPath
        #cp $destDir/* "$tmpDir/$subDir" 2>/dev/null

        echo "Working on: $sPath to $dPath"

        if [[ "$action" == zar* ]]; then 
            find $tmpDir/$subDir -name "*.tar" -print0 | xargs -0 -P 4 -I {} sh -c 'echo unzar.py "$1"; echo rming "$1";' _ {}
        else 
            #find $tmpDir/$subDir -name "*.tar" -print0 | xargs -0 -P 4 -I {} sh -c 'tar --overwrite -xf "$1" -C "$(dirname "$1")"; rm $1 ${1/.tar/.md5sum}' _ {}
            find $sPath -maxdepth 1 -mindepth 1 \( -type f -o -type l \) ! -name "*.md5sum" -print0 | xargs -0 -I {} sh -c '
                if [[ "$1" == *.tar ]]; then
                    if tar -tf "$1" | grep -qxF "${1%.tar}.md5sum" || [ -f ${1%.tar}.md5sum ]; then
                            sudo tar --exclude ".md5sum" --overwrite -xf "$1" -C "$2"
                        else
                            sudo cp -a "$1" "$2/"
                        fi
                    fi    
            ' _ {} $dPath
        fi 

        printf '%b\n' "$1" >> $logDir/done.$2.txt

    else
        echo "Warning: $sPath does not exist."
    fi
}
export -f processFolder

#[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return  

date
echo Running $0 $@ 

set -x 


echo Running $0 $@ 

action="$1" 
if [[ "$action" == zar* ]]; then 
        module load miniconda3
        conda activate zar 
fi 

pass="$2"

sFolder=`head -n 1 $pass/folders.txt`


export dFolder="$2"

action="$3" 

count=$4

[[ ! -z "$4" && ! "$4" =~ ^[0-9]+$ ]] && { echo "Error: numberOfPathToCheck must be a number"; usage; }

if [[ "$action" == zar* ]]; then 
        module load miniconda3
        conda activate zar 
fi 

sFolder=`realpath $1 || readlink $1 || echo $1`

[[ "$1" == *snapshot* ]] || { echo "Error: source folder $1 does not contain .snapshot"; usage; } 

export sFolder=${sFolder%/}

#export baseDir=${sFolder%/.snapshot*} #/n/groups/marks/projects

#export snapshotDir=${sFolder%_UTC/*}_UTC # /n/groups/marks/projects/.snapshot/groups_2025-06-17_23_00_04_UTC

#export sDir=a${sFolder##*/}

export logDir=l${sFolder##*/}

#dFolder=`realpath $dFolder` 

folders="$logDir/folders.txt"

#[ -z "$4" ] && dDir="./tmp1" || dDir="$4"

#mkdir -p "$tmpDir"

#rm -r $tmpDir/* 2>/dev/null


    # Select all paths when count is 0 or larger than/equal to total
cat $logDir/folders.txt | xargs -P 4 -I {} bash -c '
    #set -x     
    #source $1; 
    processFolder "$1" 0
' __ "{}"
     
