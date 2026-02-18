# Archieve Small Files

To decrease number of small file, keep the folder structure, tar all files less than 1G

git clone https://github.com/ld32/archieveSmallFiles.git

export PATH=$PWD/archiveSmallFiles/bin:$PATH

## Practice with testing data

```
## Prepare a testing data 
$ createTestData.sh 2 2 2
...
Test data generation complete. It is in /n/scratch/TestingData

## To scan folders:
$ sudoScanFolders.sh TestingData/ 1 55
...
Folder count matches expected value: 55. Total folders found: 55.

## To archive using tar:
archiveFolders.sh tar local pass1


## Some folders might not work due to permission or some other reason. Let's find the folders not done yet
$ findFoldersNotDoneArchiving.sh pass1
...
Actual folders: 55
Done folders: 54
Not done folders: 1
Next pass folders.txt already exists. It is renamed.
Not done folders are saved to pass2/folders.txt.
You can run the next pass now: pass2
archiveFolders.sh tar local/sbatch pass2
or:
checkArchives.sh tar local/sbatch pass2
Or, if there are permission issues, please run:
sudoCorrectPermission.sh pass2 4

## To check archives
$ checkArchives.sh tar local pass

## Some folders might not work due to permission or some other reason. Let's find the folders not done yet
$ findFoldersNotDoneChecking.sh pass1
...
Actual folders: 55
Done folders: 54
Not done folders: 1
Not done folders are saved to pass2/folders.txt.
You can run the next pass now: pass2
or:
checkArchives.sh tar local/sbatch pass2
Or, if there are permission issues, please run:
sudoCorrectPermission.sh pass2 4

## To randomly un-archieve 10 folder and compare with original
randomCheck.sh tar pass1 10
```

# Working with real data

```
## To scan folders:
sudoScanFolders.sh TestingData/ 20 55000000

## To archive using tar and each job runs 10k folders:
archiveFolders.sh tar sbatch pass1

## To check archives and each job works on 10k folders
checkArchives.sh tar sbatch pass1

## To randomly un-archieve 100 folder and compare with original
randomCheck.sh tar pass1 1000



```
