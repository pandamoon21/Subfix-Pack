@echo off
:: This script is for subtitles from different sources (timing & font).
:: For "extract=y" you need the following base as a MKV: "ID0:Video" + "ID1:Audio" + "ID2:Sub"
REM ######################
setlocal ENABLEDELAYEDEXPANSION
echo.
echo Keep all files and this batch file in the same folder. 
echo Only set the names of them, no directory structure (paths)!
echo Just press enter for detault values.
echo Always use lowercase.
echo.
REM ######################
:: Explanation: https://iamscum.wordpress.com/guides/prass/
REM ######################
set fast=n
set extract=n
set source=ass
set timefix=y
set timefixmode=3
set shifting=0
set secpass=y
set mux=y
set template=template_advanced.ass
set font=font1.ttf
set font2=font1i.ttf
REM ######################

if "%extract%" EQU "y" (
 if "%source%" EQU "ass" (
 mkvextract --ui-language en tracks "%~1" 2:"%~n1.ass"
 set videoname=%~n1.mkv
 set scriptname=%~n1.ass
 goto TTT
 )
 if "%source%" EQU "srt" (
 mkvextract --ui-language en tracks "%~1" 2:"%~n1.srt"
 set videoname=%~n1.mkv
 set scriptname=%~n1.srt
 goto TTT
 )
)

set /p videoname=Video (e.g. Test.mkv): 
set /p scriptname=Subtitle (e.g. Test.ass / Test.srt): 

:TTT

if "%fast%" EQU "y" (
goto GGF
)

echo Default is template_advanced.ass
set /p template=Template (e.g. template.ass): 
echo Default is font.ttf
set /p font=Normal font (e.g. font.ttf): 
echo Default is font2.ttf
set /p font2=Italic font (e.g. font2.ttf): 
echo Default is ass
set /p source=srt or ass input (e.g. ass): 
echo Default is n
set /p secpass=Use a second mux pass (y/n): 
echo Default is 0
set /p shifting=Time difference for subtitles (1,2,24 for frame/s forward, 0 for nothing or -1,-2,-24 for frame/s backward): 
echo Default is y
set /p timefix=Run timefix (y/n): 
 if "%timefix%" EQU "y" (
 echo Default is 3
 set /p timefixmode=Strenght of the timefix (0-6): 
)
echo Default is y
set /p mux=Mux everything together at the end (y/n): 

:GGF
echo.
echo Start fixing...

if "%secpass%" EQU "y" (
 if NOT exist "%videoname%_fixed.mkv" (
 mkvmerge -o "%videoname%_fixed.mkv" "--no-subtitles" "--default-duration" "0:24000/1001p" "--fix-bitstream-timing-information" "0:1" "%videoname%"
 )
)

if "%secpass%" EQU "n" (
 if NOT exist "%videoname%_fixed.mkv" (
 copy "%videoname%" "%videoname%_fixed.mkv"
 )
)
 
if "%source%" EQU "srt" (
 echo Converting srt to ass...
 py -3 audio\prass\prass.py convert-srt "%scriptname%" --encoding utf-8 | py -3 audio\prass\prass.py copy-styles --resolution 1920x1080 --from audio\%template% -o "%scriptname%_srt.ass"
 py -3 audio\amazon-netflix_typeset_split.py "%scriptname%_srt.ass" "%scriptname%_tmp.ass"
 del "%scriptname%_srt.ass"
 echo Converting completed.
)

if "%source%" EQU "ass" (
py -3 audio\prass\prass.py copy-styles --resample --from audio\%template% --to "%scriptname%" -o "%scriptname%_tmp.ass"
)

if "%shifting%" EQU "1" (
 ren "%scriptname%_tmp.ass" "%scriptname%_tmp2.ass"
 py -3 audio\prass\prass.py shift --by 42ms "%scriptname%_tmp2.ass" -o "%scriptname%_tmp.ass"
 del "%scriptname%_tmp2.ass"
)

if "%shifting%" EQU "-1" (
 ren "%scriptname%_tmp.ass" "%scriptname%_tmp2.ass"
 py -3 audio\prass\prass.py shift --by -42ms "%scriptname%_tmp2.ass" -o "%scriptname%_tmp.ass"
 del "%scriptname%_tmp2.ass"
)

if "%shifting%" EQU "2" (
 ren "%scriptname%_tmp.ass" "%scriptname%_tmp2.ass"
 py -3 audio\prass\prass.py shift --by 84ms "%scriptname%_tmp2.ass" -o "%scriptname%_tmp.ass"
 del "%scriptname%_tmp2.ass"
)

if "%shifting%" EQU "-2" (
 ren "%scriptname%_tmp.ass" "%scriptname%_tmp2.ass"
 py -3 audio\prass\prass.py shift --by -84ms "%scriptname%_tmp2.ass" -o "%scriptname%_tmp.ass"
 del "%scriptname%_tmp2.ass"
)

if "%shifting%" EQU "24" (
 ren "%scriptname%_tmp.ass" "%scriptname%_tmp2.ass"
 py -3 audio\prass\prass.py shift --by 1001ms "%scriptname%_tmp2.ass" -o "%scriptname%_tmp.ass"
 del "%scriptname%_tmp2.ass"
)

if "%shifting%" EQU "-24" (
 ren "%scriptname%_tmp.ass" "%scriptname%_tmp2.ass"
 py -3 audio\prass\prass.py shift --by -1001ms "%scriptname%_tmp2.ass" -o "%scriptname%_tmp.ass"
 del "%scriptname%_tmp2.ass"
)

awk "/\[Script Info\]/ { print; print \"ScaledBorderAndShadow: yes\"; next }1" "%scriptname%_tmp.ass" >"%scriptname%_tmp2.ass"
del "%scriptname%_tmp.ass"
ren "%scriptname%_tmp2.ass" "%scriptname%_tmp.ass"

if "%timefix%" EQU "n" (
 ren "%scriptname%_tmp.ass" "%scriptname%_fixed.ass"
 goto NSU
)
if "%timefixmode%" EQU "0" (
 ren "%scriptname%_tmp.ass" "%scriptname%_fixed.ass"
 goto NSU
)

if "%timefix%" EQU "y" (
 if NOT exist "%videoname%_fixed.mkv_keyframes.txt" (
  echo Generate keyframes...
  ffmpeg -i "%videoname%_fixed.mkv" -f yuv4mpegpipe -vf scale=640:360 -pix_fmt yuv420p -vsync drop - | SCXvid "%videoname%_fixed.mkv_keyframes.txt"
  echo Keyframes completed.
  )
 if "%timefixmode%" EQU "1" (
  py -3 audio\prass\prass.py tpp "%scriptname%_tmp.ass" --keyframes "%videoname%_fixed.mkv_keyframes.txt" --fps 23.976 --kf-before-start 84 --kf-before-end 84 --kf-after-start 84 --kf-after-end 84    -o "%scriptname%_fixed.ass"
  del "%scriptname%_tmp.ass"
 )
 if "%timefixmode%" EQU "2" (
  py -3 audio\prass\prass.py tpp "%scriptname%_tmp.ass" --lead-in 42 --lead-out 42 --gap 210 --overlap 126 --bias 50 --keyframes "%videoname%_fixed.mkv_keyframes.txt" --fps 23.976 --kf-before-start 210 --kf-before-end 210 --kf-after-start 252 --kf-after-end 252    -o "%scriptname%_fixed.ass"
  del "%scriptname%_tmp.ass"
 )
 if "%timefixmode%" EQU "3" (
  py -3 audio\prass\prass.py tpp "%scriptname%_tmp.ass" --lead-in 84 --lead-out 84 --gap 462 --overlap 252 --bias 80 --keyframes "%videoname%_fixed.mkv_keyframes.txt" --fps 23.976 --kf-before-start 210 --kf-before-end 294 --kf-after-start 294 --kf-after-end 294    -o "%scriptname%_fixed.ass"
  del "%scriptname%_tmp.ass"
 )
 if "%timefixmode%" EQU "4" (
  py -3 audio\prass\prass.py tpp "%scriptname%_tmp.ass" --lead-in 84 --lead-out 84 --gap 210 --overlap 126 --bias 100 --keyframes "%videoname%_fixed.mkv_keyframes.txt" --fps 23.976 --kf-before-start 210 --kf-before-end 294 --kf-after-start 294 --kf-after-end 294    -o "%scriptname%_fixed.ass"
  del "%scriptname%_tmp.ass"
 )
 if "%timefixmode%" EQU "5" (
  py -3 audio\prass\prass.py tpp "%scriptname%_tmp.ass" --lead-in 42 --lead-out 42 --gap 378 --overlap 252 --bias 60 --keyframes "%videoname%_fixed.mkv_keyframes.txt" --fps 23.976 --kf-before-start 252 --kf-before-end 336 --kf-after-start 294 --kf-after-end 294    -o "%scriptname%_fixed.ass"
  del "%scriptname%_tmp.ass"
 )
 if "%timefixmode%" EQU "6" (
  py -3 audio\prass\prass.py tpp "%scriptname%_tmp.ass" --lead-in 42 --lead-out 0 --gap 252 --overlap 210 --bias 70 --keyframes "%videoname%_fixed.mkv_keyframes.txt" --fps 23.976 --kf-before-start 210 --kf-before-end 336 --kf-after-start 294 --kf-after-end 294    -o "%scriptname%_fixed.ass"
  del "%scriptname%_tmp.ass"
 )
)

:NSU

if "%typo%" EQU "y" (
 ren "%scriptname%_fixed.ass" "%scriptname%-needfix.ass"
 py -3 audio\fuehre_mich.py "%scriptname%-needfix.ass" "%scriptname%_fixed.ass"
 del "%scriptname%-needfix.ass"
)

if "%mux%" EQU "y" (
 mkvmerge -o "%videoname%_final.mkv" "%videoname%_fixed.mkv" "--sub-charset" "0:UTF-8" "--language" "0:zxx" "--track-name" "0:" "--default-track" "0:yes" "%scriptname%_fixed.ass" "--attachment-mime-type" "application/vnd.ms-opentype" "--attachment-name" "%font%" "--attach-file" "audio\%font%" "--attachment-mime-type" "application/vnd.ms-opentype" "--attachment-name" "%font2%" "--attach-file" "audio\%font2%"
 del "%videoname%_fixed.mkv"
)

echo Done.
PAUSE
