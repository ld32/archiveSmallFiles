# Archieve Small Files

To decrease number of small file, keep the folder structure, tar all files less than 1G

git clone https://github.com/ld32/archiveSmallFiles.git

export PATH=$PWD/archiveSmallFiles/bin:$PATH

## Practice with testing data

```
# Start an interactive job, create a working directory and go to it: 
$ srun -p short -t 2:0:0 --mem 2G --pty /bin/bash 
$ cd $HOME
$ mkdir -p tarTesting 
$ cd tarTesting

# Prepare a testing data: 
$ createTestData.sh
...
Test data generation complete. It is in /home/xyz/tarTesting/TestingData. 
One folder and one file are set to not readable, so that you can test the scripts.

# Correct permission: assuming all the data belong to the user's group, set everything group readable
$ find TestingData -exec sh -c 'for f; do [ -d "$f" ] && chmod 775 "$f" || chmod 664 "$f"; done' sh {} +

# If there is any error and need sudo command to set permision, please contact data owner or rchelp@hms.harvard.edu for help 

# To scan folders (with 1 process):
$ scanFolders.sh TestingData/ 1 65 2>&1 | tee scan.log
...
Folder count matches expected value: 65. Total folders found: 65.
Scan results (should match with the numbers in starfish):
Total number of folders:
65
And total number of files:
365

# To archive using tar:
archiveFolders.sh tar local pass1

# Some folders will not work due to permission or some other reason. 
# Let's find the folders not done yet:
$ findFoldersNotDoneArchiving.sh pass1
...
Actual folders: 65
Done folders: 63
Not done folders: 2
Not done folders are saved to pass2/folders.txt.
Please review logs and see what is the issue: 
$ cat pass1/tarError* 

# If there is permission issues, please run: 
$ find TestingData -exec sh -c 'for f; do [ -d "$f" ] && chmod 775 "$f" || chmod 664 "$f"; done' sh {} +

# If there is any error and need sudo command to set permision, please contact data owner or rchelp@hms.harvard.edu for help 

#Aftet that, you can run the next pass now:
$ archiveFolders.sh tar local pass2

#Check again: 
$ findFoldersNotDoneArchiving.sh pass2
...
Actual folders: 2
Done folders: 2

# To check archives (We use pass1 because pass1 has full list of folders):
$ checkArchives.sh tar local pass1

# Some folders might not work due to permission or some other reason. 
# Let's find the folders not done yet:
$ findFoldersNotDoneChecking.sh pass1
...
pass1
Archive checking results:
Actual folders: 65
Done folders: 63
Total number of original files:
365
Total number of files if we  untar all the data (should be the same as untarred file count):
348
Total number of files after tarring (should be the same the number of files in tarred folder in starfish):
57
Not done folders: 2
Not done folders are saved to pass3/folders.txt.

#Please review logs and see what is the issue:
$ cat pass1/tarError*

# If there is permission issues, please run: 
$ find TestingData -exec sh -c 'for f; do [ -d "$f" ] && chmod 775 "$f" || chmod 664 "$f"; done' sh {} +

# If there is any error and need sudo command to set permision, please contact data owner or rchelp@hms.harvard.edu for help 

#Aftet that, you can archive them: 
$ archiveFolders.sh tar local/sbatch pass3

#Aftet that, you can run the next pass now:
$ checkArchives.sh tar local pass3

Then:
$ findFoldersNotDoneChecking.sh pass3

# To randomly un-archieve 10 folder and compare with original using diff command:
randomUnArchiveToCheck.sh tar pass1 10
```

## Un-Archive 
``` bash 
# quickly untar from interactive commandline: 
$ find dataFolder -name "*.tar" -print0 | xargs -0 -P 4 -I {} sh -c 'tar --overwrite -xf "$1" -C "$(dirname "$1")"; rm $1 ${1/.tar/.md5sum}' _ {}

# this code snippet takes care of both cases: 
 $ find $sPath -maxdepth 1 -mindepth 1 \( -type f -o -type l \) ! -name "*.md5sum" -print0 | xargs -0 -I {} sh -c '
                if [[ "$1" == *.tar ]]; then
                    if tar -tf "$1" | grep -qxF "${1%.tar}.md5sum" || [ -f ${1%.tar}.md5sum ]; then
                            tar --exclude ".md5sum" --overwrite -xf "$1" -C "$2"
                        else
                            cp -a "$1" "$2/"
                        fi
                    fi    
            ' _ {} $dPath

# Using scripts
$ unArchives.sh tar local pass2
```

## Working with real data
``` bash
# Start an interactive job, create a working directory where you 
# want to keep the archived data and go to it: 
$ srun -p short -t 12:0:0 --mem 8G --pty /bin/bash 
$ cd /some/big/storage/
$ mkdir -p tarFprReal 
$ cd tarForReal

# Correct permission: assuming all the data belong to the user's group, set everything group readable
$ find /n/data1/xyz/someData -exec sh -c 'for f; do [ -d "$f" ] && chmod 775 "$f" || chmod 664 "$f"; done' sh {} +

# If there is any error and need sudo command to set permision, please contact data owner or rchelp@hms.harvard.edu for help 

# Wait for next day and use new snapshot to scan folders
# Check Starfish website and find the actul folder count, 
# for example 5500000 folders, 
# then scan folders using 20 processes:
$ scanFolders.sh /n/data1/xyz/.snapshot/daily.2026.2.1/someData 20 5500000 2>&1 | tee scan.log
...
Folder count matches expected value: 55000000. 
Total folders found: 55000000.
Parallel scan is done
Warning: Found 5500000 folders, which is more than 100000. 
Let me split the folder list into 6 parts:
pass1/folders_part_1
pass1/folders_part_2
pass1/folders_part_3
pass1/folders_part_4
pass1/folders_part_5
pass1/folders_part_6

# To archive using tar using Slurm jobs, each job run 10k folders:
archiveFolders.sh tar sbatch pass1

# Some folders might not work due to permission or some other reason. 
# Let's find the folders not done yet:
$ findFoldersNotDoneArchiving.sh pass1
...
Actual folders: 5500000
Done folders: 5499999
Not done folders: 1
Not done folders are saved to pass2/folders.txt.
Please review logs and see what is the issue: 
$ cat pass1/tarError* 

# If there is permission issues, please run: 
$ find TestingData -exec sh -c 'for f; do [ -d "$f" ] && chmod 775 "$f" || chmod 664 "$f"; done' sh {} +

# If there is any error and need sudo command to set permision, please contact data owner or rchelp@hms.harvard.edu for help 

# Wait for the new .snapshot and update to use new .snapshot
# To updata .snapshot version with the folder paths: 
$ updateSnapshotVersion.sh

# Aftet that, you can run the next pass now: pass2
$ archiveFolders.sh tar sbatch pass2

# To check archives:
$ checkArchives.sh tar local1 pass

# Some folders might not work due to permission or some other reason. 
# Let's find the folders not done yet:
$ findFoldersNotDoneChecking.sh pass1
...
Actual folders: 5500000
Done folders: 5499999
Not done folders: 1
Not done folders are saved to pass2/folders.txt.
Please review logs and see what is the issue: 
$ cat pass1/tarError* 

# If there is permission issues, please run: 
$ find /n/data1/xyz/someData -exec sh -c 'for f; do [ -d "$f" ] && chmod 775 "$f" || chmod 664 "$f"; done' sh {} +

# If there is any error and need sudo command to set permision, please contact data owner or rchelp@hms.harvard.edu for help 

# Wait for the new .snapshot and update to use new .snapshot
# To updata .snapshot version with the folder paths: 
$ updateSnapshotVersion.sh

# Aftet that, you can run the next pass now: pass2
$ checkArchives.sh tar sbatch pass2

# To randomly un-archieve 10 folder and compare with original:
$ randomUnarchiveToCheck.sh tar pass1 10

# Sometimes, an .snapshot may outdated. 
# To updata .snapshot version with the folder paths: 
$ updateSnapshotVersion.sh

```
