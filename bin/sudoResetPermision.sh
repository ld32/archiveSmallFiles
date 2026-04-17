#!/bin/bash

set -x 
set -e 

rootPath=$1

permission=$2

[ ! -d "$rootPath" ]  && echo "$0 <root path> <readOnly or readWrite>" && exit 1 

[[ "$permission" == readOnly ]] || [[ "$permission" == readWrite ]] || { echo "$0 <root path> <readOnly or readWrite>" && exit 1; } 

groupName=$(stat -c '%G' "$rootPath")

if [[ "$permission" == readOnly ]]; then 
   sudo find "$rootPath" \
    \( ! -group "$groupName" -exec chown -v :"$groupName" {} + \) \
    -o \( -perm -a+w -exec chmod -v a-w {} + \) \
    -o \( -type d ! -perm -ug+rx -exec chmod -v ug+rx,g+s {} + \) \
    -o \( -type f ! -perm -ug+r -exec chmod -v ug+r {} + \)

elif [[ "$permission" == readWrite ]]; then 
  sudo find "$rootPath" \
    \( ! -group "$groupName" -exec chown -v :"$groupName" {} + \) \
    -o \( -type d ! -perm -g+rwx -exec chmod -v g+rwx,g+s {} + \) \
    -o \( -type f ! -perm -g+rw -exec chmod -v g+rw {} + \)
fi 

