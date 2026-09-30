@echo off
setlocal enabledelayedexpansion

title STM32F103C6 Proteus Auto-Loader

echo ===================================================
echo   STM32F103C6 Proteus Auto-Build ^& Simulation
echo ===================================================
echo.

:: -----------------------------------------------------
:: 1. CONFIGURATION PATHS
:: -----------------------------------------------------
set "PROJECT_DIR=%~dp0"
set "BUILD_DIR=%PROJECT_DIR%build"
set "HEX_FILE=%BUILD_DIR%\Lab1.hex"
set "HEX_ROOT=%PROJECT_DIR%Lab1.hex"
set "ELF_FILE=%BUILD_DIR%\Lab1.elf"
set "PDS_PROJECT=%PROJECT_DIR%Lab1.pdsprj"

:: -----------------------------------------------------
:: 2. LOCATE PROTEUS 8 EXECUTABLE
:: -----------------------------------------------------
set "PROTEUS_EXE="

:: Kiểm tra trong Registry hệ thống trước
for /f "tokens=2* skip=2" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\PDS.EXE" /ve 2^>nul') do (
    if exist "%%b" set "PROTEUS_EXE=%%b"
)

:: Nếu Registry không có, thử tìm đường dẫn mặc định
if not defined PROTEUS_EXE (
    if exist "C:\Program Files (x86)\Labcenter Electronics\Proteus 8 Professional\BIN\PDS.EXE" (
        set "PROTEUS_EXE=C:\Program Files (x86)\Labcenter Electronics\Proteus 8 Professional\BIN\PDS.EXE"
    ) else if exist "C:\Program Files\Labcenter Electronics\Proteus 8 Professional\BIN\PDS.EXE" (
        set "PROTEUS_EXE=C:\Program Files\Labcenter Electronics\Proteus 8 Professional\BIN\PDS.EXE"
    )
)

:: -----------------------------------------------------
:: 3. BUILD FIRMWARE
:: -----------------------------------------------------
echo [1/3] Compiling STM32F103C6 firmware...
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

:: Configure CMake nếu chưa sinh file Makefile hoặc build.ninja
if not exist "%BUILD_DIR%\Makefile" if not exist "%BUILD_DIR%\build.ninja" (
    cmake -B "%BUILD_DIR%" -G "MinGW Makefiles" -DCMAKE_TOOLCHAIN_FILE="%PROJECT_DIR%cmake\gcc-arm-none-eabi.cmake"
    if errorlevel 1 goto BUILD_ERROR
)

cmake --build "%BUILD_DIR%"
if errorlevel 1 goto BUILD_ERROR

if not exist "%HEX_FILE%" goto BUILD_ERROR

:: Đồng bộ file HEX ra thư mục gốc
copy /y "%HEX_FILE%" "%HEX_ROOT%" >nul

:: Sao chép đường dẫn file HEX vào Clipboard
<nul set /p="%HEX_FILE%" | clip

echo.
echo [2/3] SUCCESS: Firmware compiled successfully!
echo       HEX file updated: "%HEX_FILE%"
echo.

:: -----------------------------------------------------
:: 4. RELOAD OR LAUNCH PROTEUS
:: -----------------------------------------------------
echo [3/3] Checking Proteus 8 status...

tasklist /FI "IMAGENAME eq PDS.exe" 2>NUL | find /I /N "PDS.exe">NUL
if "%ERRORLEVEL%"=="0" goto PROTEUS_RUNNING

:PROTEUS_NOT_RUNNING
if "%PROTEUS_EXE%"=="" (
    echo [ERROR] Proteus 8 is not running and PDS.EXE path was not found.
    goto END
)
if exist "%PDS_PROJECT%" (
    echo [INFO] Proteus is not running. Launching design file: "%PDS_PROJECT%"
    start "" "%PROTEUS_EXE%" "%PDS_PROJECT%"
) else (
    echo [INFO] Proteus is not running. Launching Proteus 8...
    start "" "%PROTEUS_EXE%"
)
goto SUCCESS_END

:PROTEUS_RUNNING
echo [INFO] Proteus 8 is ALREADY RUNNING!
echo [INFO] Triggering simulation reload...

:: Gửi phím tắt qua PowerShell:
:: 1. Active cửa sổ Proteus
:: 2. Gửi Shift+Space để DỪNG (Stop) mô phỏng (giúp Proteus xả HEX cũ)
:: 3. Chờ 300ms rồi gửi Space để CHẠY LẠI (Run) với file HEX mới
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$wshell = New-Object -ComObject WScript.Shell;" ^
    "if ($wshell.AppActivate('Proteus')) {" ^
        "Start-Sleep -Milliseconds 200;" ^
        "$wshell.SendKeys('+ ');" ^
        "Start-Sleep -Milliseconds 300;" ^
        "$wshell.SendKeys(' ');" ^
    "}"

:SUCCESS_END
echo.
echo ===================================================
echo   CODE BUILD AND AUTO-RELOAD SUCCESSFUL!
echo ===================================================
echo   HEX Path copied to clipboard: %HEX_FILE%
echo ===================================================
echo.
goto END

:BUILD_ERROR
echo.
echo ===================================================
echo   [BUILD ERROR] COMPILATION FAILED!
echo ===================================================
echo   Please check the error output above.
echo   Fix the code errors and run this script again.
echo ===================================================
echo.

:END
pause