#!/bin/bash

set -euo pipefail  # Ensure pipe failures propagate properly, python need this to work.

function processFolder() { # sourceDir jobID
    [ -z "$rowsToTry" ] || set -x

    local sPath="$1"
    # sPath=${sPath/$baseDir/$snapshotDir}
    # echo working on $sPath
    echo Processing: "$1"

    local path="$dFolder${sPath#$sFolder}"; 

    #local sPath="$1"
    
    #local path="/n/data3_vast/hms/neurobio/htem2/temcagt/datasets/migrated/.snapshot/data3_2025-11-19_16_00_05_UTC/cb2/$1"

    #[ -d "$path" ] || path="/n/data3_vast/hms/neurobio/htem/temcagt/datasets/migrated/.snapshot/data3_2025-11-19_16_00_05_UTC/cb2/$1"

    [ -d "$path" ] || { echo "Error: $path does not exist"; return 1; } 

    grep -qxF "$1" "$logDir"/done.check.$pass.$2.txt 2>/dev/null && echo done earlier && return 

    local tmpfile=$(mktemp)

    #[[ "$sPath" == */n/standby/* ]] && sPath="./fromStandby.${sFolder##*/}${sPath#$sFolder}"

    # type size name 
    # local oFiles=$(find "$sPath"  -maxdepth 1 -mindepth 1 \( -type f -o -type l -o -type d \) -printf "%y\t%s\t%f\n" | awk 'BEGIN{FS=OFS="\t"} $1=="l" || $1=="d" {$2=0}1' | sort 2> $tmpfile)

    local oFiles=$(find "$sPath"  -maxdepth 1 -mindepth 1 \( -type f -o -type l -o -type d \) -printf "%y\t%s\t%f\n" | awk 'BEGIN{FS=OFS="\t"}
{
  # zero size for symlinks and directories
  if ($1=="l" || $1=="d") {
    $2 = 0
  }
  # if filename starts with "-", prepend "./"
  if (($1=="l" || $1=="f") && ($3 ~ /^-/ || $3 == "\\")) {
    $3 = "./" $3
  }
}
1' | sort 2> $tmpfile)

    # echo original files from $sPath:
    # echo -e "$oFiles"

    [ -s $tmpfile ] && echo -e "Error: ----------`cat $tmpfile`---------------" && rm $tmpfile  && return 
    rm $tmpfile

    #local tars=""
    local non_tars=""
    local tarFiles=""
    while IFS=$'\t' read -r type size file; do
        #if [[ "$oFiles" != *"$file"\n* ]]; then 
            if [[ $type == d ]]; then 
                non_tars="$non_tars$type\t0\t$file\n" # set directory size to 0 beause folder size do not match well.

            # it is tar file and newly created within 7 days 
            elif [[ $file == *.tar ]] && `tar -tf "${path}/$file" | grep -qxF "${file%.tar}.md5sum"`; then 

                tarFiles="$tarFiles$(tar --wildcards --exclude='*.md5sum' -tvf "${path}/$file" |awk '{
                    gsub(/^-/, "f", $1)
                    name = ""
    for (i = 6; i <= NF; i++) {
        if ($i == "->") break
        if (name == "") name = $i; else name = name " " $i
    }
                    print substr($1, 1, 1) "\t" $3 "\t" name
                }' )\n"

            elif [[ "$file" == *.zarr.zip ]]; then 
                
                # need to modify this to output type, name and size
                tarFiles="$tarFiles$(viewZar.py "${path}/$file")\n"
            
            elif [[ $file != *.md5sum ]]; then 
                non_tars="$non_tars$type\t$size\t$file\n"
            fi    
        #fi
    done < <(find "$path" -maxdepth 1 -mindepth 1 \( -type f -o -type d \) -printf "%y\t%s\t%f\n") 

    if [ -z "$oFiles" ]; then 
        if [ -z "$tarFiles$non_tars" ]; then 
            echo -e "empty folder, nothing to check: $sPath"
            printf '%b\n' "$1" >> $logDir/done.check.$pass.$2.txt 
        else 
            echo "Error: original files do not exist, but there are extra files in destination!!!"
        fi 
        return; 
    fi 

    #tars="${tars//\$/\\\$}"; printf "%s\n" "$tars"
    #[ -z "$tars" ] || tarFiles=$(tar -tf ${tars} | sort) #| sed 's|^\./||')
    
    tarFiles=${tarFiles%\\n}; #tarFiles=`echo -e "${tarFiles}" | sort`
    non_tars=${non_tars%\\n}
    
    if [ -z "$tarFiles" ]; then 
        tarFiles=`echo -e "$non_tars" | sort`
    elif [ -z "$non_tars" ]; then 
        tarFiles=`echo -e "$tarFiles" | sort`
    else 
        tarFiles=`echo -e "$non_tars\n$tarFiles" | sort`
    fi 
    #echo Compare: && non_tars=${non_tars%\\n} 
    #echo -e "$oFiles" | sort
    #echo -e "$tarFiles" | sort

    if [ -n "$tarFiles$non_tars$oFiles" ] && [ -n "$(diff <(echo -e "$oFiles") <(echo -e "$tarFiles"))" ]; then
        echo checking file $sPath vs $path
        ls $path/*.tar 2>/dev/null && echo Error: wrong tar to delete: "$path"/*.tar "$path"/*.md5sum 
        
        [ -n "$oFiles" ] &&  echo -e "orignal files:\n$oFiles"

        if [ -n "$tarFiles" ]; then 
            echo -e "files in tar:\n$tarFiles"
        else 
            echo No files were found in tar.   
        fi 
        [ -n "$oFiles" ] && [ -n "$tarFiles" ] && echo diff output: && diff <(echo -e "$oFiles") <(echo -e "$tarFiles") || true; 

        echo Error: need rerun: "$sPath" for "$path"
        echo
        #printf '%b\n' "$sPath" >> $logDir/reRun.check.$pass.txt
    else
        printf '%b\n' "$1" >> $logDir/done.check.$pass.$2.txt
    fi

    #set +x 
}
export -f processFolder

# script is sourced, so only source the bash functions
#[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return  

usage() {
    echo "Usage: $0 <sourceFolder> <action> <runType> "; exit 1;
}

date
echo Running $0 $@ 

#set -x 

[[ -z "$1" ]] && { echo "Error: action not specified"; usage; } 

[[ -z "$2" ]] && { echo "Error: runType not specified"; usage; } 

[[ "$1" != zar* && "$1" != tar* ]] && { echo "Error: action must be tar or zar"; usage; } 

[[ "$2" != local && "$2" != sbatch ]] && { echo "Error: runType must be local or sbatch"; usage; }  
[ -z "$3" ] && { echo "Error: pass# not specified"; usage; }

[[ "$3" =~ ^pass[0-9]+$ ]] || { echo "Error: pass should be in format pass#"; exit 1; } 

logDir=$3 #`ls -d $3 2>/dev/null`

sFolder=`head -n 1 $logDir/folders.txt`

folders=$logDir/folders.txt

[[ -z "$sFolder" ]] && { echo "Error: source folder not specified"; usage; } 

[[ -d "$sFolder" ]] || { echo "Error: source folder $sFolder does not exist"; usage; }

if [[ "$sFolder" != *"TestingData"* ]]; then
    [[ "$sFolder" == *snapshot* ]] || { echo "Error: source folder $sFolder does not contain .snapshot"; usage; } 
fi 

#sFolder=`realpath $1 2>/dev/null || readlink $1 || echo $1`

export sFolder=${sFolder%/}

#export baseDir=${sFolder%/.snapshot*} #/n/groups/marks/projects

#export snapshotDir=${sFolder%_UTC/*}_UTC # /n/groups/marks/projects/.snapshot/groups_2025-06-17_23_00_04_UTC

export action="$1"

export runType="$2" 

export pass="$3"

[ $# -ge 4 ] && fromJob="$4" || fromJob=''

[ $# -ge 5 ] && toJob="$5" || toJob=''

[ $# -ge 6 ] && export rowsToTry="$6" || export rowsToTry=''

[ -z "$rowsToTry" ] || set -x 

[[ ! -z "$fromJob" && ! "$fromJob" =~ ^[0-9]+$ ]] && { echo "Error: fromJob must be a number"; usage; }     
[[ ! -z "$toJob" && ! "$toJob" =~ ^[0-9]+$ ]] && { echo "Error: toJob must be a number"; usage; }

if [ ! -z "$fromJob" ] && [ ! -z "$toJob" ]; then 
   [ "$fromJob" -le "$toJob" ] || { echo "Error: fromJob must be less than toJob"; usage; }
fi

[[ ! -z "$rowsToTry" && ! "$rowsToTry" =~ ^[0-9]+$ ]] && { echo "Error: rowsToTry must be a number"; usage; }


# sFolder=`realpath $1 || readlink $1 || echo $1`

# export sFolder=${sFolder%/}


# #export baseDir=${sFolder%/.snapshot*} #/n/groups/marks/projects

# #export snapshotDir=${sFolder%_UTC/*}_UTC # /n/groups/marks/projects/.snapshot/groups_2025-06-17_23_00_04_UTC

# export runType="$3" 

# action=$2

# export pass=$4


# [[ "$4" =~ ^pass[0-9]+$ ]] || { echo "Error: pass should be in format pass#"; exit 1; }



# if [ $# -ge 5 ]; then  
#     fromJob=$5 

#     toJob=$6
# else 
#     fromJob=''
#     toJob=$''
# fi 

# [ $# -ge 7 ] && export rowsToTry=$7 || export rowsToTry='' 

# umask 007

dFolder=tarred; #a${sFolder##*/}

#[ -f $dFolder.log ] && mv $dFolder.log $dFolder.log.$(stat -c '%.19z' $dFolder.log | cut -c 6- | tr " " . | tr ":" "-")

export logDir=$pass

mkdir -p $dFolder $logDir

export dFolder=`realpath $dFolder` 

#rm $logDir/reRun.check.$pass.txt 2>/dev/null || true

if [ ! -f $logDir/folders.txt ]; then 
    echo "Error: $logDir/folders.txt does not exist. Please run the script with pass1 or create folders.txt."
    exit 1
fi

touch $logDir/archive.log

startTime=`date`

if [[ "$action" == zar* ]]; then 
        module load miniconda3
        conda activate zar 
fi     

if [[ "$runType" == local ]]; then  
   
    echo nJobs 0 > $logDir/runTime.txt
    echo 1 start time $(date) >> $logDir/runTime.txt
    
    #cat $logDir/folders.txt

    # escape $ sign
    cat $logDir/folders.txt | xargs -P 1 -I "{}" bash -c '
        #set -x 
        #source $1;
        processFolder "$1" 0
    ' __ "{}"

    echo 0 end time $(date) >> $logDir/runTime.txt

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

    x=$(wc -l < $logDir/folders.txt)  

    export rows_per_job=10000

    nJobs=$(( (x + rows_per_job - 1) / rows_per_job ))

    #[ $x -lt $nJobs ] && nJobs=$x
    echo nJobs $nJobs >> $logDir/runTime.txt

    nodeFile=$logDir/sbtachExclusivceLog.txt

    #nodeFile=/n/data3_vast/data3_datasets/ld32/sbatachExclusivceLog.txt

    #[[ "`realpath .`" == "/n/scratch/users/l/ld32/debug"* ]] && nodeFile=/n/scratch/users/l/ld32/debug/sbatachExclusivceLog.txt

    sinfo -p short -N -o "%N %P %T" | grep -v drain | grep -v down | grep -v allocated | grep -v "\-h\-" | cut -d ' ' -f 1,2 > $nodeFile

    #[[ "$PWD" == "/n/scratch/users/l/ld32/debug"* ]] && nodeFile=/n/scratch/users/l/ld32/debug/sbatachExclusivceLog.txt

    [ -f $logDir/job.sh  ] && mv $logDir/job.sh  $logDir/job.sh.$(stat -c '%.19z' $logDir/job.sh | cut -c 6- | tr " " . | tr ":" "-")

    echo "#!/bin/bash" > $logDir/job.sh   
    echo >> $logDir/job.sh
    #echo "set -e" >> $logDir/job.sh 

    echo "export sFolder=$sFolder" >> $logDir/job.sh
    echo "export dFolder=$dFolder" >> $logDir/job.sh
    echo "export logDir=$logDir" >> $logDir/job.sh
    #echo "export dFolderTmp=\$(mktemp -d /n/scratch/users/l/ld32/tmp.XXXXXX)" >> $logDir/job.sh
    #dFolderTmp=$(mktemp -d /n/scratch/users/l/ld32/tmp.XXXXXX)
    #echo "trap \"rm -fr \$dFolderTmp \" EXIT"  >> $logDir/job.sh

    #echo "trap \"rm -r \$dFolderTmp \$logDir/exclusive 2>/dev/null; echo exiting and delete lock; df /tmp;\" EXIT" >> $logDir/job.sh
    #echo "trap \"rm -r \$logDir/exclusive 2>/dev/null; echo exiting and delete lock; \" EXIT" >> $logDir/job.sh 
    # echo "jIndex=\$1" >> $logDir/job.sh
    # echo "echo job index: \$jIndex" >> $logDir/job.sh
    # echo "echo \$jIndex start time \$(date) \$SLURM_JOBID" >> $logDir/job.sh
    # echo "start_row=\$(( (jIndex - 1) * $rows_per_job + 1 ))" >> $logDir/job.sh 
    # echo "end_row=\$(( jIndex * $rows_per_job ))"  >> $logDir/job.sh 
    # echo "[ \$jIndex -eq $nJobs ] && end_row=$x"  >> $logDir/job.sh 
    # echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt " >> $logDir/job.sh
    # echo "source $0" >> $logDir/job.sh
    # echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt  | while IFS= read -r line; do" >> $logDir/job.sh         
    # echo "  processFolder \"\$line\" \$jIndex" >> $logDir/job.sh 
    # #echo "  sleep 100" >> $logDir/job.sh 
    # echo done >> $logDir/job.sh 
    # echo echo done >> $logDir/job.sh

    echo "jIndex=\$1" >> $logDir/job.sh
    echo "nJobs=$nJobs" >> $logDir/job.sh
    echo "echo job index: \$jIndex" >> $logDir/job.sh
    echo "echo \$jIndex start time \$(date) \$SLURM_JOBID" >> $logDir/job.sh

    # Make the folders more distributed
    # echo "awk -v jIndex=\"\$jIndex\" -v nJobs=\"\$nJobs\" '( NR - 1 ) % nJobs == jIndex - 1' $logDir/folders.txt > $logDir/job_\${jIndex}.txt" >> $logDir/job.sh

    # echo "source $0" >> $logDir/job.sh

    # # Process extracted lines
    # echo "while IFS= read -r line; do" >> $logDir/job.sh
    # echo "  processFolder \"\$line\" \$jIndex" >> $logDir/job.sh
    # echo "done < $logDir/job_\${jIndex}.txt" >> $logDir/job.sh

    echo "rm $logDir/subFolder\$1.check.txt 2>/dev/null" >> $logDir/job.sh
    
    if [ -z "$rowsToTry" ]; then  
        echo "awk -v jIndex=\"\$jIndex\" -v nJobs=\"\$nJobs\" '( NR - 1 ) % nJobs == jIndex - 1' \"\$logDir/folders.txt\" | xargs -n 1 -P 1 -I {} bash -c '" >> $logDir/job.sh
    else 
        echo "awk -v jIndex=\"\$jIndex\" -v nJobs=\"\$nJobs\" '( NR - 1 ) % nJobs == jIndex - 1' \"\$logDir/folders.txt\" | head -n $rowsToTry | xargs -n 1 -P 1 -I {} bash -c '" >> $logDir/job.sh
    fi

    #echo "    set -x" >> $logDir/job.sh
    #echo "    source $0" >> $logDir/job.sh
    echo "    echo \"\$2\" >> $logDir/subFolder\$1.check.txt" >> $logDir/job.sh
    #if [[ "$runType" == *Check ]]; then 
    #     echo "    checkArchieve \"{}\" \"\$1\"" >> $logDir/job.sh
    #else 
    echo "    processFolder \"\$2\" \"\$1\"" >> $logDir/job.sh
    #fi
    
    echo "' _  \"\$jIndex\" \"{}\"" >> $logDir/job.sh
    
    echo "echo Job \$jIndex done" >> $logDir/job.sh

    #echo "echo \$jIndex end time \$(date) \$SLURM_JOBID" >> $logDir/job.sh 
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
    echo "              cmd=\"sbatch -A rccg --qos=testbump -w \$node -o $logDir/slurm.check.$pass.\$jIndex.1.txt -J ${dFolder##*/}.\$jIndex.1 -t 12:0:0 -p short --mem 2G $logDir/job.sh \$jIndex\" " >> $logDir/job.sh 
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

    #count=0; 
    
    if [ -z "$toJob" ]; then 
        toJob=$nJobs
    elif [ "$toJob" -gt "$nJobs" ]; then
        toJob=$nJobs
    fi    

    [ ! -z $rowsToTry ] && fromJob=1 && toJob=1; 


    for i in `seq $fromJob $toJob`; do 
    #for i in 1; do

        # if done earler, skip it
        #grep "^$i end time" $logDir/runTime.txt && echo Done earlier && continue         
        [ -f $logDir/slurm.check.$pass.$i.txt ] && grep "^$i end time" $logDir/slurm.check.$pass.$i.txt && echo Done earlier && continue 
        [ -f $logDir/slurm.check.$pass.$i.1.txt ] && grep "^$i end time" $logDir/slurm.check.$pass.$i.1.txt && echo Done earlier && continue        
        
        #count=$((count+1))
        #[ "$count" -gt 3000 ] && break 

        # for force rerun
        #[ -f $logDir/slurm.check.$pass.$i.txt ] && continue 
        #[ -f $logDir/slurm.check.$pass.$i.1.txt ] && continue
        rm $logDir/tarError$i.txt 2>/dev/null || true

        dep=""; export standbyTmp=''
        # if [[ "$sFolder" == /n/standby* ]]; then
        #     #jIndex=$1
        #     #start_row=$(( (jIndex - 1) * $rows_per_job + 1 )) 
        #     #end_row=$(( jIndex * $rows_per_job )) 
        #     #[ $jIndex -eq $nJobs ] && end_row=$x
        #     #sed -n "${start_row},${end_row}p" $logDir/folders.txt > $standbyTmp.list
        #     #nSFolder=`realpath $PWD/a${standbyTmp##*/}`
        #     #sed 's/^$sFolder/$dFolder/' $standbyTmp.list > "$standbyTmp.list1" 
        #     job_id=$(sbatch --qos=testbump --mem 2G -p transfer -o $logDir/transfer.$i.txt -J transfer.$i -t 2:0:0 --parsable --wrap="rsyncFolders.sh $sFolder $i")        
        #     echo "Submitted job with ID: $job_id"
        #     dep="-d afterok:$job_id"
        #     export standbyTmp="./${sFolder##/}"

        #     echo $job_id >> $logDir/allJobs.txt 
        # fi 

        node=`grep '^com' $nodeFile | grep short | shuf -n 1 | tr -s " " | cut -f1 | cut -d' ' -f1`
        
        node=compute-a-16-21

        if [ -z "$node" ]; then                                                             # -H 
            cmd="sbatch $dep -A rccg --parsable --qos=testbump -o $logDir/slurm.check.$pass.$i.txt -J ${dFolder##*/}.$i -t 12-0:0:0 -p long --mem $mem $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd | tee -a $logDir/readme
            output="$(eval $cmd)"
            echo $output
            #echo holdit short `date '+%m-%d %H:%M:%S'` job $i: ${output##* } >> $nodeFile
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i >> $logDir/runTime.txt
            #dep="-d afterok:$output" 
        else        # -w $node
            cmd="sbatch $dep --qos=testbump --parsable -c 1 -A rccg -o $logDir/slurm.check.$pass.$i.txt -J ${dFolder##*/}.$i -t 12-0:0:0 -p long --mem $mem $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd | tee -a $logDir/readme
            output="$(eval $cmd)"
            echo $output
            sed -i "s/^${node}/o${node}/" $nodeFile
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
