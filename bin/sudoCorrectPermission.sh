#!/bin/bash

#set -x
set -e

echo Running $0 $@ 

# make sure $2 is not empty and is a number
if [[ -z "$2" || ! "$2" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <pass, for example: pass1> <nProcess>"
    exit 1
fi

[ -f "$1/folders.txt" ] || { echo "Folder list file $1/folders.txt does not exist."; exit 1; }

folders="$1/folders.txt"
nProc="$2"

firstLine=$(head -n 1 "$folders")

if [[ "$firstLine" == *".snapshot"* ]]; then
  

  snapshotPath=$(echo "$firstLine" | grep -oE '/\.snapshot/[^/]+')

  sed "s|$snapshotPath||g" "$folders" > "$folders.tmp"

  firstLine=$(head -n 1 "$folders.tmp")
else 
  cp "$folders" "$folders.tmp"
fi

export groupName=$(stat -c '%G' "$firstLine")

cat $folders.tmp | xargs -P "$nProc" -I %% bash -c '
  echo Processing "$1";
  sudo find "$1" -mindepth 1 -maxdepth 1 \( \! -group $groupName -exec chown :$groupName {} \; \) -o \( -type d \! -perm -g+rx -exec chmod u+rwx,g+rwxs {} \; \) -o \( -type f \! -perm -g+r -exec chmod u+rw,g+rw {} \; \)
' _ "%%"
