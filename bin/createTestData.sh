#!/bin/bash

set -e 
#set -u
#set -x 

usage() {
    echo "Usage: $0 <numDirs> <numFilesPerDir> <numSubDirs>"
    echo "  <numDirs>        - Number of top-level directories to create."
    echo "  <numFilesPerDir> - Number of files to create in each directory."
    echo "  <numSubDirs>     - Number of subdirectories to create in each directory."
}

if [ "$#" -ne 3 ]; then
    usage
    exit 1
fi

baseDir=TestingData

numDirs="$1"
numFilesPerDir="$2"
numSubDirs="$3"

[ -d "$baseDir" ] && rm -r "$baseDir"
mkdir -p "$baseDir"


baseDir=`realpath $baseDir`

fileExtensions=("txt" "dat" "log")

# first leve directories

# Create directories with special characters in their names
specialDirs=(
    "dir-with-hyphen"
    "dir.with.dot"
    "dir,with,comma"
    "dir(with(paren)"
    "dir)with)paren)"
    "dir[with[bracket]"
    "dir]with]bracket]"
    "dir{with{brace}"
    "dir}with}brace}"
    "dir!with!exclaim"
    "dir@with@at"
    "dir#with#hash"
    "dir$with$dollar"
    "dir&with&ampersand"
    "dir;with:semicolon"
    "dir:with:colon"
    "dir=with=equals"
    "dir+with+plus"
    "dir%with%percent"
    "dir^with^caret"
    "dir~with~tilde"
    "dir space"
    "dir@#%&!()[]{};:,.=+^~$"
)

for (( dirIndex=1; dirIndex<=numDirs; dirIndex++ )); do
    dirPath="$baseDir/dir_$dirIndex"
    mkdir -p "$dirPath"
    echo "Creating directory: $dirPath"

    for (( fileIndex=1; fileIndex<=numFilesPerDir; fileIndex++ )); do
        for ext in "${fileExtensions[@]}"; do
            filePath="$dirPath/file_${fileIndex}.${ext}"
            echo "This is test content for file $fileIndex with extension .${ext} in directory $dirIndex" > "$filePath"
            echo "Created file: $filePath"
        done
    done

    dirPath="$baseDir/dir x$dirIndex"
    mkdir -p "$dirPath"
    echo "Creating directory: $dirPath"

    for (( fileIndex=1; fileIndex<=numFilesPerDir; fileIndex++ )); do
        for ext in "${fileExtensions[@]}"; do
            filePath="$dirPath/file_${fileIndex}.${ext}"
            echo "This is test content for file $fileIndex with extension .${ext} in directory $dirIndex" > "$filePath"
            echo "Created file: $filePath"
        done
    done

    # Create special character directories for each dirIndex
    for specialDir in "${specialDirs[@]}"; do
        specialDirPath="$baseDir/${specialDir}_$dirIndex"
        mkdir -p "$specialDirPath"
        echo "Creating special char directory: $specialDirPath"
        for (( fileIndex=1; fileIndex<=numFilesPerDir; fileIndex++ )); do
            for ext in "${fileExtensions[@]}"; do
                filePath="$specialDirPath/file_${fileIndex}.${ext}"
                echo "This is test content for file $fileIndex with extension .${ext} in special char directory $specialDirPath" > "$filePath"
                echo "Created file: $filePath"
            done
        done
    done

    # second level directories
    # Create a 'Raw Images' directory in each subdirectory
    rawImagesPath="$dirPath/Raw Images"
    mkdir -p "$rawImagesPath"
    
    for i in {1..5}; do 
        filePath="$rawImagesPath/file_$i.dat"
        echo "This is test content for .dat file $i in 'Raw Images'" > "$filePath"
        echo "Created file: $filePath"
    done

    for (( fileIndex=1; fileIndex<=numFilesPerDir; fileIndex++ )); do
        for ext in "${fileExtensions[@]}"; do
            filePath="$rawImagesPath/file_${fileIndex}.${ext}"
            echo "This is test content for file $fileIndex with extension .${ext} in directory $dirIndex" > "$filePath"
            echo "Created file: $filePath"
        done
    done

    for (( subDirIndex=1; subDirIndex<=numSubDirs; subDirIndex++ )); do
        subDirPath="$dirPath/subdir_$subDirIndex"
        mkdir -p "$subDirPath"
        echo "Creating subdirectory: $subDirPath"

        for (( fileIndex=1; fileIndex<=numFilesPerDir; fileIndex++ )); do
            for ext in "${fileExtensions[@]}"; do
                filePath="$subDirPath/file_${fileIndex}.${ext}"
                echo "This is test content for file $fileIndex with extension .${ext} in subdirectory of directory $dirIndex" > "$filePath"
                echo "Created file: $filePath"
            done
        done

        # third level directories
        for (( subDirIndex=1; subDirIndex<=numSubDirs; subDirIndex++ )); do
            subDirPath="$dirPath/subdir_$subDirIndex"
            mkdir -p "$subDirPath"
            echo "Creating subdirectory: $subDirPath"

            for (( fileIndex=1; fileIndex<=numFilesPerDir; fileIndex++ )); do
                for ext in "${fileExtensions[@]}"; do
                    filePath="$subDirPath/file_${fileIndex}.${ext}"
                    echo "This is test content for file $fileIndex with extension .${ext} in subdirectory of directory $dirIndex" > "$filePath"
                    echo "Created file: $filePath"
                done
            done
        done    

    done
done


# Mix large files with small files in each top-level directory
largeFileSize=$(( 1024 * 1024 * 1024 + 100 * 1024 * 1024)) 

numLargeTextFiles=1
numLargeTarFiles=1

for (( dirIndex=1; dirIndex<=numDirs; dirIndex++ )); do
    dirPath="$baseDir/dir_$dirIndex"
    # Add a large text file
    largeTextFile="$dirPath/largefile_${dirIndex}.txt"
    echo "Creating large text file: $largeTextFile ($largeFileSize bytes)"

    # Fast large file creation: use head -c from /dev/zero
    head -c $largeFileSize </dev/zero > "$largeTextFile"
    echo "This is a large test text file for dir $dirIndex" | dd of="$largeTextFile" bs=1 count=1 conv=notrunc

done

# Create 3 large text files in the first 3 top-level dirs with special chars in names
specialLargeNames=(
    "large file@#1 (test).txt"
    "large-file_#2[!].txt"
    "large.file,3;:~.txt"
)
for ((i=1; i<=numLargeTextFiles && i<=numDirs; i++)); do
    dirPath="$baseDir/dir_$i"
    largeTextFile="$dirPath/${specialLargeNames[$((i-1))]}"
    echo "Creating large text file: $largeTextFile ($largeFileSize bytes)"
    head -c $largeFileSize </dev/zero > "$largeTextFile"
    echo "This is a large test text file for dir $i" | dd of="$largeTextFile" bs=1 count=1 conv=notrunc
done

# Create 2 large tar files in the first 2 top-level dirs with special chars in names
specialLargeTarNames=(
    "large tar@#1 (test).tar"
    "large-tar_#2[!].tar"
)
for ((i=1; i<=numLargeTarFiles && i<=numDirs; i++)); do
    dirPath="$baseDir/dir_$i"
    tarDir="$dirPath/tarcontent_${i}"
    mkdir -p "$tarDir"
    dummyFile="$tarDir/dummy_${i}.bin"
    head -c $largeFileSize </dev/zero > "$dummyFile"
    tarFile="$dirPath/${specialLargeTarNames[$((i-1))]}"
    echo "Creating large tar file: $tarFile"
    tar -cf "$tarFile" -C "$tarDir" .
    rm -rf "$tarDir"
done

# Remove read permission from one folder and one file to simulate permission errors
if [ "$numDirs" -ge 1 ]; then
    chmod a-r "$baseDir/dir_1"
    echo "Removed read permission from $baseDir/dir_1"
fi

# Remove read permission from a file in dir_1 if it exists
firstFile="$baseDir/dir_1/file_1.txt"
if [ -f "$firstFile" ]; then
    chmod a-r "$firstFile"
    echo "Removed read permission from $firstFile"
fi

echo "Test data generation complete. It is in $baseDir"