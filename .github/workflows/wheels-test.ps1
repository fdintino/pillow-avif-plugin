param ([string]$venv, [string]$pillow_avif_plugin="C:\pillow-avif-plugin")
$ErrorActionPreference  = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-PSDebug -Trace 1
if ("$venv" -like "*\cibw-run-*\pp*-win_amd64\*") {
    # unlike CPython, PyPy requires Visual C++ Redistributable to be installed
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri 'https://aka.ms/vs/15/release/vc_redist.x64.exe' -OutFile 'vc_redist.x64.exe'
    C:\vc_redist.x64.exe /install /quiet /norestart | Out-Null
}
$env:path += ";$pillow_avif_plugin\winbuild\build\bin\"
& "$venv\Scripts\activate.ps1"
& reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\python.exe" /v "GlobalFlag" /t REG_SZ /d "0x02000000" /f
cd $pillow_avif_plugin
& python -VV
if (!$?) { exit $LASTEXITCODE }
& python -m pytest -vx tests
if (!$?) { exit $LASTEXITCODE }
