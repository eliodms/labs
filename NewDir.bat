@echo off
REM Create a new directory
md NewDir

REM Change into the new directory
cd NewDir

REM Create random files
echo Random content 1 > file1.txt
echo Another line of text > file2.txt
echo More data in this file > file3.txt

REM Optionally list the files
dir

echo Done.
