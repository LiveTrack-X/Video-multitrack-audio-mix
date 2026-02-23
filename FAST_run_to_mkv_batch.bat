@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

if /i "%~1"==":MIXSEG" goto MIXSEG

set "BASE=%~dp0"
set "IN_DIR=%BASE%in"
set "OUT_DIR=%BASE%out"
set "FFDIR=%BASE%ffmpeg"
set "FFMPEG=%FFDIR%\ffmpeg.exe"
set "FFPROBE=%FFDIR%\ffprobe.exe"
set "PAUSE_ON_END=1"

echo ======================================================
echo [DEBUG] START  %DATE% %TIME%
echo [DEBUG] BASE   = "%BASE%"
echo [DEBUG] IN_DIR = "%IN_DIR%"
echo [DEBUG] OUT_DIR= "%OUT_DIR%"
echo ======================================================
echo.

if not exist "%FFMPEG%"  (set "FAILMSG=Missing ffmpeg.exe" & goto END_FAIL)
if not exist "%FFPROBE%" (set "FAILMSG=Missing ffprobe.exe" & goto END_FAIL)
if not exist "%IN_DIR%"  (set "FAILMSG=Missing in folder" & goto END_FAIL)
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%" >nul 2>&1

"%FFMPEG%" -version >nul 2>&1 || (set "FAILMSG=ffmpeg cannot run" & goto END_FAIL)
"%FFPROBE%" -version >nul 2>&1 || (set "FAILMSG=ffprobe cannot run" & goto END_FAIL)

echo [DEBUG] in\ listing:
dir /b /a:-d "%IN_DIR%\*.*" 2>nul
echo.

REM ---- Tracks
echo Enter audio track numbers to MIX (1-based).
echo Example: 2345  or  23
echo Default: 2345
set /p "TRKSTR=Tracks> "
if "%TRKSTR%"=="" set "TRKSTR=2345"

REM show raw input with brackets (detect hidden spaces)
echo [DEBUG] TRKSTR_RAW=[%TRKSTR%]

REM digits-only check
for /f "delims=0123456789" %%A in ("%TRKSTR%") do (
  set "FAILMSG=Invalid input. Digits only."
  goto END_FAIL
)

REM ---- Build filter_complex with safe digit->index mapping (1..9)
set "INS="
set "N=0"
set "TMP=%TRKSTR%"

:PARSE_LOOP
if "!TMP!"=="" goto PARSE_DONE
set "CH=!TMP:~0,1!"
set "TMP=!TMP:~1!"

REM Map digit to IDX (0-based)
set "IDX="
if "!CH!"=="1" set "IDX=0"
if "!CH!"=="2" set "IDX=1"
if "!CH!"=="3" set "IDX=2"
if "!CH!"=="4" set "IDX=3"
if "!CH!"=="5" set "IDX=4"
if "!CH!"=="6" set "IDX=5"
if "!CH!"=="7" set "IDX=6"
if "!CH!"=="8" set "IDX=7"
if "!CH!"=="9" set "IDX=8"

if "!IDX!"=="" (
  set "FAILMSG=Track digits must be 1..9. Got: !CH!"
  goto END_FAIL
)

set "INS=!INS![0:a:!IDX!]"
set /a N+=1
goto PARSE_LOOP

:PARSE_DONE
if %N% LSS 1 (
  set "FAILMSG=No tracks parsed."
  goto END_FAIL
)

set "FILTER=%INS%amix=inputs=%N%:duration=longest:normalize=0[a]"
echo [DEBUG] Tracks=%TRKSTR%  N=%N%
echo [DEBUG] Filter=%FILTER%
echo.

REM ---- Settings
set "SEG_TIME=600"
for /f %%N in ('powershell -NoProfile -Command "[int]([Environment]::ProcessorCount*0.75)"') do set "MAX_JOBS=%%N"
if "%MAX_JOBS%"=="" set "MAX_JOBS=3"
if %MAX_JOBS% LSS 1 set "MAX_JOBS=1"
set "THREADS=0"

echo [DEBUG] MAX_JOBS=%MAX_JOBS%  SEG_TIME=%SEG_TIME%
echo.

REM ---- Count inputs
set "FILECOUNT=0"
for /f "delims=" %%F in ('dir /b /a:-d "%IN_DIR%\*.mp4" 2^>nul') do set /a FILECOUNT+=1
for /f "delims=" %%F in ('dir /b /a:-d "%IN_DIR%\*.mkv" 2^>nul') do set /a FILECOUNT+=1

echo [DEBUG] FILECOUNT=%FILECOUNT%
if %FILECOUNT% EQU 0 (
  echo [WARN] No mp4/mkv found.
  goto END_OK
)

for /f "delims=" %%F in ('dir /b /a:-d "%IN_DIR%\*.mp4" 2^>nul') do call :PROCESS_ONE "%IN_DIR%\%%F"
for /f "delims=" %%F in ('dir /b /a:-d "%IN_DIR%\*.mkv" 2^>nul') do call :PROCESS_ONE "%IN_DIR%\%%F"

echo.
echo [ALL DONE]
goto END_OK


:PROCESS_ONE
set "INPUT=%~1"
set "NAME=%~n1"
set "OUTPUT=%OUT_DIR%\%NAME%.mixed_%TRKSTR%.mkv"

echo ==============================================
echo [FILE] "%INPUT%"
echo [OUT ] "%OUTPUT%"

"%FFPROBE%" -v error -show_entries format=duration -of default=nw=1:nk=1 "%INPUT%" >nul 2>&1
echo [DEBUG] ffprobe errorlevel=%errorlevel%
if errorlevel 1 (
  echo [WARN] Not readable media -> skip
  echo.
  exit /b 0
)

set "WORK=%TEMP%\mixC_%RANDOM%%RANDOM%"
set "SEG=%WORK%\seg"
set "WAV=%WORK%\wav"
mkdir "%SEG%" >nul 2>&1
mkdir "%WAV%" >nul 2>&1

echo [STEP 1/4] Split...
"%FFMPEG%" -hide_banner -y -i "%INPUT%" -map 0 -c copy ^
-f segment -segment_time %SEG_TIME% -reset_timestamps 1 ^
"%SEG%\part_%%03d.mkv"
if errorlevel 1 goto FAIL_ONE

echo [STEP 2/4] PCM mix (parallel)...
for %%S in ("%SEG%\part_*.mkv") do (
  call :WAIT_SLOT
  start "" /b cmd /c call "%~f0" :MIXSEG "%%~fS" "%FILTER%" "%WAV%" "%FFMPEG%" %THREADS%
)
call :WAIT_FFMPEG_DRAIN

echo [STEP 3/4] Concat PCM...
set "LIST=%WORK%\wav.txt"
del "%LIST%" >nul 2>&1
for %%W in ("%WAV%\*.wav") do (
  >> "%LIST%" echo file '%%~fW'
)

"%FFMPEG%" -hide_banner -y -f concat -safe 0 -i "%LIST%" -c copy "%WORK%\audio.wav"
if errorlevel 1 goto FAIL_ONE

echo [STEP 4/4] Final MKV + FLAC...
"%FFMPEG%" -hide_banner -y -i "%INPUT%" -i "%WORK%\audio.wav" ^
-map 0:v:0 -map 1:a:0 ^
-c:v copy -c:a flac ^
"%OUTPUT%"
if errorlevel 1 goto FAIL_ONE

rmdir /s /q "%WORK%" >nul 2>&1
echo [OK]
echo.
exit /b 0

:WAIT_SLOT
:WS_LOOP
call :RUNNING CNT
if %CNT% GEQ %MAX_JOBS% (
  timeout /t 1 >nul
  goto WS_LOOP
)
exit /b 0

:WAIT_FFMPEG_DRAIN
:WD_LOOP
call :RUNNING CNT
if NOT "%CNT%"=="0" (
  timeout /t 1 >nul
  goto WD_LOOP
)
exit /b 0

:RUNNING
for /f %%C in ('tasklist /fi "imagename eq ffmpeg.exe" ^| find /c "ffmpeg.exe"') do set "%~1=%%C"
exit /b 0

:FAIL_ONE
echo [FAIL] "%INPUT%"
echo [DEBUG] Temp kept: "%WORK%"
echo.
exit /b 0

:MIXSEG
"%~5" -hide_banner -y -threads %6 ^
-i "%~2" ^
-filter_complex "%~3" ^
-map "[a]" -ac 2 -ar 48000 -c:a pcm_s24le ^
"%~4\%~n2.wav"
exit /b %errorlevel%

:END_OK
echo [DEBUG] END_OK
if "%PAUSE_ON_END%"=="1" pause
exit /b 0

:END_FAIL
echo [DEBUG] END_FAIL: %FAILMSG%
if "%PAUSE_ON_END%"=="1" pause
exit /b 1
