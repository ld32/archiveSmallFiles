#!/bin/bash

action=$1

#3 7 11 15 19 21 24 26 29 31 34 36 39 41 44 46 49 51 54 56 59 61 64 66 69 71 74 76 79 81 84 86 89 91 94 96 99 101 104 106 109 111 114 116 119 121 124 126 129 131 134 136 139 141 144 146 149

failedJobs=$(grep -l "NODE FAILURE" pass1/slurm.pass1.*.txt \
  | sed -E 's/.*pass1\.([0-9]+)\.txt/\1/' | sort -n | paste -sd' ')
if [ -z "$failedJobs" ]; then
  echo "No failed jobs found."
else
  echo "Resubmitting failed jobs: $failedJobs"
  for i in $failedJobs; do
    artchFolders.sh tar sbatch $i $i force 
  done
fi
