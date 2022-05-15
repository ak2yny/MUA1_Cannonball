@echo off


REM ---------------------------------------------------------------------------------

REM Settings:

REM What operation should be made? (Extract to JSON and sound files =extract; combine JSON and sound files again =combine; add WAV files to JSON =addWAV; convert WAVs =convert; detect operation by extension =detect; edit a JSON file =editJSON; =ask)
set operation=detect
REM Remove the input files when done? (Yes =true; No =false)
REM WARNING: Don't set it to =true, unless you're 100% sure you don't need them anymore!
set delInputFiles=false
REM Sample rate? (default mono, half quality =22050; default quality, must still be mono =44100; MUA high quality, some music =44100; ask each time set samfreq=)
REM For all exist some mono and some stereo (and higher quality some multi channel) sounds, but stereo doesn't work yet.
set samfreq=22050
REM Location of uninstalled Zsnd (folder wher zsnd.py and hashes.json are in)?
set "zsndp=%~dp0zsnd"
REM Force using uninstalled version of Zsnd? (Yes =true; No =false)
REM outfile must be false, or a location, as this version requires a full path
set forcezsnd=true

REM Extract Settings:
REM Extract to the input folder? (yes, extract at same location as file =true; no, extract to where Zsnd..bat is =false)
set outfile=false

REM addWAV Settings:
REM Specify a JSON file to add the sounds to. This is useful for x_voice for example. (Or to build a sound file one WAV file at a time)
REM Optionally also specify a path to MUA, or MUA mod folder, or OpenHeroSelect (Ask for it each time instead =ask)
REM Optionally also specify which format to use for reading herostat.engb when a MUA or MUA mod folder is set. (Raven Format's JSON format =json; NBA2kStuff's format =txt)
set "oldjson=%~dp0x_voice.json"
set "MUAOHSpath=x_voicePack"
set decfmt=txt
REM Define a specific subfolder to move WAV files into. Only for x_voice.
set xvoicefolder=New
REM For the new file: Do you want to be asked for a new name? (ask, even if a JSON has been found or selected =true; only ask if no JSON exists =false; take the name of the input folder instead of the JSON, behaves like false =folder; always take the folder name, will never ask =forcefolder)
REM For other operations, it will take the names of ZSS/ZSM or JSON files respectively.
set askname=false
REM Always create a new sound file? (yes - WAVs are moved to the bat folder =true; yes - WAVs are moved to a subfolder of the bat folder, if not converted =folder; no =false)
REM WARNING: Avoid identical names if dropping files from various sources.
set acreate=false
REM Ask for a new hash? (yes =true; automatically generate "REPLACE_THIS_HASH" =false; automatically generate hash with filename =file; ask but don't add randomindex =nori; ask even if hashes are found =always)
set askhash=true
REM Remove the header of WAV files? (only useful for old versions of Zsnd).
REM (no =false; ask before converting =true; convert always, without asking =always; move the converted files back to the source and make a backup of the unconverted files - behaves like always =source; move the converted files back to the source and replace the unconverted files - behaves like always =replace)
set remHead=always
REM Use the sample-reate of the source JSON? (yes =true; no, use from the initial selection =false)
set asample=false
REM Always finish a sound file when adding files through drag and drop? (yes =true; yes and combine =combine; no, ask if I want to finish it at the end =false)
set afinish=true
REM Do you want to update a JSON (add files) if it is found, instead of creating a new one? (yes =true; no =false)
set updatej=true
REM Choose a sample_index number? (Yes =true; No, just add at the end =false; Yes, same for all =all)
REM =true processes individually, which results in a reverse index order for the new files.
set chooseIndex=false

REM editJSON Settings:
REM Replace the input file? (yes =true; no, create a new one with the .fixed suffix =false)
set replace=false

REM ---------------------------------------------------------------------------------

REM these are automatic settings, don't edit them:
set inext=.wav
if "%operation%" == "ask" call :opswitcher
if "%operation%" == "extract" ( set inext=.zss, .zsm
) else if "%operation%" == "combine" ( set inext=.json
) else if "%operation%" == "detect" set inext=.zss, .zsm, .json, .wav
for %%x in (Zsnd, py) do call :checkTools %%x
if "%operation%" == "editJSON" ( set inext=.json
) else call :checkZsnd
if "%outfile%" == "false" ( set "outfile=%~dp0"
) else if "%outfile%" == "true" set outfile=
if defined outfile if "%forcezsnd%" == "true" set Zsnd=py "%zsndp%\zsnd.py"

if defined oldjson set updatej=true
set filecount=0
if exist "%~dp0error.log" del "%~dp0error.log"

if "%remHead%" == "true" (
 echo.
 choice /m "Do you want to change/remove the header of all input WAVs"
 if ERRORLEVEL 2 set remHead=false
)

:start
set oneonly=
%dragndrop%
for %%p in (%*) do goto isnotbatch

:isbatch
set dragndrop=goto isbatch
for %%e in (%inext%) do call :setupextBa %%e
set "inpath=%~dp0"
call :procfolder
GOTO End
:setupextBa
set inextA=%inextA%*%1, 
EXIT /b

:isnotbatch
set dragndrop=goto isnotbatch
set "inall=%cmdcmdline%"
set "inall=%inall:"=""%"
set "inall=%inall:*"" =%"
set "inall=%inall:~0,-2%"
set "inall=%inall:^=^^%"
set "inall=%inall:&=^&%"
set "inall=%inall: =^ ^ %"
set inall=%inall:""="%
set "inall=%inall:"=""Q%"
set "inall=%inall:  ="S"S%"
set "inall=%inall:^ ^ = %"
set "inall=%inall:""="%"
setlocal enableDelayedExpansion
set "inall=!inall:"Q=!"
for %%p in ("!inall:"S"S=" "!") do (
 if "!!"=="" endlocal
 set infiles=%%p
 2>nul pushd "%%~p" && call :isfolder || call :isfiles
)
GOTO End

:isfolder
for %%e in (%inext%) do call :setupextFo %%e
set "inpath=%infiles:~1,-1%\"
:procfolder
for /f "delims=" %%i in ('dir /b %inextA:~0,-2%') do if not "%inpath%%%~i" == "%~dp0temp.igb" (
 set "fullpath=%inpath%%%~i"
 call :filesetup
 call :%operation%
)
EXIT /b
:setupextFo
set inextA=%inextA%"%infiles:~1,-1%\*%1", 
EXIT /b

:isfiles
set "fullpath=%infiles:~1,-1%"
call :filesetup
for %%e in (%inext%) do if /i "%xtnsonly%" == "%%e" call :%operation%
EXIT /b


:askop
CLS
ECHO.
ECHO %operationtext%
ECHO.
CHOICE /C AS /M "Press 'A' to accept and continue with this process, press 'S' to switch"
IF ERRORLEVEL 2 goto opswitcher
IF ERRORLEVEL 1 EXIT /b
:opswitcher
if "%operation%" == "ask" set operation=convert
if "%operation%" == "extract" set "operation=combine" & set "operationtext=Combine sound files to ZSS/ZSM according to a JSON file." & goto askop
if "%operation%" == "combine" set "operation=editJSON" & set "operationtext=Edit sample indexes in JSON files." & goto askop
if "%operation%" == "editJSON" set "operation=addWAV" & set "operationtext=Add WAV files to a JSON file, according to settings. Then, optinally combine them to ZSS/ZSM." & goto askop
if "%operation%" == "addWAV" set "operation=convert" & set "operationtext=Convert WAV files to be used in ZSS/ZSM files (convert/remove header)." & goto askop
if "%operation%" == "convert" set "operation=extract" & set "operationtext=Extract sound files from ZSS/ZSM files, and create a JSON file with informations." & goto askop
goto askop

:detect
if /i "%xtnsonly%" == ".json" goto combine
if /i "%xtnsonly%" == ".wav" set "operation=addWAV" & goto addWAV
goto extract
EXIT /b

:askfreqrate
CLS
echo Make sure your WAV files are mono ^(1 channel^), 16bit, and one of the following sample frequencies:
echo.
echo 1^) 22050hz
echo 2^) 41000hz
echo 3^) 44100hz
echo 4^) I don't know / they're mixed - Abort
echo    If they're mixed, you can also choose a format and manually change the other ones afterwards
echo.
choice /c "1234" /m "What sample frequenzy are your input files"
if ERRORLEVEL 4 goto End
if ERRORLEVEL 1 set samfreq=22050
if ERRORLEVEL 2 set samfreq=41000
if ERRORLEVEL 3 set samfreq=44100
EXIT /b

:filesetup
for %%i in ("%fullpath%") do (
 set pathonly=%%~dpi
 set pathname=%%~dpni
 set nameonly=%%~ni
 set namextns=%%~nxi
 set xtnsonly=%%~xi
)
EXIT /b

:extract
if exist "%outfile%%nameonly%\" set index=0 & call :safeExtract
if exist "%outfile%%nameonly%.json" set index=0 & call :safeExtract .json
if defined outfile set "back=%cd%" & cd /d "%zsndp%"
echo extracting . . .
%Zsnd% -d "%fullpath%" "%outfile%%nameonly%.json"
if defined outfile cd /d "%back%"
EXIT /b
:safeExtract
set /a index+=1
if exist "%outfile%%nameonly%_BAK%index%%1" ( goto safeExtract
) else ren "%outfile%%nameonly%%1" "%nameonly%_BAK%index%%1"
EXIT /b

:combine
set extension=
if /i "%nameonly:~-2%" == "_m" ( set extension=zsm
) else if /i "%nameonly:~-2%" == "_v" ( set extension=zss
) else if /i "%nameonly%" == "x_common" ( set extension=zsm
) else if /i "%nameonly%" == "x_voice" set extension=zss
if not defined extension (
 echo.
 choice /c MV /m "Combine to [m]aster sounds or [v]oice file"
 if ERRORLEVEL 2 (set extension=zss) else set extension=zsm
)
echo combining . . .
%Zsnd% "%fullpath%" "%pathname%.%extension%" 2>"%~dp0RFoutput.log"
if not %errorlevel%== 0 call :writerror
EXIT /b

:addWAV
if not defined samfreq call :askfreqrate
set /a filecount+=1
if defined oldjson ( if defined jsonname goto addFileJSON
) else echo "%pathlist%"|find /i "%pathonly%" >nul || if not "%pathonly%" == "%~dp0" set pathlist="%pathonly%*.json", 
if not "%remHead%" == "false" goto convert
EXIT /b
:addWAVPost
if defined oldjson ( if defined jsonname ( goto CombineJSON
) else for %%a in ("%oldjson%") do set "jsonname=%%~na"
) else call :listJSON
call :prepJSON
if not "%remHead%" == "false" goto convertPost
goto start

:convert
set "infolder=%pathonly:\=\\%"
call :writeConvJSON
EXIT /b
:convertPost
(call :writebottom)>>"%~dp0toconvert.json"
echo converting . . .
zsnd "%~dp0toconvert.json" "%~dp0toconvert.zss" 2>"%~dp0RFoutput.log"
if not %errorlevel%== 0 call :writerror
set "back=%cd%" & cd /d %zsndp%
py zsnd.py -d "%~dp0toconvert.zss" "%~dp0converted.json"
cd /d %back%
del "%~dp0toconvert.json"
del "%~dp0toconvert.zss"
del "%~dp0converted.json"
if "%remHead%" == "source" (
 choice /m "Do you want to keep a backup of the unconverted WAV files"
 if ERRORLEVEL 2 set remHead=replace
)
if "%operation%" == "addWAV" goto start
EXIT /b

:listJSON
CLS
for %%j in ("%pathonly:~0,-1%") do if exist "%%~fj.json" set "fupjson=%%~fj.json"
for %%j in (%pathlist%"%~dp0*.json", "%fupjson%") do set "oldjson=%%~fj" & set "jsonname=%%~nj" & set /a x+=1 & echo "%%~nxj"
if %x% LEQ 1 EXIT /b
:pickJSON
set jsonname=createnewjson
echo.
set /p jsonname=Multiple JSON files found. Enter the filename to choose one, or just press enter to create an all new one: 
if "%jsonname%" == "createnewjson" EXIT /b
for %%j in (%pathlist%"%~dp0*.json", "%fupjson%") do echo "%%~fj" | find "%jsonname%" && set "oldjson=%%~fj"
if not defined oldjson goto pickJSON
for %%a in ("%oldjson%") do set "jsonname=%%~na"
set updatej=true
EXIT /b

:prepJSON
for %%j in ("%pathonly:~0,-1%") do set "fupjson=%%~fj.json"
if "%jsonname%" == "createnewjson" (
 if "%askname%" == "folder" set askname=true
 if "%askname%" == "false" set askname=true
 for %%a in ("%fupjson%") do set "jsonname=%%~na" 
)
if "%askname:~-6%" == "folder" for %%a in ("%fupjson%") do set "jsonname=%%~na"
if "%askname%" == "true" set /p jsonname=Enter a name for the new sound file, or just press enter to use "%jsonname%": 
REM x is the max index number (min index number is always 0)
set x=-1
if "%updatej%" == "false" EXIT /b
if not defined oldjson EXIT /b
if exist "%~dp0%jsonname%_fileslist.json" if "%afinish%" == "false" set "countjson=%~dp0%jsonname%_fileslist.json" & call :countindex & EXIT /b
call :splitJSON
EXIT /b
:countindex file with full path as countjson
for /f "tokens=3 delims=:" %%a in ('find /c """file"":" "%countjson%"') do set x=%%a
set x=%x:~1%
set /a x-=1
EXIT /b

:splitJSON var as oldjson and jsonname
set "countjson=%oldjson%" & call :countindex
echo Splitting "%jsonname%" . . .
for /f "usebackq delims=" %%a in (`PowerShell "((gc -Path '%oldjson%') | select-string '    \"samples\": \[').LineNumber-3"`) do (
 (PowerShell "gc '%oldjson%' -First %%a")>"%~dp0%jsonname%_hashlist.json"
 for /f "usebackq delims=" %%b in (`PowerShell "(gc '%oldjson%' ).length-4"`) do (
  (PowerShell "(gc '%oldjson%' )[%%a..%%b]")>"%~dp0%jsonname%_fileslist.json"
 )
)
EXIT /b

:splitFileAtLine linenumber; var as oldjson and jsonname
REM Splits after 3 lines above linenumber. Lines 1-3 can't be split.
for /f "delims=0123456789" %%i in ("%1") do EXIT /b
if "%1" == "" EXIT /b
if %1 GTR 5 (set /a n=%1-3) else set n=3
echo Splitting "%jsonname%" . . .
(PowerShell "gc '%oldjson%' -First %n%")>"%oldjson%.top.json"
(more /e +%n% "%oldjson%")>"%oldjson%.bottom.json"
move /y "%oldjson%.top.json" "%oldjson%"
EXIT /b

:splitFileAtIndex indexnumber
REM Splits above file that is at specified index
call :getLineFromIndex %1
call :splitFileAtLine %n%
EXIT /b

:splitHashAtIndex indexnumber
REM Splits above file that is at specified index
call :getHLineFromIndex %1
for %%n in (%nh%) do call :splitFileAtLine %%n & move /y "%oldjson%.bottom.json" "%oldjson%.%%n.json"
EXIT /b

:addFileJSON
set searchline=
set "infolder=%pathonly%"
call :newfolder
REM for %%a in ("%newjson%") do call set "infolder=%%infolder:%%~dpa=%%"
set "infolder=%infolder:\=\\%"
set /a x+=1
set sampleindex="sample_index": %x%,
if not "%chooseIndex%" == "false" call :prepIndex
set filename="file": "%infolder%%namextns%",
if defined oldjson for /f "skip=2 delims=[]" %%l in ('find /i /n "\%nameonly%." "%oldjson%"') do set searchline=%%l
if not defined searchline goto defineNewJSON
:readOldJSON line of filename as var searchline
REM Set samples information, except file:
set /a searchline+=1
call :findLineJSON format %searchline%
set /a searchline+=1
if "%asample%" == "true" ( call :findLineJSON sample %searchline%
) else set sample="sample_rate": %samfreq%
set /a searchline+=1
call :findLineJSON flags %searchline%
echo %flags% | find "}" >nul && set "flags=" || if not "%sample:~-1%" == "," set sample=%sample%,
REM Set hash information, except sample_index:
set hash=
set i=-1
for /f "skip=2 delims=[]" %%l in ('find /n """file"":" "%oldjson%"') do if %%l LEQ %searchline% set /a i+=1
for /f "skip=2 delims=[]" %%s in ('find /n """sample_index"": %i%," "%oldjson%"') do set searchline=%%s
set /a searchline-=1
call :findLineJSON hash %searchline%
set /a searchline+=2
call :findLineJSON flagsh %searchline%
if "%askhash%" == "always" call :hashgen
goto writeJSON
:defineNewJSON
set format="format": 106,
set sample="sample_rate": %samfreq%
set flags=
REM looping has not been implemented yet. flags is 2 for stereo, and 34 for 4 channel.
if defined loopSound set flags="flags": 1
if defined flags set sample=%sample%,
call :hashgen
set flagsh="flags": 31
REM recent voices usually have flag 255, but it's probably better to change it afterwards
:writeJSON
echo Generating sound database . . .
set oneonly=done
if %x% EQU 0 (
 (call :writetophash)>"%~dp0%jsonname%_hashlist.json"
 (call :writetopfile)>"%~dp0%jsonname%_fileslist.json"
) else (
 (call :writehash)>>"%~dp0%jsonname%_hashlist.json"
 (call :writefile)>>"%~dp0%jsonname%_fileslist.json"
)
if "%chooseIndex%" == "true" call :finishIndex
EXIT /b

:findLineJSON var; line; searchfile as oldjson
for /f "tokens=1* delims=[]" %%a in ('find /v /n "" "%oldjson%" ^| find "[%2]"') do call :trimmer %%b
set %~1=%trim%
EXIT /b

:hashgen
if "%jsonname:~0,7%" == "x_voice" call :x_voiceHash & if defined hashname goto setHash
set hashname=REPLACE_THIS_HASH
if %askhash%==false goto setHash
set "hashname=%nameonly%"
if %askhash%==file goto setHash
if defined hash (set "hashname=%hash:~9,-2%")
echo.
set /p hashname=Enter or paste a hash for "%namextns%", or press enter to use "%hashname%": 
:setHash
for /f "delims=" %%h in ('PowerShell "'%hashname%'.ToUpper()"') do set "hashname=%%h"
set hash="hash": "%hashname%",
EXIT /b

:newfolder
if "%jsonname:~0,7%" == "x_voice" goto askfolder
set "targetpath=%fullpath%"
if "%remHead%" == "true" (
 ren "%~dp0converted" "%jsonname%"
 set "infolder=%~dp0%jsonname%\"
) else if "%remHead%" == "source" (
 if not exist "%pathonly:~0,-1%-backup\" mkdir "%pathonly:~0,-1%-backup\"
 move "%fullpath%" "%pathonly:~0,-1%-backup\"
 call :convtofolder
) else if "%remHead%" == "false" if "%acreate%" == "folder" (
 if not exist "%~dp0%jsonname%\" mkdir "%~dp0%jsonname%\"
 move "%fullpath%" "%~dp0%jsonname%\"
 set "infolder=%jsonname%\"
 set "newjson=%~dp0%jsonname%.json"
 EXIT /b
) else if "%remHead%" == "replace" call :convtofolder
if "%acreate%" == "true" ( set "newjson=%~dp0%jsonname%.json"
) else if not defined oldjson ( for %%a in ("%pathonly:~0,-1%.json") do set "newjson=%%~dpa%jsonname%.json"
) else set "newjson=%oldjson%"
EXIT /b
:convtofolder
if not exist "%~dp0converted\%namextns%" (
 echo The converted "%namextns%" could not be found. This is probably due to a too long total file and path name. 
 echo  Check the "converted" folder for any ill-named files and rename them according to the input file. 
 echo  Manually move them to the correct folder, as defined in the JSON file.
)>>"%~dp0error.log" else move /y "%~dp0converted\%namextns%" "%targetpath%"
EXIT /b
:askfolder
for %%i in ("%oldjson%") do set xvpath=%%~dpi
CLS
if not defined xvoicefolder (
 echo.
 dir /b /ad "%xvpath%"
 echo.
 set /p xvoicefolder=Choose an existing folder from the list by entering the name exactly as displayed. Entering a different name creates a new folder: 
 goto askfolder
)
if not exist "%xvpath%%xvoicefolder%" mkdir "%xvpath%%xvoicefolder%"
set "targetpath=%xvpath%%xvoicefolder%"
if "%remHead%" == "false" ( copy "%fullpath%" "%xvpath%%xvoicefolder%"
) else call :convtofolder
set "infolder=%xvoicefolder%\"
set "newjson=%oldjson%"
EXIT /b
:x_voiceHash
if "%MUAOHSpath%" == "ask" set "MUAOHSpath=" & set /p "MUAOHSpath=Please paste or enter the path to the MUA installation, or MUA mod folder, or OpenHeroSelect here: "
if not defined MUAOHSpath EXIT /b
if defined charactername EXIT /b
if exist "%MUAOHSpath%\mua\xml\" ( set "charactername=invalid" & call :OHSherostats
) else if exist "%MUAOHSpath%\data\herostat.engb" ( call :MUAherostats || EXIT /b
) else goto askIntName
set /p version=<"%herostat%"
if "%version:~0,1%" == "<" ( set "searchstring=%searchstring:.*==\""%\"""
) else if "%version%" == "{" ( set "searchstring=%searchstring:.*=.: \""%\"","
) else set "searchstring=%searchstring:.*= = % ;"
for /f "usebackq delims=" %%a in (`PowerShell "((gc -Path '%herostat%') | select-string -Pattern '%searchstring%').LineNumber"`) do set /a x=%%a
call :findIntName
choice /m "Do you want to use "%charactername%" for the hash for all remaining input files"
if not ERRORLEVEL 2 set charactername=
:calloutORbreak
choice /c CBX /m "Is '%nameonly%' a name [c]allout or a [b]reak line (press [X] if it's something else)"
if ERRORLEVEL 3 set "hashname=" & EXIT /b
if ERRORLEVEL 1 set hashprefix=COMMON/MENUS/CHARACTER/AN_
if ERRORLEVEL 2 set hashprefix=COMMON/MENUS/CHARACTER/BREAK_
if "%hashname%" == "%lasthash%" (set /a randomindex+=1) else call :countHashes
set "lasthash=%hashname%"
if %askhash%==nori (set randomindex=) else set randomindex=/***RANDOM***/%randomindex%
set "hashname=%hashprefix%%hashname%%randomindex%"
EXIT /b
:askIntName
set /p hashname=Enter the internal name for "%nameonly%": 
if defined hashname (goto calloutORbreak) else EXIT /b
:findIntName
for /f "usebackq skip=%x% delims=" %%s in ("%herostat%") do (
 set linein=%%s
 call :filterSkins && EXIT /b
)
EXIT /b
:filterSkins
echo "%linein:"=%"|find /i " name" >nul && call :JsonNBA2kSreader hashname 4
echo "%linein:"=%"|find /i " name" >nul && EXIT /b
notdoneyet 2>nul
EXIT /b
:countHashes
set randomindex=0
for /f "usebackq delims=" %%a in (`PowerShell "((gc -Path '%oldjson%') | select-string -Pattern '%hashprefix%%hashname%').Line"`) do set /a randomindex+=1
EXIT /b

:CombineJSON
if "%chooseIndex%" == "all" call :finishIndex
if "%afinish%" == "false" (
 choice /m "Do you want to finish the sound file (press N if you want to add more files)"
 if ERRORLEVEL 2 EXIT /b
)
if exist "%newjson%" for %%j in ("%newjson%") do ren "%newjson%" "%%~nj.bkp.json"
copy "%~dp0%jsonname%_hashlist.json"+"%~dp0%jsonname%_fileslist.json" "%newjson%" /b
(call :writebottom)>>"%newjson%"
if exist "%~dp0%jsonname%_fileslist.json" del "%~dp0%jsonname%_fileslist.json"
if exist "%~dp0%jsonname%_fileslist.json.bottom.json" del "%~dp0%jsonname%_fileslist.json.bottom.json"
if exist "%~dp0%jsonname%_hashlist.json" del "%~dp0%jsonname%_hashlist.json"
if not "%afinish%" == "combine" EXIT /b
set "fullpath=%newjson%"
call :filesetup
call :combine
EXIT /b

:addFileAtIndex index number; var as oldjson
REM Set oneonly=direct to process files directly from other operations.
REM Direct processing reverts the index order of the input files if they are multiple.
set /a filecount+=1
for %%a in ("%oldjson%") do set "jsonname=%%~na"
set "infolder=%pathonly:\=\\%"
set filename="file": "%infolder%%namextns%"
set format="format": 106,
set sample="sample_rate": %samfreq%
call :hashgen
set flagsh="flags": 31
if not defined oneonly ( call :splitJSON & set oneonly=prepared
) else if "%oneonly%" == "direct" call :splitJSON
call :prepIndex %1
set sampleindex="sample_index": %c%,
(call :writehash)>>"%~dp0%jsonname%_hashlist.json"
(call :writefile)>>"%~dp0%jsonname%_fileslist.json"
if "%oneonly%" == "direct" call :finishIndex 1
EXIT /b
:addFileAtIndexPost
if "%oneonly%" == "direct" EXIT /b
call :finishIndex %filecount%
EXIT /b
:prepIndex
if "%updatej%" == "false" EXIT /b
if not defined oldjson EXIT /b
CLS
if "%chooseIndex%" == "all" if defined backupjson set /a c+=1 & EXIT /b
set i=%1
set c=%1
if not defined i set /p i=Enter the sample_index number to add "%nameonly%" on, or enter the filename after which to add it: 
if not defined i EXIT /b
set "backupjson=%oldjson%" & set "oldjson=%~dp0%jsonname%_fileslist.json"
set "n=" & for /f "delims=0123456789" %%i in ("%i%") do set "n=%%i"
if defined n ( set "s=%i%" & set next=true & call :getIndex
) else call :getLineFromIndex %i%
call :splitFileAtLine %n%
:finishIndex
set "oldjson=%~dp0%jsonname%_hashlist.json"
set replace=true
set /a c+=1
call :fixIndex %i% %c%
set "oldjson=%backupjson%"
copy /y "%~dp0%jsonname%_fileslist.json"+"%~dp0%jsonname%_fileslist.json.bottom.json" "%~dp0%jsonname%_fileslist.fixed.json" /b
move /y "%~dp0%jsonname%_fileslist.fixed.json" "%~dp0%jsonname%_fileslist.json"
EXIT /b
:getIndex filename (or as var s)
if not "%~1" == "" set "s=%~1"
set i=-1
setlocal enableDelayedExpansion
for /f "skip=2 tokens=1,2* delims=[]: " %%a in ('find /n """file"": " "%oldjson%"') do (
 set /a i+=1 & set "n=%%a"
 if defined loop goto getIndex2
 for %%w in (%%c) do echo %%~nxw | find "%s%" >nul && if defined next (set loop=done) else goto getIndex2
)
endlocal
EXIT /b
:getIndex2
endlocal & set "i=%i%" & set "n=%n%"
EXIT /b
:getIndexHash hash linenumber
set /a s=%1+1
for /f "tokens=1-3 delims=[]:, " %%a in ('find /n """sample_index"":" "%oldjson%" ^| find "[%s%]"') do set i=%%c
EXIT /b
:getLine filename or hashname (or as var s)
if not "%~1" == "" set "s=%~1"
for /f "skip=2 tokens=1,2 delims=[]:, " %%a in ('find /n "%s%" "%oldjson%"') do (
 set n=%%a
 if %%b == "file" ( call :getIndex & EXIT /b
 ) else if %%b == "hash" call :getIndexHash %%a
)
EXIT /b
:getHLineFromIndex indexnumber
set nh=
setlocal enableDelayedExpansion
for /f "skip=2 tokens=1 delims=[]" %%a in ('find /n """sample_index"": %1," "%oldjson%"') do call :setLineAbove %%a & set nh=!n! !nh!
endlocal & set nh=%nh%
EXIT /b
:setLineAbove linenumber
set n=%1
set /a n-=1
EXIT /b
:getLineFromIndex indexnumber
set n=-1
setlocal enableDelayedExpansion
for /f "skip=2 tokens=1 delims=[]" %%a in ('find /n """file"": " "%oldjson%"') do (
 set /a n+=1
 if !n! EQU %1 endlocal & set "n=%%a" & EXIT /b
)
endlocal & set /a i=%n%+1
for /f usebackq %%n in (`PowerShell "(gc -Path '%oldjson%').length"`) do set n=%%n
find /n """sample_rate"":" "%oldjson%" | find "[%n%]" >nul && set /a n+=3
EXIT /b

:editJSON
set "oldjson=%fullpath%"
for %%a in ("%oldjson%") do set "jsonname=%%~na"
CLS
echo 1^) Free index number^(s^).
echo 2^) Create a new index.
echo 3^) Remove index number^(s^), hash or file.
echo 4^) Move index number^(s^) or file.
echo.
choice /c 1234 /m "What do you want to do with %namextns%"
IF ERRORLEVEL 4 goto moveIndexS
IF ERRORLEVEL 3 goto removeIndex
IF ERRORLEVEL 2 goto fixIndex
IF ERRORLEVEL 1 goto freeIndex

:freeIndex number
set range=%1
if not defined range set /p range=Enter the sample_index number^(s^) to free. Eg. "20-25" or "9": 
if not defined range EXIT /b
for /f "tokens=1,2 delims=-" %%a in ("%range%") do set "a=%%a" & set "b=%%b"
if defined b ( set /a c=%b%+1 ) else set /a c=%a%+1
call :fixIndex %a% %c%
EXIT /b
:removeIndex index or filename
set range=%~1
echo.
if not defined range set /p range=Enter the sample_index number^(s^) to remove - Eg. "20-25" or "9", or enter a file or hash ^(which cannot consist of numbers only^): 
if not defined range EXIT /b
set "nr=" & for /f "delims=0123456789- " %%i in ("%range%") do set "nr=%%i"
if defined nr ( set "s=%range%" & call :getLine
) else for /f "tokens=1,2 delims=- " %%a in ("%range%") do call :removeRange %%a %%b & EXIT /b
call :removeRange %i%
EXIT /b
:moveIndexS sourceIndex or filename; targetIndex
REM Inserted above the target index (if exist)
set range=%~1
set nindex=%2
echo.
if not defined range set /p range=Enter the sample_index number^(s^) to move - Eg. "20-25" or "9", or enter a file ^(which cannot consist of numbers only^): 
if not defined range EXIT /b
if not defined nindex set /p nindex=Enter the lowest index number, to move the selection to: 
if not defined nindex EXIT /b
for /f "delims=0123456789" %%i in ("%nindex%") do goto moveIndexS
set "nr=" & for /f "delims=0123456789- " %%i in ("%range%") do set "nr=%%i"
if defined nr ( set "s=%range%" & call :getIndex
) else for /f "tokens=1,2 delims=- " %%a in ("%range%") do call :moveTarget %nindex% %%a %%b & EXIT /b
if %i% EQU %nindex% EXIT /b
call :moveTarget %nindex% %i%
EXIT /b
:moveTarget targetIndex; minSourceIndex; optional maxSourceIndex
REM oldjson and fullpath must be identical for this one
if "%2" == "" call :moveIndexS
call :checkTarget %1 %2 %3
call :splitJSON
set "oldjson=%~dp0%jsonname%_hashlist.json"
call :fixIndex %1 "" %d%
if "%replace%" == "false" move /y "%oldjson%.fixed.json" "%oldjson%"
set nindex=%1
for /l %%i in (%a% 1 %b%) do call :replaceIndex %%i & set /a nindex+=1
set /a b+=1
call :fixIndex %b% %a%
if "%replace%" == "false" move /y "%oldjson%.fixed.json" "%oldjson%"
set "oldjson=%~dp0%jsonname%_fileslist.json"
call :moveBlock %1 %2 %3
if "%replace%" == "false" del "%oldjson%.bak"
copy "%~dp0%jsonname%_hashlist.json"+"%~dp0%jsonname%_fileslist.json" "%pathname%.fixed.json" /b
(call :writebottom)>>"%pathname%.fixed.json"
if "%replace%" == "true" move /y "%pathname%.fixed.json" "%fullpath%"
del "%~dp0%jsonname%_fileslist.json"
del "%~dp0%jsonname%_hashlist.json"
EXIT /b
:replaceIndex sourceIndex; targetIndex as nindex
for /f "skip=2 tokens=1 delims=[]" %%a in ('find /n """sample_index"": %1," "%oldjson%"') do (
 set newline="sample_index": %nindex%,
 (call :replaceLine %%a)>"%oldjson%.fixed.json"
 move /y "%oldjson%.fixed.json" "%oldjson%"
)
EXIT /b
:removeRange indexnumber(s)
REM oldjson and fullpath must be identical for this one
call :sortTwo %1 %2
if not defined b set b=%1
call :splitJSON
set "oldjson=%~dp0%jsonname%_hashlist.json"
for /l %%i in (%a% 1 %b%) do call :removeHashIndex %%i
set /a i=%b%+1
call :fixIndex %i% %a%
if "%replace%" == "false" move /y "%oldjson%.fixed.json" "%oldjson%"
set "oldjson=%~dp0%jsonname%_fileslist.json"
call :removeFileRange %a% %b%
copy "%~dp0%jsonname%_hashlist.json"+"%~dp0%jsonname%_fileslist.json" "%pathname%.fixed.json" /b
(call :writebottom)>>"%pathname%.fixed.json"
if "%replace%" == "true" move /y "%pathname%.fixed.json" "%fullpath%"
del "%~dp0%jsonname%_fileslist.json"
del "%~dp0%jsonname%_hashlist.json"
EXIT /b
:setIndex
CLS
echo To create a new index: instead of entering a number, just press enter. But make sure that the file and hash count are identical and that they are in the same order.
echo.
if not defined i set /p i=Enter the lowest incorrect index number: 
if defined i set /p c=Enter the correct new index number for it: 
EXIT /b
:fixIndex lowest incorrect index; new index for it; difference
REM requires JSON file as oldjson and jsonname
set i=%1
set c=%~2
set d=%3
set x=-1
if not defined c if not defined d set i=
if not defined i call :setIndex
if not defined d set /a d=%c%-%i% 2>nul
echo fixing index for "%jsonname%" . . .
(for /f "usebackq delims=" %%a in ("%oldjson%") do echo %%a|find /v """sample_index"": " || call :moveIndex %%a %i% %d%)>"%oldjson%.fixed.json"
if "%replace%" == "true" move /y "%oldjson%.fixed.json" "%oldjson%"
EXIT /b
REM Powershell is not faster. Find and Findstr slows it down.
REM PowerShell "gc -Path '%oldjson%' -First [sampleindexlinenumber]"
REM Use this pipe to add new lines: " | Select-Object -Last %lastline%"
REM Use this pipe to add rem lines: " | Select-Object -Skip %lastline%"
:moveIndex whole line; lowest index to move; value to move
REM only echos line with new index
if "%3" == "" ( set /a x+=1
) else if %2 LSS %3 ( set x=%2
) else set /a x=%2+%4
echo             "sample_index": %x%,
EXIT /b
:moveBlock targetIndex; minSourceIndex; optional maxSourceIndex
if not defined a call :checkTarget %1 %2 %3
if not defined nindex set /a b+=1
if "%replace%" == "false" copy /y "%oldjson%" "%oldjson%.bak"
if "%target%" == "less" goto moveBlock2
call :splitFileAtIndex %1
move /y "%oldjson%.bottom.json" "%oldjson%.last.json"
call :extractBlock
move /y "%oldjson%.bottom.json" "%oldjson%.tomove2.json"
goto combineMoved
:moveBlock2
call :extractBlock
move "%oldjson%.first.json" "%oldjson%"
move /y "%oldjson%.bottom.json" "%oldjson%.last.json"
call :splitFileAtIndex %1
move "%oldjson%" "%oldjson%.first.json"
move /y "%oldjson%.tomove1.json" "%oldjson%.tomove2.json"
move "%oldjson%.bottom.json" "%oldjson%.tomove1.json"
:combineMoved
call :sortTwo %a% %1
if %a% EQU 0 (
 more +1 "%oldjson%.tomove1.json">"%oldjson%.tomove1.fixed.json"
 move /y "%oldjson%.tomove1.fixed.json" "%oldjson%.tomove1.json"
 (echo         },&type "%oldjson%.tomove2.json")>"%oldjson%.tomove2.fixed.json"
 move /y "%oldjson%.tomove2.fixed.json" "%oldjson%.tomove2.json"
)
copy "%oldjson%.first.json"+"%oldjson%.tomove2.json"+"%oldjson%.tomove1.json"+"%oldjson%.last.json" "%oldjson%" /b
del "%oldjson%.first.json"
del "%oldjson%.tomove1.json"
del "%oldjson%.tomove2.json"
del "%oldjson%.last.json"
EXIT /b
:extractBlock
call :splitFileAtIndex %a%
move /y "%oldjson%" "%oldjson%.first.json"
move "%oldjson%.bottom.json" "%oldjson%"
set /a b=%b%-%a%
call :splitFileAtIndex %b%
move /y "%oldjson%" "%oldjson%.tomove1.json"
EXIT /b
:checkTarget targetIndex; minSourceIndex; optional maxSourceIndex
call :sortTwo %2 %3
if defined b ( call :diffeRange %3 %2 d
) else set "b=%2" & set d=1
if %1 GTR %b% EXIT /b
if %1 LSS %a% set "target=less" & EXIT /b
echo.
echo The source index number^(s^) cannot contain the target index number.
goto Errors
EXIT /b
:removeHash hash (or as var s)
if not "%~1" == "" set "s=%~1"
call :getLine
call :splitFileAtLine %n%
more +5 "%oldjson%.bottom.json">>"%oldjson%"
del "%oldjson%.bottom.json"
EXIT /b
:remHashIndxFix indexnumber
call :removeHashIndex %1
set /a i=%1+1
call :fixIndex %i% %1
EXIT /b
:removeHashIndex indexnumber
call :splitHashAtIndex %1
setlocal enableDelayedExpansion
for %%n in (%nh%) do set na=%%n !na!
endlocal & set nh=%na%
for %%n in (%nh%) do more +5 "%oldjson%.%%n.json">>"%oldjson%"
for %%n in (%nh%) do del "%oldjson%.%%n.json"
EXIT /b
:removeFile filename (or as var s)
if not "%~1" == "" set "s=%~1"
call :getIndex
call :removeFileIndex %i%
EXIT /b
:removeFileRange indexnumber1 and 2
call :sortTwo %1 %2
if not defined b goto removeFileIndex
set /a b+=1
call :splitFileAtIndex %b%
move /y "%oldjson%.bottom.json" "%oldjson%.newbottom.json"
call :splitFileAtIndex %a%
set i=%a%
goto finishRemFindex
:removeFileIndex indexnumber
set /a i=%1+1
call :splitFileAtIndex %i%
move /y "%oldjson%.bottom.json" "%oldjson%.newbottom.json"
set /a i-=1
call :splitFileAtIndex %i%
:finishRemFindex
set topline=fix
if %i% EQU 0 set /p topline=<"%oldjson%.bottom.json" & set p= +1
if %i% EQU 0 if "%topline:~-1%" == "[" echo     "samples": [>>"%oldjson%"
more%p% "%oldjson%.newbottom.json">>"%oldjson%"
del "%oldjson%.bottom.json"
del "%oldjson%.newbottom.json"
EXIT /b
:diffeRange number1 number2 var
set /a %~3=%1-%2
call set /a %~3=%%%~3:-=%%+1
EXIT /b
:sortTwo
set "a=%1" & set b=%2
if "%2" == "" EXIT /b
if %1 GTR %2 set "a=%2" & set b=%1
EXIT /b
:sortThree
REM Both sorts store the numbers in ascending order in var a, b, and c
call :sortTwo %1 %2
if not defined b EXIT /b
if "%3" == "" EXIT /b
set c=%3
if %3 GTR %b% EXIT /b
if %3 LSS %a% set "c=%b%" & set "b=%a%" & set "a=%3" & EXIT /b
set "c=%b%" & set b=%3
EXIT /b

:replaceLine line; new value no indent as var newline
set /a line=%1-1
PowerShell "gc -Path '%oldjson%' -First %line%"
echo             %newline%
more /e +%1 "%oldjson%"
EXIT /b

:listIndex
for /f "tokens=2 delims=:, " %%a in ('findstr "\"sample_index\"" ^<"%fullpath%"') do echo %%a
EXIT /b

:writeConvJSON
set filename="file": "%infolder%%namextns%",
set format="format": 106,
set sample="sample_rate": %samfreq%
if not defined oneonly ( call :writetop
) else (call :writefile)>>"%~dp0toconvert.json"
set oneonly=done
EXIT /b

:writetop
echo removing header . . .
(
echo {
echo     "platform": "PC",
echo     "sounds": [
echo         {
echo             "hash": "TOCONVERT",
echo             "sample_index": 0,
echo             "flags": 255
echo         }
echo     ],
echo     "samples": [
echo         {
echo             %filename%
echo             %format%
echo             %sample%
)>"%~dp0toconvert.json"
EXIT /b

:writetophash
echo {
echo     "platform": "PC",
echo     "sounds": [
echo         {
echo             %hash%
echo             %sampleindex%
echo             %flagsh%
EXIT /b

:writehash
echo         },
echo         {
echo             %hash%
echo             %sampleindex%
echo             %flagsh%
EXIT /b

:writetopfile
echo         }
echo     ],
echo     "samples": [
echo         {
echo             %filename%
echo             %format%
echo             %sample%
if not defined flags EXIT /b
echo             %flags%
EXIT /b

:writefile
echo         },
echo         {
echo             %filename%
echo             %format%
echo             %sample%
if not defined flags EXIT /b
echo             %flags%
EXIT /b

:writebottom
echo         }
echo     ]
echo }
EXIT /b


:MUAherostats
xmlb 2>nul
if %errorlevel%==9009 ( if exist "%~dp0json2xmlb.exe" set xmlbc="%~dp0json2xmlb.exe"
) else set xmlbc=xmlb
if "%decfmt%" == "txt" (
 if exist C:\Windows\xmlb-compile.exe ( set xmlbc=xmlb-compile -s
 ) else if exist "%~dp0xmlb-compile.exe" set xmlbc="%~dp0xmlb-compile.exe" -s
 set writeto=^>
)
if not defined xmlbc error 2>nul & EXIT /b
set "herostat=%MUAOHSpath%\data\herostat.%decfmt%"
if exist "%MUAOHSpath%\data\herostat.%decfmt%" EXIT /b
%xmlbc% -d %MUAOHSpath%\data\herostat.engb" %writeto% "%MUAOHSpath%\data\herostat.%decfmt%"
EXIT /b

:OHSherostats
for /f "usebackq skip=3 delims=" %%a in (`PowerShell "dir -Path '%MUAOHSpath%\mua\xml\*.xml' | select-string -Pattern 'charactername = %charactername% ;' -List | Select Path"`) do set herostat=%%~fh
if not defined herostat (
 set "herostat=%MUAOHSpath%\mua\xml\*.xml"
 call :pickChar
 set herostat=
 goto OHSherostats
)
EXIT /b

:pickChar
CLS
set x=0
for /f "usebackq delims=" %%n in (`PowerShell "(Select-String -Path '%herostat%' -Pattern "charactername" -Encoding ASCII).Line"`) do (
 set /a x+=1
 set "charactername=%%n"
 call :prettyPrintCharName
)
if %x% GTR 1 (
 set charactername=invalid
 set /p charactername=Multiple characters found. Choose one from the list above by entering the name exactly as printed: 
)
set "searchstring=charactername.*%charactername%"
EXIT /b
:prettyPrintCharName
set "charactername=%charactername:*charactername=%"
if "%charactername:~-1%" == ">" (
 set "xmlstring=%charactername%"
 call :XMLfilter charactername
 set charactername=%xmlstring:~0,-1%
) else if "%charactername:~-1%" == "," ( set charactername=%charactername:~4,-2%
) else if "%charactername:~-1%" == ";" set charactername=%charactername:~3,-2%
echo %charactername%
EXIT /b

:JsonNBA2kSreader var; lenght of left value; full line as var linein
REM indent only for herostat (6/14).
set /a indent=%2+6
call set %~1=%%linein:~%indent%,-2%%
if "%linein:~-1%" == ";" EXIT /b
set "%~1=%linein:"=%"
set /a indent=%2+14
call set %~1=%%%~1:~%indent%,-1%%
EXIT /b


:trimmer
set "trim=%*"
EXIT /b

:writerror
set errfile=
for /f "skip=2 delims=" %%e in ('find /i "error" "%~dp0RFoutput.log" 2^>nul') do set "msg=%%e" & call :writeMsg
EXIT /b
:writeMsg
if not defined errfile echo "%fullpath%" >>"%~dp0error.log"
set "errfile=%nameonly%"
echo  %msg:&=^&% >>"%~dp0error.log"
EXIT /b

:checkTools program extension
if "%~2" == "" (set exe=exe) else set exe=%2
for /f "delims=" %%a in ('where %1 2^>nul') do set %1=%1
if not defined %1 if exist "%~dp0%1.%exe%" set %1="%~dp0%1.%exe%"
EXIT /b
:checkZsnd
REM if not defined Zsnd if exist "%zsndp%\zsnd.py" ( set Zsnd=py "%zsndp%\zsnd.py"
REM ) else call :checkPython
REM EXIT /b
:checkPython
if defined py (
 for /f "delims=" %%a in ('where zsnd 2^>nul') do goto setRF
 PATH | find "Programs\Python\Python" >nul && goto instRF
)
echo Python is not correctly installed. Check the Readme.
goto Errors
:instRF
pip install raven-formats
:setRF
set xmlb=xmlb
set Zsnd=Zsnd
EXIT /b


:End
call :%operation%Post
if not exist "%~dp0error.log" goto cleanup
:Errors
echo.
echo There was an error in the process. Check the error description.
if exist "%~dp0error.log" (
 echo.
 type "%~dp0error.log"
)
pause
:cleanup
if exist "%pathonly%hashes.json" if not" %pathonly%" == "%zsndp%\" del "%pathonly%hashes.json"
if exist "%~dp0RFoutput.log" del "%~dp0RFoutput.log"
EXIT