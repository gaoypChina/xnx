@echo off

set PRJ=xnx
set APP=app
set BIN=bin
set OST=Windows
set OST_LC=windows

set ZIP=%APP%\%PRJ%-%OST_LC%.zip
set BIN_OST=%BIN%\%OST%\%PRJ%

if "%1" == "-k" (MOVE=--move) else (MOVE=)

rem Reset errorlevel
ver > nul

%~d0
if errorlevel 1 exit /B 1

cd %~dp0..
if errorlevel 1 exit /B 1

if not exist "%BIN_OST%" (
    mkdir "%BIN_OST%"
    if errorlevel 1 exit /B 1
)

call dart pub get
if errorlevel 1 exit /B 1

dart compile exe "%BIN%\main.dart" -o "%BIN_OST%\%PRJ%.exe"
if errorlevel 1 exit /B 1

set OSTYPE=%OST%
call scripts\mkicons\mkicons %*
if errorlevel 1 exit /B 1

copy /Y examples "%BIN_OST%"
if errorlevel 1 exit /B 1

copy /Y "README.md" "%BIN_OST%"
if errorlevel 1 exit /B 1

"%BIN%_%OST%\%PRJ%" %MOVE% --zip "%BIN_OST%" "%ZIP%"

del /S /Q "%BIN%\%OST%"

exit /B 0
