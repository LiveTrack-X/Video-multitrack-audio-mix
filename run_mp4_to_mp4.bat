@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM =====================================================
REM Sub-mode entry (spawned workers)
REM =====================================================
if /i "%~1"==":MIXSEG" goto MIXSEG

REM =====================================================
REM Main
REM =====================================================
set "BASE=%~dp0"
set "IN_DIR=%BASE%in"
set "OUT_DIR=%BASE%out"
set "FFDIR=%BASE%ffmpeg"
set "FFMPEG=%FFDIR%\ffmpeg.exe"
set "FFPROBE=%FFDIR%\ffprobe.exe"

set "PAUSE_ON_END=1"

echo [INFO] BASE   = "%BASE%"
echo [INFO] IN_DIR = "%IN_DIR%"
echo [INFO] OUT_DIR= "%OUT_DIR%"
echo [INFO] FFMPEG = "%FFMPEG%"
echo [INFO] FFPROBE= "%FFPROBE%"
echo.

if not exist "%FFMPEG%"  (echo [ERROR] Missing "%FFMPEG%"  & goto END_FAIL)
if not exist "%FFPROBE%" (echo [ERROR] Missing "%FFPROBE%" & goto END_FAIL)
if not exist "%IN_DIR%"  (echo [ERROR] Missing folder "%IN_DIR%" & goto END_FAIL)
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%" >nul 2>&1

"%FFMPEG%" -version  >nul 2>&1 || (echo [ERROR] ffmpeg cannot run  & goto END_FAIL)
"%FFPROBE%" -version >nul 2>&1 || (echo [ERROR] ffprobe cannot run & goto END_FAIL)

REM ===== Ask tracks =====
echo Enter audio track numbers to MIX (1-based).
echo Example: 2345 or 23456 or 23
echo Default: 2345
set /p "TRKSTR=Tracks> "
if "%TRKSTR%"=="" set "TRKSTR=2345"

for /f "delims=0123456789" %%A in ("%TRKSTR%") do (
  echo [ERROR] Invalid input. Digits only.
  goto END_FAIL
)

REM ===== Build filter_complex =====
set "INS="
set "N=0"
set "TMP=%TRKSTR%"
:PARSE
if "%TMP%"=="" goto DONE_PARSE
set "C=%TMP:~0,1%"
set "TMP=%TMP:~1%"
set /a D=C
if %D% LSS 1 (echo [ERROR] Track must be >=1 & goto END_FAIL)
set /a IDX=D-1
set "INS=%INS%[0:a:%IDX%]"
set /a N+=1
goto PARSE
:DONE_PARSE

if %N% LSS 1 (echo [ERROR] No tracks & goto END_FAIL)

set "FILTER=%INS%amix=inputs=%N%:duration=longest:normalize=0[a]"

echo.
echo [INFO] Tracks = %TRKSTR%
echo [INFO] Filter = %FILTER%
echo.

REM ===== Settings =====
set "SEG_TIME=600"
for /f %%N in ('powershell -NoProfile -Command "[int]([Environment]::ProcessorCount*0.75)"') do set "MAX_JOBS=%%N"
if "%MAX_JOBS%"=="" set "MAX_JOBS=3"
if %MAX_JOBS% LSS 1 set "MAX_JOBS=1"

set "THREADS=0"

echo [INFO] SEG_TIME=%SEG_TIME% sec
echo [INFO] MAX_JOBS=%MAX_JOBS%
echo.

REM ===== Count inputs =====
set "FILECOUNT=0"
for %%F in ("%IN_DIR%\*.mp4") do set /a FILECOUNT+=1
if %FILECOUNT% EQU 0 (
  echo [WARN] No .mp4 files in "%IN_DIR%"
  goto END_OK
)
echo [INFO] Found %FILECOUNT% file(s).
echo.

REM ===== Process each input =====
for %%F in ("%IN_DIR%\*.mp4") do (
  call :PROCESS_ONE "%%~fF" "%FILTER%" "%TRKSTR%"
)

echo.
echo [ALL DONE]
goto END_OK


:PROCESS_ONE
set "INPUT=%~1"
set "FILTER=%~2"
set "TRKSTR=%~3"

set "NAME=%~n1"
set "OUTPUT=%OUT_DIR%\%NAME%.mixed_%TRKSTR%.mp4"

echo ==============================================
echo [FILE] "%INPUT%"
echo [OUT ] "%OUTPUT%"

set "WORK=%TEMP%\mixC_%RANDOM%%RANDOM%"
set "SEG=%WORK%\seg"
set "WAV=%WORK%\wav"
mkdir "%SEG%" >nul 2>&1
mkdir "%WAV%" >nul 2>&1

echo [STEP 1/4] Split...
"%FFMPEG%" -hide_banner -y -i "%INPUT%" -map 0 -c copy ^
-f segment -segment_time %SEG_TIME% -reset_timestamps 1 ^
"%SEG%\part_%%03d.mp4"
if errorlevel 1 goto FAIL_ONE

echo [STEP 2/4] PCM mix (parallel)...
for %%S in ("%SEG%\part_*.mp4") do (
  call :WAIT_SLOT
  start "" /b cmd /c call "%~f0" :MIXSEG "%%~fS" "%FILTER%" "%WAV%" "%FFMPEG%" %THREADS%
)

call :WAIT_FFMPEG_DRAIN

echo [STEP 3/4] Concat WAV...
set "LIST=%WORK%\wav.txt"
del "%LIST%" >nul 2>&1

for %%W in ("%WAV%\*.wav") do (
  >> "%LIST%" echo file '%%~fW'
)

if not exist "%LIST%" goto FAIL_ONE
"%FFMPEG%" -hide_banner -y -f concat -safe 0 -i "%LIST%" -c copy "%WORK%\audio.wav"
if errorlevel 1 goto FAIL_ONE

echo [STEP 4/4] Final MP4 (AAC 320k once)...
"%FFMPEG%" -hide_banner -y -i "%INPUT%" -i "%WORK%\audio.wav" ^
-map 0:v:0 -map 1:a:0 ^
-c:v copy -c:a aac -b:a 320k ^
-movflags +faststart ^
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
echo [INFO] Temp kept: "%WORK%"
echo.
exit /b 0


REM =====================================================
REM Worker: mix one segment -> WAV
REM args: %2=inseg %3=filter %4=wavdir %5=ffmpeg %6=threads
REM =====================================================
:MIXSEG
set "INSEG=%~2"
set "FC=%~3"
set "WAVDIR=%~4"
set "FF=%~5"
set "TH=%~6"

"%FF%" -hide_banner -y -threads %TH% ^
-i "%INSEG%" ^
-filter_complex "%FC%" ^
-map "[a]" -ac 2 -ar 48000 -c:a pcm_s24le ^
"%WAVDIR%\%~n2.wav"

exit /b %errorlevel%


:END_OK
if "%PAUSE_ON_END%"=="1" pause
exit /b 0

:END_FAIL
if "%PAUSE_ON_END%"=="1" pause
exit /b 1
