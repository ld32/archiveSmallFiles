#!/bin/bash

# login to starfish 
# screen 
# sf query "VAST_DATA3:hms/neurobio/htem/cold_staging/datasets_tocold/righty_r1062" --type d --format "aggrs.total.files full_path" > allfolders.txt
# scp allfolders.txt o2server:/home/ld32

set -ex 

echo starting scanFolderUsingStarfish.sh 

rootpath="${1%/}" # such as: /n/data3_vast/hms/neurobio/htem/cold_staging/datasets_tocold/.snapshot/data3_2026-10-21_16_00_02_UTC/righty_r1062/


if [ -z "$rootpath" ]; then
    echo "Please provide the root path as an argument."
    exit 1
elif [ ! -d "$rootpath" ]; then
    echo "The provided root path does not exist or is not a directory."
    exit 1
elif [[ "$rootpath" != *"/.snapshot/"* ]]; then
    echo "The provided root path is not snapshot."
    exit 1
fi

# remove the fist row from the file
sed '1d' allfolders.txt > allfolders_no_first_row.txt


# get first 20 chars from the first row of the allfolders_no_first_row.txt file
first20chars=$(sed -n '1p' allfolders_no_first_row.txt | cut -f2- | cut -c 1-20)

firstpart=${rootpath%$first20chars*} # such as: /n/data3_vast/hms/neurobio/htem/cold_staging/datasets_tocold

# append the first part to the beginning of the second column in the folders.txt file
sed -i "s|^\([^[:space:]]*\)\t|\1\t$firstpart|" allfolders_no_first_row.txt

# get snapshot path (.snapshot/data3_2026-10-21_16_00_02_UTC/righty_r1062/)from the root path
snapshot="/.snapshot/${rootpath#*.snapshot\/}"

dataset="/${snapshot##*/}/" # such as: righty_r1062

# replace data set with snapshot path in the root path
sed "s|$dataset|$snapshot/|g" allfolders_no_first_row.txt > folders.txt.withCount

# order the rows by the number of files in each folder in the first column from big to small
sort -r -n -k1 folders.txt.withCount > folders.txt.withCount.sorted

# remove the first column from the file and the tab character after the first column, and save the result to a new file
#awk '{$1=""; print $0}' allfolders_sorted.txt > allfolders_sorted_no_count.txt
cut -f2- folders.txt.withCount.sorted > folders.txt

# add root path to first row of the file
sed -i "1s|.*|$rootpath|" folders.txt

head folders.txt

