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

# To scan folders:
$ sudoScanFolders.sh TestingData/ 1 55
...
Folder count matches expected value: 55. Total folders found: 55.

# To archive using tar:
archiveFolders.sh tar local pass1

# Some folders will not work due to permission or some other reason. 
# Let's find the folders not done yet:
$ findFoldersNotDoneArchiving.sh pass1
...
Actual folders: 55
Done folders: 53
Not done folders: 2
Not done folders are saved to pass2/folders.txt.
Please review logs and see what is the issue: 
$ cat pass1/tarError* 

If there is permission issues, please run: 
$ sudoCorrectPermission.sh pass2 4

Aftet that, you can run the next pass now: pass2
$ archiveFolders.sh tar local pass2

# To check archives:
$ checkArchives.sh tar local pass

# Some folders might not work due to permission or some other reason. 
# Let's find the folders not done yet:
$ findFoldersNotDoneChecking.sh pass1
...
Actual folders: 55
Done folders: 53
Not done folders: 2
Not done folders are saved to pass2/folders.txt.
Please review logs and see what is the issue: 
$ cat pass1/tarError* 

If there is permission issues, please run: 
$ sudoCorrectPermission.sh pass2 4

Aftet that, you can run the next pass now: pass2
$ checkArchives.sh tar local pass2

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
                            sudo tar --exclude ".md5sum" --overwrite -xf "$1" -C "$2"
                        else
                            sudo cp -a "$1" "$2/"
                        fi
                    fi    
            ' _ {} $dPath

# Using scripts
$ unArchives.sh tar local pass2 # todo: need more work
```

## Working with real data
``` bash
# Start an interactive job, create a working directory where you 
# want to keep the archived data and go to it: 
$ srun -p short -t 12:0:0 --mem 8G --pty /bin/bash 
$ cd /some/big/storage/
$ mkdir -p tarFprReal 
$ cd tarForReal

# Check Starfish website and find the actul folder count, 
# for example 5500000 folders, 
# then scan folders using 20 processes:
$ sudoScanFolders.sh /n/data1/xyz/.snapshot/daily.2026.2.1/someData 20 5500000
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

If there is permission issues, please run: 
$ sudoCorrectPermission.sh pass2 4

Aftet that, you can run the next pass now: pass2
$ checkArchives.sh tar sbatch pass2

# To check archives:
$ checkArchives.sh tar local pass

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

If there is permission issues, please run: 
$ sudoCorrectPermission.sh pass2 4

Aftet that, you can run the next pass now: pass2
$ checkArchives.sh tar sbatch pass2

# To randomly un-archieve 10 folder and compare with original:
randomUnarchiveToCheck.sh tar pass1 10

# When we help with lab data, the tarred data 
# need set proper ownership and permission.
# If folder list is not very large, 
# set ownership and permission using 4 processes: 
$ sudoSetOwnerPermision.sh pass1 4

# Or if folder list is huge, run 6 interactive 
# jobs and each job run 1 subset folders: 
# srun -p short --mem 8G -t 5:0:0 --pty /bin/bash
$ sudoSetOwnerPermisionParts.sh pass1 4 1

# srun -p short --mem 8G -t 5:0:0 --pty /bin/bash
$ sudoSetOwnerPermision.sh pass1 4 2

# srun -p short --mem 8G -t 5:0:0 --pty /bin/bash
$ sudoSetOwnerPermision.sh pass1 4 3

# srun -p short --mem 8G -t 5:0:0 --pty /bin/bash
$ sudoSetOwnerPermision.sh pass1 4 4

# srun -p short --mem 8G -t 5:0:0 --pty /bin/bash
$ sudoSetOwnerPermision.sh pass1 4 5

# srun -p short --mem 8G -t 5:0:0 --pty /bin/bash
$ sudoSetOwnerPermision.sh pass1 4 6

# Sometimes, an .snapshot may outdated. 
# To updata .snapshot version with the folder paths: 
$ updateSnapshotVersion.sh

```
