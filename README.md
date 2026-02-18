# Archieve Small Files

To decrease number of small file, keep the folder structure, tar all files less than 1G

git clone https://github.com/ld32/archieveSmallFiles.git

export PATH=$PWD/archieveSmallFiles/bin:$PATH

## Prepare a testing data 
createTestData.sh 2 2 2

## To scan folders:
sudoScanFolders.sh TestingData/ 1 55

## To archive using tar:
archiveFolders.sh tar local pass1

## To check archives
checkArchives.sh tar local pass1

## To randomly un-archieve 10 folder and compare with original
randomCheck.sh tar pass1 10

# Working with real data

## To scan folders:
sudoScanFolders.sh TestingData/ 20 55000000

## To archive using tar and each job runs 10k folders:
archiveFolders.sh tar sbatch pass1

## To check archives and each job works on 10k folders
checkArchives.sh tar sbatch pass1

## To randomly un-archieve 10 folder and compare with original
randomCheck.sh tar pass1 1000




