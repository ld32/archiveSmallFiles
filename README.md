# Archieve Small Files

To decrease number of small file, keep the folder structure, tar all files less than 1G

git clone https://github.com/ld32/archieveSmallFiles.git

export PATH=$PWD/archiveSmallFiles/bin:$PATH

## Practice with testing data

```
# Prepare a testing data: 
$ createTestData.sh 2 2 2
...
Test data generation complete. It is in /n/scratch/TestingData. One folder and one file are set to not readable.

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
You can run the next pass now: pass2
archiveFolders.sh tar local/sbatch pass2
Or, if there are permission issues, please run:
sudoCorrectPermission.sh pass2 4

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
You can run the next pass now: pass2
archiveFolders.sh tar local/sbatch pass2
Or, if there are permission issues, please run:
sudoCorrectPermission.sh pass2 4

# To randomly un-archieve 10 folder and compare with original:
randomUnArchiveToCheck.sh tar pass1 10
```

## Working with real data
```
# Check Starfish website and find the actul folder count for example 5500000 folders, 
# then scan folders using 20 processes:
$ sudoScanFolders.sh /n/grouns/xya/.snapshot/daily.2025.12.1/someData 20 5500000
...
Folder count matches expected value: 55000000. 
Total folders found: 55000000.

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
You can run the next pass now: pass2
archiveFolders.sh tar local/sbatch pass2
Or, if there are permission issues, please run:
sudoCorrectPermission.sh pass2 4

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
You can run the next pass now: pass2
archiveFolders.sh tar local/sbatch pass2
Or, if there are permission issues, please run:
sudoCorrectPermission.sh pass2 4

# To randomly un-archieve 10 folder and compare with original:
randomUnarchiveToCheck.sh tar pass1 10

# When we help with lab data, the tarred data need set proper ownership and permission.
# Set ownership and permission using 4 processes: 
$ sudoSetOwnerPermision.sh pass1 4

# Sometimes, an .snapshot may outdated. 
# To updata .snapshot version: 
$ updateSnapshotVersion.sh

```
