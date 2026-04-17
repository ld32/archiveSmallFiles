#!/bin/bash

set -e 
#set -u
#set -x 

# usage() {
#     echo "Create some testing data to test arching/un-archiving scripts."
#     echo "Usage: $0 <numDirs> <numFilesPerDir> <numSubDirs>"
#     echo "  <numDirs>        - Number of top-level directories to create in adition to the special character directories."
#     echo "  <numSubDirs>     - Number of subdirectories to create in each directory."
#     echo "  <numFilesPerDir> - Number of files to create in each directory."
# }

# if [ "$#" -ne 3 ]; then
#     usage
#     exit 1
# fi

baseDir=TestingData

numDirs=2 #"$1"
numSubDirs=2 #"$2"
numFilesPerDir=2 #"$3"


[ -d "$baseDir" ] && rm -r "$baseDir"
mkdir -p "$baseDir"


baseDir=`realpath $baseDir`

fileExtensions=("txt" "dat" "log")

# first leve directories

# Create directories with special characters in their names
specialDirs=(
    "dir space"
    'dir"WithDouleQuotation'
    "dirWithSingle'Quotation"
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
        cp "$dirPath/file_${fileIndex}.${ext}" "$dirPath/.file_${fileIndex}.${ext}" 
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


echo "Test data generation complete. It is in $baseDir. One folder and one file are set to not readable, so that you can test the scripts."
