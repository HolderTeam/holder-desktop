@echo off
setlocal EnableExtensions

set "MODE=%~1"
if "%MODE%"=="" set "MODE=test"

if /I "%MODE%"=="help" goto usage
if /I "%MODE%"=="--help" goto usage
if /I "%MODE%"=="-h" goto usage

if not defined MSYS2_BASH set "MSYS2_BASH=C:\msys64\usr\bin\bash.exe"

if not exist "%MSYS2_BASH%" (
  echo MSYS2 bash was not found at "%MSYS2_BASH%".
  echo Install MSYS2, or set MSYS2_BASH to the full path of bash.exe.
  echo Example: set MSYS2_BASH=C:\msys64\usr\bin\bash.exe
  exit /b 1
)

set "HOLDER_DESKTOP_MODE=%MODE%"
set "HOLDER_DESKTOP_ROOT=%CD%"
set "MSYSTEM=UCRT64"
set "CHERE_INVOKING=1"

"%MSYS2_BASH%" -lc "set -euo pipefail; export PATH=/ucrt64/bin:/usr/bin:$PATH; cd \"$(cygpath -u \"$HOLDER_DESKTOP_ROOT\")\"; mode=\"${HOLDER_DESKTOP_MODE:-test}\"; build_dir=\"${BUILD_DIR:-build-win}\"; setup_build() { if [ -f \"$build_dir/build.ninja\" ]; then meson setup \"$build_dir\" --reconfigure; else meson setup \"$build_dir\"; fi; }; build_app() { setup_build; rm -f \"$build_dir/data/gschemas.compiled\"; meson compile -C \"$build_dir\"; }; case \"$mode\" in deps) pacman -S --needed --noconfirm base-devel mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-pkgconf mingw-w64-ucrt-x86_64-vala mingw-w64-ucrt-x86_64-gtk4 mingw-w64-ucrt-x86_64-libadwaita mingw-w64-ucrt-x86_64-gtksourceview5 mingw-w64-ucrt-x86_64-libspelling mingw-w64-ucrt-x86_64-libgee mingw-w64-ucrt-x86_64-libsoup3 mingw-w64-ucrt-x86_64-json-glib mingw-w64-ucrt-x86_64-vte4 ;; build) build_app ;; test) build_app; GSETTINGS_BACKEND=memory meson test -C \"$build_dir\" --print-errorlogs ;; run) build_app; GSETTINGS_SCHEMA_DIR=\"$PWD/$build_dir/data\" \"./$build_dir/holder-desktop.exe\" ;; *) echo \"Usage: make.bat [deps|build|test|run]\"; exit 2 ;; esac"

exit /b %ERRORLEVEL%

:usage
echo Usage: make.bat [deps^|build^|test^|run]
echo.
echo   deps   Install MSYS2 UCRT64 build dependencies with pacman
echo   build  Configure and compile holder-desktop
echo   test   Build and run Meson tests
echo   run    Build and launch holder-desktop
exit /b 0
