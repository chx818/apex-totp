@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

if exist "%SCRIPT_DIR%..\build_tools\jdk_extracted\jdk-11.0.32.1+1\bin\javac.exe" (
    set "JAVA_HOME=%SCRIPT_DIR%..\build_tools\jdk_extracted\jdk-11.0.32.1+1"
    set "PATH=%SCRIPT_DIR%..\build_tools\jdk_extracted\jdk-11.0.32.1+1\bin;%PATH%"
)

if exist "%SCRIPT_DIR%..\SmartPGP-J3R452-Curve25519\sdks\jc304_kit" (
    if "%JC_HOME%"=="" set "JC_HOME=%SCRIPT_DIR%..\SmartPGP-J3R452-Curve25519\sdks\jc304_kit"
)

if exist "%SCRIPT_DIR%..\build_tools\ant_extracted\apache-ant-1.10.18\bin\ant.bat" (
    set "ANT_CMD=%SCRIPT_DIR%..\build_tools\ant_extracted\apache-ant-1.10.18\bin\ant.bat"
) else (
    set "ANT_CMD=ant"
)

echo ============================================================
echo  Building VivoKey Apex-TOTP (RAM-Optimized for JCOP 4/5)
echo ============================================================
call "%ANT_CMD%" -f "%SCRIPT_DIR%build.xml" dist

if %errorlevel% equ 0 (
    echo.
    echo ============================================================
    echo  BUILD SUCCESS!
    echo  CAP file: %SCRIPT_DIR%target\vivokey-otp.cap
    echo ============================================================
) else (
    echo.
    echo ============================================================
    echo  BUILD FAILED! Please check error output above.
    echo ============================================================
)

endlocal
