#/bin/bash

usage() {
    echo "Usage: $0"; exit 1;
}

#set -x

date

echo Running $0 $@ 

echo which pass do are you prepariing for? 
for i in {1..8}; do 
    [ -d "pass$i" ] || { nextPass="pass$i"; break; }
done

RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

export folders=`ls -d pass*/folders.txt || true`

[ -z "$folders" ] && echo No folders.txt found for this directory && exit 1 

echo -e "Please select the folders.txt you want to process or type ${RED}q${NC} to quit:"
count=1 
for i in $folders; do
    printf "${GREEN}%-2s${NC}\t%s\n" $count "$i"
    count=$((count + 1))
done

if [ $count -eq 2 ]; then
    echo Only one folders.txt found. No need to select.
else
    while true; do
        
        read -p "" x </dev/tty
        [[ "$x" == q ]] && exit 0 
        [[ "$x" =~ ^[0-9]+$ && "$x" -lt $count && "$x" -ne 0 ]] || { echo -e "${RED}Out of range. Should be between > 0 and < $count"; continue; }
        export folders=`echo $folders | cut -d' ' -f$x`

        break
    done
fi


sFolder=`head -n 1 $folders`

# note: command to unzarr: 
# find atestData -name "*.zarr.zip" -print0 | xargs -0 -P 1 -I {} sh -c 'date; echo "{}"; module load miniconda3; conda activate zar; unzar.py "{}"'
# find atestData/ -name "*.tar" -print0 | xargs -0 -P 4 -I {} sh -c 'date; echo "$1"; tar --overwrite -xf "$1" -C "$(dirname "$1")"' _ {}


snapshotPath=$(echo "$sFolder" | grep -oE '/\.snapshot/[^/]+')

newSanpshot=$(ls -d ${sFolder%/.snapshot/*}/.snapshot/* 2>/dev/null | sort | tail -n 1 | grep -oE '/\.snapshot/[^/]+' || true)

if [ ! -z "$newSanpshot" ] && [[ "$newSanpshot" != "$snapshotPath" ]]; then 
    echo "Found newer snapshot(s) than the one in folders.txt:"
    echo $newSanpshot
    echo -e "Do you want to use the newer snapshot and update the folders.txt? ${RED}[y/n]${NC}"
    read -p "" yn </dev/tty
    if [[ "$yn" == y ]]; then 
        mkdir -p "$nextPass" 
        if [ -f "$nextPass/folders.txt" ]; then 
         cp "$folders" "$nextPass/folders.txt}.$(date '+%Y-%m-%d_%H-%M-%S_%4N')"
            echo "Backed up folders.txt to $nextPass/folders.txt.$(date '+%Y-%m-%d_%H-%M-%S_%4N')"
        fi     
        sed  "s|$snapshotPath|$newSanpshot|g" "$folders" > "$nextPass/folders.txt"
    fi 
else 
    mkdir -p "$nextPass"
    cp $folders "$nextPass/folders.txt"
fi 

echo Redy to run for $nextPass/folders.txt
