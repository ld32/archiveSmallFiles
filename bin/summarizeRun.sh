#!/bin/bash

#set -x

pass=$1

echo 
echo -------------------------------------------------- 
#echo log${dFolder}
#dFolder=aaronsBrain--sections
logDir=$pass 

[ -d $logDir ] || { echo Log directory $logDir not found; exit 1; }

x=$(wc -l < $logDir/folders.txt)  

rows_per_job=10000

nJobs=$(( (x + rows_per_job - 1) / rows_per_job ))

count=0;
for i in `seq 1 $nJobs`; do 
    #[ -f $logDir/slurm.$i.txt ] && log=$logDir/slurm.$i.txt || log=$logDir/slurm.$i.1.txt
    { echo Last 10 rows of the log:; tail $logDir/slurm.*.$i.txt  2>/dev/null;  tail $logDir/slurm.*.$i.1.txt  2>/dev/null; } | grep "^$i end time" 1>/dev/null && count=$((count+1)) || { echo job $i not done; tail -n 2  $logDir/slurm.*.$i.txt; }
done     
#count=$nJobs

if [ $count -eq $nJobs ]; then 
    #touch $logDir/allDone
    echo All $nJobs jobs are done already  ++++++++++++++++++   
    passed=`cat $logDir/done.check.$pass.*.txt | wc -l | cut -d' ' -f1` 
    total=`wc -l $logDir/folders.txt | cut -d' ' -f1`
    if [ "$passed" -eq "$total" ]; then
        echo All $total folders done $pass.  ++++++++++++++++++
    else 
        echo $passed/$total folders done with $pass. Need rerun: $((total-passed))
        #set -x 
        for i in `seq 1 $nJobs`; do 
            # passed=`wc -l $logDir/done.$pass.$i.txt 2>/dev/null | cut -d' ' -f1 || echo 0` 
            # passed1=`wc -l $logDir/done.check.$pass.$i.txt 2>/dev/null | cut -d' ' -f1 || echo 0` 
            # total=`wc -l $logDir/subFolder$i.txt 2>/dev/null | cut -d' ' -f1 || echo 0`
            # [ $total -eq 0 ] && total=`wc -l $logDir/subFolder$i.check.txt 2>/dev/null | cut -d' ' -f1 || echo 0`
           # done.$pass.$i.txt
            if [ -f "$logDir/done.$pass.$i.txt" ]; then
                passed=$(wc -l < "$logDir/done.$pass.$i.txt")
            else
                passed=0
            fi

            # done.check.$pass.$i.txt
            if [ -f "$logDir/done.check.$pass.$i.txt" ]; then
                passed1=$(wc -l < "$logDir/done.check.$pass.$i.txt")
            else
                passed1=0
            fi

            # subFolder$i.txt
            if [ -f "$logDir/subFolder$i.txt" ]; then
                total=$(wc -l < "$logDir/subFolder$i.txt")
            else
                total=0
            fi

            # fallback to subFolder$i.check.txt if total is 0
            if [ "$total" -eq 0 ] && [ -f "$logDir/subFolder$i.check.txt" ]; then
                total=$(wc -l < "$logDir/subFolder$i.check.txt")
            fi
            if [ "$passed" -gt 0 ] && [ "$passed" -ne "$total" ]; then
                echo Job $i: $passed/$total folders done with $pass. Need rerun: $((total-passed))
            fi 
            if [ "$passed1" -gt 0 ] && [ "$passed1" -ne "$total" ]; then
                echo Job $i: $passed1/$total folders done with check $pass. Need rerun: $((total-passed1))
                #rm $logDir/slurm.check.$pass.$i.txt 2>/dev/null || true
                #rm $logDir/done.check.$pass.$i.txt 2>/dev/null || true
                
            #else 
            #    echo Job $i: All $total folders done. 
            fi
        done 
    fi 
# else 
#     echo $count of $nJobs are done. 
#     checkJobs $dFolder; 
    
fi 

