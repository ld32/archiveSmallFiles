#!/bin/bash

function archiveFiles() {  #  $1 source path, 2 jobID 3 dest path 4 item 5 tmpFile name
    #return 0
    [ -z "$rowsToTry" ] || set -x

    local item=$4; local tmp=$5

    [ -z "$item" ] && echo Error: Empty item >> "$logDir/tarError$2.txt" && return 1;  

    [ -f "$3/$item.zarr.zip" ] && echo done earlier: $3/$item.zarr.zip && return

    [ -f "$3/$item.tar" ] && echo Tar done earlier: $3/$item.tar && return

    if [[ "$action" == zar* ]]; then 
        
        #echo file list:
        #cat $tmp.list 
        zar.py $tmp.list "$1" $tmp.zarr.zip || { echo "Error: tar $1" | tee -a "$logDir/tarError$2.txt"; return 1; } 
        rsync -a "$tmp.zarr.zip" "$3/$item.zarr.zip" || { echo Error: srync .zarr.gz for $1 | tee -a  "$logDir/tarError$2.txt"; return 1; } 
    
    else 

        mkdir -p "$tmp.extract"

        # ( cd $1; xargs -d '\n' -a $tmp.list md5sum --quiet) >  "$tmp.extract/$item.md5sum"

  #cat "$tmp.list" 
        ( cd "$1" && while IFS=$'\t' read -r file tp; do
            [[ "$tp" == f ]] && md5sum -- "$file" || exit 1
        done < "$tmp.list" ) > "$tmp.extract/$item.md5sum"
        if [ $? -ne 0 ]; then 
          echo "Error: md5sum failed for $file in $1" | tee -a "$logDir/tarError$2.txt";  
          return 1
        fi 
        #ls "$tmp.extract/$item.md5sum"
        #echo MD5 sum file:
        #cat "$tmp.extract/$item.md5sum"
        #cat "$tmp.md5sum"

        #sed -i 's|^-|./-|' "$tmp.list" # if file name starting with -, need add ./ Otherwise tar give error
        
        #if [[ "$action" == "zar"* ]]; then    
        sed -i 's/\t[^\t]*$//' "$tmp.list" # remove last column
        #fi

        tar --create --preserve-permissions --file "$tmp" -C "$1" -T "$tmp.list" -C "$tmp.extract" "$item.md5sum" 2>> "$logDir/tarError$2.txt" || { echo Error: tar $1 maybe Permission error | tee -a "$logDir/tarError$2.txt"; return 1; } 

        
        tar -xf "$tmp" -C "$tmp.extract" || { echo "Error: Extraction failed - tar corrupt" >> "$logDir/tarError$2.txt"; return 1; }
        
        if [ -s "$tmp.extract/$item.md5sum" ]; then
            # all deadlinks in the file list ˆ
            if (cd "$tmp.extract"; md5sum -c "$item.md5sum" > /dev/null) ; then
                echo "All files in tar verify OK against original MD5s: $item"
            else
                echo "Error: Checksum mismatch - tar has errors or corruption" >> "$logDir/tarError$2.txt"
                return 1
            fi
         else 
            if find "$tmp.extract" -mindepth 1 -maxdepth 1 -type f ! -name "$item.md5sum" | read -r _; then
                ls -l "$tmp.extract"
                #echo "Directory has at least one regular file (no symlinks)." >> $logDir/tarError$2.txt
                echo "Error: MD5 sum file is empty or missing, but directory has at least one regular file (for: $3/$item.tar)" >> $logDir/tarError$2.txt
                return 1
            else
                echo "Warning: MD5 sum file is empty or missing, maybe all links, skipping verification: $1" >> $logDir/tarError$2.txt
            fi
        fi   
        #checkSum=$(md5sum "$tmp" | awk '{ print $1 }') || { echo Error: checksum $1 | tee -a  $logDir/tarError$2.txt; return 1; }     
        #echo "$checkSum $item.tar" > "$path/$item.md5sum" || { echo Error: checksum1 $1 | tee -a $logDir/tarError$2.txt; return 1; } 
        
        rsync -a "$tmp" "$path/$item.tar" || { echo Error: rsync .tar for "$1" | tee -a  $logDir/tarError$2.txt; return 1; } 
    fi
}
export -f archiveFiles

function processFolder() { # $1 input path $2 job ID
    
    [ -z "$rowsToTry" ] || set -x

    echo Processing: "$1"

    #set -x 

    local sourceDir="$1"
    #sourceDir=${sourceDir/$baseDir/$snapshotDir}
    #echo working on $sourceDir
    
    [[ "$sourceDir" != "$sFolder"* ]] && echo Error: path does not contain source folder: path $sourceDir source: $sFolder  && exit 1; 

    local path="$dFolder${sourceDir#$sFolder}"; 

    #echo rsync -avh /n/standby/hms/neurobio/htem/compute/tier2_tocold_20251201_tar1/atier2_tocold_20251201/.snapshot/standby_data_daily_2026-01-22_08-30/${sourceDir#$sFolder}/ $path/ >> $logDir/remove.log 

    # remove the data for rerun
    #echo "find $path -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -exec rm {} + ">> $logDir/remove.log
    #return 

    #[ ! -z "$standbyTmp" ] && sourceDir=$standbyTmp${sourceDir#$sFolder}
    
    grep -qxF "${1}" "$logDir"/done.$pass.$2.txt 2>/dev/null && echo done earlier for folder: $sourceDir && return 
    
    [ -d "$sourceDir" ] && mkdir -p "$path" || { echo Error: source dir does not exist: $sourceDir >> $logDir/tarError$2.txt; return; } 

    if [[ "$action" == "retar" ]]; then
        echo rm "$path/*" "$path"/.[!.]* >> $logDir/remove.log
        rm "$path"/* "$path"/.[!.]* 2>/dev/null || true
    fi

    local error_log=$(mktemp -p /n/scratch/users/${USER:0:1}/$USER/ tmp.XXXXXX)
                                                                                                    # name, type, size
    local find_output=$(find "$sourceDir" -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -printf "%f\t%y\t%k\n" 2> "$error_log" | sort -n)

    #echo -e "$find_output"

    cat "$error_log" >> $logDir/tarError$2.txt
    
    if grep -q "Permission denied" "$error_log" 2>/dev/null; then
        echo "Find command encountered permission error: $sourceDir Exiting."
        rm "$error_log"
        return 1
    fi
    
    if [ -z "$find_output" ]; then 
        echo empty folder
        rm "$error_log"
        #echo ${1} >> "$logDir"/done.$pass.$2.txt
        printf '%s\n' "$1" >> "$logDir/done.$pass.$2.txt"
        return 
    fi 

    rm "$error_log"

    local files=""
    local totalSize=0
    local count=0
    local item type size #  ="";  
    # Process the find output
    
    while IFS=$'\t' read -r item type size; do

        #echo $item $type $size

        [[ "$item" == "-"* ]] && item="./$item"  # if file name starting with -, need add ./ Otherwise zar give error
        [[ "$item" == "\\"* ]] && item="./\\$item"  # file name starts with \  
        if [[ "$action" == zar* ]]; then 
            
            files="$files\n$item\t$type"
            count=$((count + 1))
            if [ "$count" -eq 200 ]; then
                files="${files#\\n}"   # remove leading \n

                item="${files%%\\t*}-${files##*\\n}" 
                item="${item%%\\t*}"

                item=$(printf '%b' "$item" | sed 's/[^a-zA-Z0-9.-]/_/g'); item=${item##-}; #item=${item##.}; #item=${item%_*} # firstFile-lastFile

                local length=${#item}
                if [ "$length" -gt "200" ]; then
                    hash=$(echo -n "$item" | md5sum | cut -d " " -f1)
                    item="${item:0:200}_$hash"
                fi 
                local tmp=`mktemp -p /n/scratch/users/${USER:0:1}/$USER/ tmp.XXXXXX` 
                printf '%b\n' "$files" > $tmp.list
                files=''; count=0; 
                archiveFiles "$sourceDir" "$2" "$path" "$item" $tmp || { rm -r "$tmp" "$tmp.list" "$tmp.extract" 2>/dev/null || true; return 1; }
                rm -r "$tmp" "$tmp.list" "$tmp.extract" 2>/dev/null || true
            fi 
            continue
        fi 
        
        if [ "$size" -gt '1048576' ]; then  # bigger than 1G, directly copy over
            echo rsync -a "$sourceDir/$item" "$path"; 
            rsync -a "$sourceDir/$item" "$path" &&  continue 
            echo Error: rsync item $sourceDir/$item error >> $logDir/tarError$2.txt; 
            echo Error: tar $sourceDir rsync error >> $logDir/tarError$2.txt;
            return 1 
        fi 

        files="$files\n$item\t$type"
        
        #echo line:$line.total:$totalSize.size:$size.
        totalSize=$((totalSize + size))

        if [ "$totalSize" -gt '1048576' ]; then # bigger than 1G
            files="${files#\\n}"   # remove leading \n

            item="${files%%\\t*}-${files##*\\n}" 
            item="${item%%\\t*}"

            item=$(printf '%b' "$item" | sed 's/[^a-zA-Z0-9.-]/_/g'); item=${item##-}; item=${item##.}; #item=${item%_*} # firstFile-lastFile

            local length=${#item}
    
            # Check if the length exceeds the maximum length
            if [ "$length" -gt "200" ]; then
                hash=$(echo -n "$item" | md5sum | cut -d " " -f1)
                item="${item:0:200}_$hash"
            fi 
            local tmp=`mktemp -p /n/scratch/users/${USER:0:1}/$USER/ tmp.XXXXXX` 
            printf '%b\n' "$files" > "$tmp.list"
            archiveFiles "$sourceDir" "$2" "$path" "$item" $tmp || { rm -r "$tmp" "$tmp.list" "$tmp.extract" 2>/dev/null || true; return 1; }
            rm -r "$tmp" "$tmp.list" "$tmp.extract" 2>/dev/null || true
            files=""
            totalSize=0
        fi
    done <<< "$find_output"
    if [ ! -z "$files" ]; then

        files="${files#\\n}"   # remove leading \n

        item="${files%%\\t*}-${files##*\\n}" 
        item="${item%%\\t*}"

        item=$(printf '%b\n' "$item" | sed 's/[^a-zA-Z0-9.-]/_/g'); item=${item##-}; item=${item##.}; #item=${item%_*} # firstFile-lastFile

        local length=${#item}
        if [ "$length" -gt "200" ]; then
            hash=$(echo -n "$item" | md5sum | cut -d " " -f1)
            item="${item:0:200}_$hash"
        fi 

        #echo -e "$files" 

        local tmp=`mktemp -p /n/scratch/users/${USER:0:1}/$USER/ tmp.XXXXXX` 
        
        printf '%b\n' "$files" > "$tmp.list"

        #echo -e "$files" > "$tmp.list"
        #cat "$tmp.list"
        
        archiveFiles "$sourceDir" "$2" "$path" "$item" $tmp || { rm -r "$tmp" "$tmp.list" "$tmp.extract" 2>/dev/null || true; return; }
        rm -r "$tmp" "$tmp.list" "$tmp.extract" 2>/dev/null || true
    fi
    #echo ${1} >> "$logDir"/done.$pass.$2.txt
    printf '%b\n' "$1" >> "$logDir/done.$pass.$2.txt"
    
}
export -f processFolder

# script is sourced, so only source the bash functions
#[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return  

usage() {
    echo "Usage: $0 <action: tar/zar> <runType: local/sbatch> <pass: pass#> <fromJob> <toJob> <rowsToTry>"; exit 1;
}

set -x

date

echo Running $0 $@ 

# note: command to unzarr: 
# find atestData -name "*.zarr.zip" -print0 | xargs -0 -P 1 -I {} sh -c 'date; echo "{}"; module load miniconda3; conda activate zar; unzar.py "{}"'
# find atestData/ -name "*.tar" -print0 | xargs -0 -P 4 -I {} sh -c 'date; echo "$1"; tar --overwrite -xf "$1" -C "$(dirname "$1")"' _ {}

[[ -z "$1" ]] && { echo "Error: action not specified"; usage; } 

[[ -z "$2" ]] && { echo "Error: runType not specified"; usage; } 

[[ "$1" != zar* && "$1" != *tar ]] && { echo "Error: action must be tar or zar"; usage; } 

[[ "$2" != local && "$2" != sbatch ]] && { echo "Error: runType must be local or sbatch"; usage; }  
[ -z "$3" ] && { echo "Error: pass# not specified"; usage; }

[[ "$3" =~ ^pass[0-9]+$ ]] || { echo "Error: pass should be in format pass#"; exit 1; } 

logDir=$3

sFolder=`head -n 1 $logDir/folders.txt`

folders=$logDir/folders.txt

[[ -z "$sFolder" ]] && { echo "Error: source folder not specified"; usage; } 

[[ -d "$sFolder" ]] || { echo "Error: source folder $sFolder does not exist"; usage; }

if [[ "$sFolder" != *"TestingData"* ]]; then
    [[ "$sFolder" == *snapshot* ]] || { echo "Error: source folder $sFolder does not contain .snapshot"; usage; } 
fi 

[[ ! -z "$4" && ! "$4" =~ ^[0-9]+$ ]] && { echo "Error: fromJob must be a number"; usage; }     
[[ ! -z "$5" && ! "$5" =~ ^[0-9]+$ ]] && { echo "Error: toJob must be a number"; usage; }

if [ ! -z "$4" ] && [ ! -z "$5" ]; then 
   [ "$4" -le "$5" ] || { echo "Error: fromJob must be less than toJob"; usage; }
fi

[[ ! -z "$6" && ! "$6" =~ ^[0-9]+$ ]] && { echo "Error: rowsToTry must be a number"; usage; }

#sFolder=`realpath $1 2>/dev/null || readlink $1 || echo $1`

export sFolder=${sFolder%/}

#export baseDir=${sFolder%/.snapshot*} #/n/groups/marks/projects

#export snapshotDir=${sFolder%_UTC/*}_UTC # /n/groups/marks/projects/.snapshot/groups_2025-06-17_23_00_04_UTC

export action="$1"

export runType="$2" 

export pass="$3"

fromJob="$4" 

toJob="$5"

export rowsToTry="$6" || export rowsToTry=''

[ -z "$rowsToTry" ] || set -x 

umask 007


#exit; 

set -uo pipefail  # Ensure pipe failures propagate properly, python need this to work.

dFolder=tarred; #a${sFolder##*/}

#[ -f $dFolder.log ] && mv $dFolder.log $dFolder.log.$(stat -c '%.19z' $dFolder.log | cut -c 6- | tr " " . | tr ":" "-")

export logDir=$PWD/$pass

mkdir -p $dFolder $logDir

export dFolder=`realpath $dFolder` 

rm $logDir/remove.log 2>/dev/null || true

# if [ ! -f $logDir/folders.txt ]; then 
#     echo "Error: $logDir/folders.txt does not exist. Please scan folders to create folders.txt."
#     exit 1
# fi

if [[ "$action" == zar* ]]; then 
        module load miniconda3
        conda activate zar 
fi 

touch $logDir/archive.log

startTime=`date`

if [[ "$runType" == local ]]; then  

    echo nJobs 1 > $logDir/runTime.txt
    echo 1 start time $(date) >> $logDir/runTime.txt
    
    #cat $logDir/folders.txt
    #set -x     
    cat $folders | xargs -P 1 -I {} bash -c '
        #set -x 
        #source $1; 
        processFolder "$1" 0
    ' __ "{}"
    echo 1 end time $(date) >> $logDir/runTime.txt

elif [[ $runType == sbatch ]]; then
    notDone=''
    if [ -f $logDir/allJobs.txt ]; then 
        IFS=$'\n'; out=`squeue -u $USER -t PD,R -o "%.18i"`
        if [ ! -z "$out" ]; then 
            for line in `cat $logDir/allJobs.txt`; do
                [[ "$out" == *$line* ]] && notDone="$line $notDone"
            done 
        fi     
    fi 

    [ -z "$notDone" ] || { echo -e "A run was started earlier on the folder and the folowing jobs are still pending or running\nPlease wait for them to finish or cancel them:\n$notDone"; exit 1; }

    rm -r $logDir/exclusive $logDir/allJobs.txt  2>/dev/null || true 


    if [[ "$action" == zar* ]]; then 
        mem=12G
    else 
        mem=4G
    fi 

    x=$(wc -l < $folders)  
    
    export rows_per_job=10000

    nJobs=$(( (x + rows_per_job - 1) / rows_per_job ))

    #[ $x -lt $nJobs ] && nJobs=$x
    echo nJobs $nJobs >> $logDir/runTime.txt

    nodeFile=$logDir/sbtachExclusivceLog.txt

    #nodeFile=/n/data3_vast/data3_datasets/$USER/sbatachExclusivceLog.txt

    #[[ "`realpath .`" == "/n/scratch/users/${USER:0:1}/$USER/debug"* ]] && nodeFile=/n/scratch/users/${USER:0:1}/$USER/debug/sbatachExclusivceLog.txt

    sinfo -p short -N -o "%N %P %T" | grep -v drain | grep -v down | grep -v allocated | grep -v "\-h\-" | cut -d ' ' -f 1,2 > $nodeFile

    #[[ "$PWD" == "/n/scratch/users/${USER:0:1}/$USER/debug"* ]] && nodeFile=/n/scratch/users/${USER:0:1}/$USER/debug/sbatachExclusivceLog.txt

    [ -f $logDir/job.sh  ] && mv $logDir/job.sh  $logDir/job.sh.$(stat -c '%.19z' $logDir/job.sh | cut -c 6- | tr " " . | tr ":" "-")

    echo "#!/bin/bash" > $logDir/job.sh   
    echo >> $logDir/job.sh
    #echo "set -x" >> $logDir/job.sh 

    echo "export sFolder=$sFolder" >> $logDir/job.sh
    echo "export dFolder=$dFolder" >> $logDir/job.sh
    echo "export logDir=$logDir" >> $logDir/job.sh
    echo "export dFolderTmp=\$(mktemp -d /n/scratch/users/${USER:0:1}/$USER/tmp.XXXXXX)" >> $logDir/job.sh
    #dFolderTmp=$(mktemp -d /n/scratch/users/${USER:0:1}/$USER/tmp.XXXXXX)
    #echo "trap \"rm -fr \$dFolderTmp \" EXIT"  >> $logDir/job.sh

    echo "trap \"rm -r \$dFolderTmp \$logDir/exclusive 2>/dev/null; echo exiting and delete lock; df /tmp;\" EXIT" >> $logDir/job.sh

    echo "jIndex=\$1" >> $logDir/job.sh
    echo "nJobs=$nJobs" >> $logDir/job.sh
    echo "echo Job index: \$jIndex" >> $logDir/job.sh
    echo "echo \$jIndex start time \$(date) \$SLURM_JOBID" >> $logDir/job.sh

    echo rm $logDir/subFolder\$1.txt 2>/dev/null >> $logDir/job.sh

    if [ -z "$rowsToTry" ]; then  
        echo "awk -v jIndex=\"\$jIndex\" -v nJobs=\"\$nJobs\" '( NR - 1 ) % nJobs == jIndex - 1' \"\$folders\" | xargs -P 1 -I {} bash -c '" >> $logDir/job.sh
    else 
        echo "awk -v jIndex=\"\$jIndex\" -v nJobs=\"\$nJobs\" '( NR - 1 ) % nJobs == jIndex - 1' \"\$folders\" | head -n $rowsToTry | xargs -P 1 -I {} bash -c '" >> $logDir/job.sh
    fi

    #echo "    set -x" >> $logDir/job.sh
    #echo "    source $0" >> $logDir/job.sh
    echo "    echo \"\$2\" >> $logDir/subFolder\$1.txt" >> $logDir/job.sh
    #if [[ "$runType" == *Check ]]; then 
    #     echo "    checkArchieve \"{}\" \"\$1\"" >> $logDir/job.sh
    #else 
        echo "    processFolder \"\$2\" \"\$1\"" >> $logDir/job.sh
    #fi
    
    echo "' _  \"\$jIndex\" \"{}\"" >> $logDir/job.sh

    echo "echo Job \$jIndex done" >> $logDir/job.sh
    [ -z "$rowsToTry" ] && echo "echo \$jIndex end time \$(date) \$SLURM_JOBID" >> $logDir/job.sh ||  echo "echo test job \$jIndex end time \$(date) \$SLURM_JOBID" >> $logDir/job.sh

    #todo: clean up tarError, irgnroe empty file or not important mesage
    echo "if [ -f $logDir/tarError\$jIndex.txt ]; then" >> $logDir/job.sh 
    echo "  er=\`cat $logDir/tarError\$jIndex.txt\`" >> $logDir/job.sh
    echo "  echo -e \"Subject: !!! With error: s\$jIndex/\$SLURM_JOBID done ${dFolder##*/}\nPlase check: \$er\" | sendmail `head -n 1 ~/.forward` " >> $logDir/job.sh
    echo "else" >> $logDir/job.sh 
    echo "  echo -e \"Subject: s\$jIndex/\$SLURM_JOBID done ${dFolder##*/}\" | sendmail `head -n 1 ~/.forward` " >> $logDir/job.sh
    echo "fi" >> $logDir/job.sh 
    # remove later
    #echo "sleep 35" >> $logDir/job.sh 
    echo exit >> $logDir/job.sh

    echo "while ! mkdir $logDir/exclusive 2>/dev/null; do" >> $logDir/job.sh 
    #echo "  echo waiting for the lock" >>  $logDir/job.sh 
    echo "  sleep \$((1 + RANDOM % 10))" >> $logDir/job.sh 
    echo "done" >> $logDir/job.sh 

    echo "echo got the lock" >>  $logDir/job.sh 

    #echo "echo job $jIndex original sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh
    #echo "cat $nodeFile >&2" >> $logDir/job.sh 

    echo "sed -i \"s/^o\${SLURM_JOB_NODELIST}/\${SLURM_JOB_NODELIST}/\" $nodeFile" >> $logDir/job.sh 
    echo "sed -i \"s/spaceHolder\${SLURM_JOB_ID}/; done \$(date '+%m-%d %H:%M:%S')/\" $nodeFile" >> $logDir/job.sh  

    # release holding job
    echo "IFS=$'\n'" >> $logDir/job.sh 
    echo "for line in \`grep '^hold' $nodeFile | grep -v unhold\`; do " >> $logDir/job.sh 
    echo "  job=\${line##* }; p=\`echo \$line | cut -d' ' -f2\`" >> $logDir/job.sh 
    echo "  node=\`grep '^com' $nodeFile | grep \$p | shuf -n 1 | tr -s \" \" | cut -f1 | cut -d' ' -f1\`" >> $logDir/job.sh 
    echo "  if [ -z \"\$node\" ]; then " >> $logDir/job.sh 
    echo "      break" >> $logDir/job.sh 
    echo "  else " >> $logDir/job.sh 
    echo "      scontrol update JobID=\$job NodeList=\$node" >> $logDir/job.sh 
    echo "      scontrol release JobID=\$job" >> $logDir/job.sh 
    echo "      sed -i \"s/^\${node}/o\${node}/\" $nodeFile" >> $logDir/job.sh 
    echo "      eTime=\$(date '+%m-%d %H:%M:%S')" >> $logDir/job.sh 
    echo "      sed -i \"s|\${job}|\${job}; unhold onto: \${node} by job: \${SLURM_JOB_ID} \${eTime}spaceHolder\${job}|\" $nodeFile" >> $logDir/job.sh  
    echo "  fi " >> $logDir/job.sh 
    #echo "  echo job $jIndex updated sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh 
    #echo "  cat $nodeFile >&2" >> $logDir/job.sh 
    echo "done " >> $logDir/job.sh 

    # switch nodes for jobs penidng more than x seconds
    echo "pending=\`squeue -u $USER -t PD -o \"%.18i\"\`" >> $logDir/job.sh 
    echo "if [ ! -z \"\$pending\" ]; then" >> $logDir/job.sh  
    echo "  for line in \`grep spaceHolder $nodeFile | grep ^submit\`; do " >> $logDir/job.sh 
    echo "      job=\${line##*spaceHolder}; p=\`echo \$line | cut -d' ' -f2\`" >> $logDir/job.sh 
        
    # submit medium 08-07 14:34:37 job: 43540546 on: compute-a-16-35spaceHolder43540546
    echo "      t=\${line##submit short }; t=\${t% job*}; t=\$(date -d \"\$t\" +%s)" >> $logDir/job.sh 
    echo "      ct=\$(date +%s); pt=\$((ct - t)); jIndex=\${line#*job }; jIndex=\${jIndex%%:*}" >> $logDir/job.sh 

                # pending for more than x seconds
    echo "      if [ \"\$pt\" -gt 1200 ] && [[ "\$pending" == *\$job* ]]; then" >> $logDir/job.sh 
    echo "          node=\`grep '^com' $nodeFile | grep \$p | shuf -n 1 | tr -s \" \" | cut -f1 | cut -d' ' -f1\`" >> $logDir/job.sh 
    echo "          if [ -z \"\$node\" ]; then " >> $logDir/job.sh 
    echo "              break" >> $logDir/job.sh 
    echo "          else " >> $logDir/job.sh 
    echo "              scancel \$job" >> $logDir/job.sh
    echo "              cmd=\"sbatch -A rccg --qos=testbump -w \$node -o $logDir/slurm.$pass.\$jIndex.1.txt -J ${dFolder##*/}.\$jIndex.1 -t 12:0:0 -p short --mem 2G $logDir/job.sh \$jIndex\" " >> $logDir/job.sh 
    echo "              output=\"\$(eval \$cmd)\" " >> $logDir/job.sh 
    echo "              sed -i \"s/^\${node}/o\${node}/\" $nodeFile " >> $logDir/job.sh 
    echo "              echo submit short \`date '+%Y-%m-%d %H:%M:%S'\` job \$jIndex: \${output##* } on: \${node}spaceHolder\${output##* } >> $nodeFile" >> $logDir/job.sh 
    echo "              echo \${output##* } >> $logDir/allJobs.txt" >> $logDir/job.sh 
    echo "              echo submitted \${output##* }/\$jIndex on \$node >> $logDir/runTime.txt" >> $logDir/job.sh 

    echo "              echo resumit to switch node for \$job to \$node" >> $logDir/job.sh 
    #echo "             scontrol update JobID=\$job NodeList=\$node" >> $logDir/job.sh 
    #echo "             scontrol release JobID=\$job" >> $logDir/job.sh 
    echo "              sed -i \"s/^\${node}/o\${node}/\" $nodeFile" >> $logDir/job.sh # don't release it because job pending forever!!
    echo "              sed -i \"s/spaceHolder\${job}/ \${job}, pended too long, resumit as \${output##* } on: \$node by job: \${SLURM_JOB_ID}/\" $nodeFile" >> $logDir/job.sh  
    echo "          fi" >> $logDir/job.sh
    echo "      fi" >> $logDir/job.sh 
    #echo "      echo job $jIndex updated sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh 
    #echo "      cat $nodeFile >&2" >> $logDir/job.sh 
    echo "  done " >> $logDir/job.sh 
    echo "fi" >> $logDir/job.sh

    echo "rm -r $logDir/exclusive " >> $logDir/job.sh 

    echo "echo released the lock" >>  $logDir/job.sh 

    echo sleep 10 >> $logDir/job.sh # wait for email to send out

    echo "[ ! -s $logDir/tarError\$jIndex.txt ] && rm $logDir/tarError\$jIndex.txt || exit 1 " >> $logDir/job.sh

    #echo "[ -f $logDir/tarError\$jIndex.txt ] && [ ! -s $logDir/tarError\$jIndex.txt ] && exit 1" >> $logDir/job.sh 

    echo Slurm script:
    
    echo Slurm script ready: $logDir/job.sh

    [ -z "$fromJob" ] && fromJob=1
    if [ -z "$toJob" ]; then 
        toJob=$nJobs
    elif [ "$toJob" -gt "$nJobs" ]; then
        toJob=$nJobs
    fi    

    [ ! -z "$rowsToTry" ] && fromJob=1 && toJob=1; 
    
    for i in `seq $fromJob $toJob`; do 
    
        # if done earler, skip it     
        [ -f $logDir/slurm.$pass.$i.txt ] && grep "^$i end time" $logDir/slurm.$pass.$i.txt && echo Done earlier && continue 
        [ -f $logDir/slurm.$pass.$i.1.txt ] && grep "^$i end time" $logDir/slurm.$pass.$i.1.txt && echo Done earlier && continue        
        
        # for force rerun
        #[ -f $logDir/slurm.$i.txt ] && continue 
        #[ -f $logDir/slurm.$i.1.txt ] && continue
        rm $logDir/tarError$i.txt 2>/dev/null

        #set -x 
        dep="";

        # if [[ "$sFolder" == */n/standby* ]] && [[ "$runType" == *sync ]]; then
        #     #export standbyTmp="./fromStandby.${sFolder##*/}"
        #     #rsyncFolders $sFolder $i

            
        #     echo "sbatch --qos=testbump -A rccg --mem 2G -p transfer -o $logDir/transfer.$i.txt -J transfer.$i -t 72:0:0 --parsable --wrap=\"source $script_path; rsyncFolders $sFolder $i\""

        #     script_path="$(readlink -f "$0")"
        #     job_id=$(sbatch --qos=testbump -A rccg --mem 2G -p transfer -o $logDir/transfer.$i.txt -J transfer.$i -t 72:0:0 --parsable --wrap="source $script_path; rsyncFolders $sFolder $i")        
        #     echo "Submitted job with ID: $job_id"
        #     dep="-d afterok:$job_id"
            
        #     echo $job_id >> $logDir/allJobs.txt 

        # fi 
        

        node=`grep '^com' $nodeFile | grep short | shuf -n 1 | tr -s " " | cut -f1 | cut -d' ' -f1`
        
        node=compute-a-16-21

        if [ -z "$node" ]; then                                                        # -H 
            cmd="sbatch $dep -A rccg --parsable --qos=testbump -o $logDir/slurm.$pass.$i.txt -J ${dFolder##*/}.$i -t 12-0:0:0 -p long --mem $mem $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd | tee -a $logDir/readme
            output="$(eval $cmd)"
            echo $output
            echo holdit short `date '+%m-%d %H:%M:%S'` job $i: ${output##* } >> $nodeFile
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i >> $logDir/runTime.txt
            #dep="-d afterok:$output" 
        else        # -w $node
            cmd="sbatch $dep --qos=testbump --parsable -c 1 -A rccg -o $logDir/slurm.$pass.$i.txt -J ${dFolder##*/}.$i -t 12-0:0:0 -p long --mem $mem $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd | tee -a $logDir/readme
            output="$(eval $cmd)"
            echo $output
            #sed -i "s/^${node}/o${node}/" $nodeFile
            #echo submit short `date '+%Y-%m-%d %H:%M:%S'` job $i: ${output##* } on: ${node}spaceHolder${output##* } >> $nodeFile
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i on $node >> $logDir/runTime.txt
            #dep="-d afterok:$output" 
        fi

        # if [[ "$sFolder" == /n/standby* ]]; then
        #     #sed -i 's/^string_to_replace/new_string/' "$standbyTmp.list" 
        #     job_id=$(sbatch $dep --qos=testbump --mem 2G -o $logDir/transfer1.$i.txt -J transfer1.$i -p transfer -t 2:0:0 --parsable --wrap="rsyncFolders.sh back $i")        
        #     echo "Submitted job with ID: $job_id"
        # fi 

        sleep 1
        #break 
    done
    #cat $nodeFile >&2
fi 


endTime=`date`
echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes" | tee -a $logDir/archive.log
