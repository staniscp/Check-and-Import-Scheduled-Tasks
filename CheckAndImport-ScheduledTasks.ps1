<#
.SYNOPSIS
    Script untuk mengecek dan mengimpor task scheduler dari file XML dengan logging ekstensif
.DESCRIPTION
    Script ini akan memeriksa apakah task dengan nama tertentu sudah ada di scheduler.
    Jika belum ada, script akan mengimpor task dari file XML yang sesuai.
    Semua aktivitas akan dicatat dalam file log.
.PARAMETER TaskNames
    Daftar nama task yang akan diperiksa dan diimpor (opsional)
.PARAMETER LogPath
    Lokasi file log (default: $PSScriptRoot\TaskSchedulerImport.log)
.EXAMPLE
    .\CheckAndImport-ScheduledTasks.ps1
    Menjalankan script secara interaktif dengan logging default
.EXAMPLE
    .\CheckAndImport-ScheduledTasks.ps1 -TaskNames "Install IDN Printer Automatically", "Gpupdate" -LogPath "C:\Logs\TaskImport.log"
    Memeriksa dan mengimpor task tertentu dengan lokasi log khusus
.NOTES
    Versi: 2.0
    Author: Your Name
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>

param (
    [Parameter(Mandatory=$false)]
    [string[]]$TaskNames = @("Install IDN Printer Automatically", "Gpupdate", "TimeSync"),
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Temp\Logs\TaskSchedulerImport.log"
)

# Mapping nama task ke file XML
$taskMappings = @{
    "Install IDN Printer Automatically" = "C:\Temp\Don't Delete\New Install\Install IDN Printer Automatically.xml"
    "Gpupdate" = "C:\Temp\Don't Delete\New Install\Gpupdate.xml"
    "TimeSync" = "C:\Temp\Don't Delete\New Install\TimeSync.xml"
}

# Fungsi untuk menulis log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $LogPath
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
        
        # Tampilkan juga di console dengan warna berbeda
        switch ($Level) {
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
            "INFO"  { Write-Host $logEntry -ForegroundColor White }
            "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
            default { Write-Host $logEntry }
        }
    } catch {
        Write-Host "Gagal menulis log: $_" -ForegroundColor Red
    }
}

# Fungsi untuk memeriksa apakah task sudah ada
function Test-TaskExists {
    param (
        [string]$taskName
    )
    
    try {
        Write-Log -Message "Memeriksa keberadaan task: $taskName" -Level "DEBUG"
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        $exists = ($null -ne $task)
        
        if ($exists) {
            Write-Log -Message "Task '$taskName' sudah terdaftar. Status: $($task.State)" -Level "INFO"
        } else {
            Write-Log -Message "Task '$taskName' tidak ditemukan" -Level "INFO"
        }
        
        return $exists
    } catch {
        Write-Log -Message "Error saat memeriksa task '$taskName': $_" -Level "ERROR"
        return $false
    }
}

# Fungsi untuk mengimpor task dari XML
function Import-TaskFromXml {
    param (
        [string]$taskName,
        [string]$xmlFilePath,
        [string]$userAccount = "SYSTEM",
        [string]$password = $null
    )
    
    try {
        Write-Log -Message "Memulai proses impor task '$taskName' dari file '$xmlFilePath'" -Level "INFO"
        
        if (-not (Test-Path -Path $xmlFilePath -PathType Leaf)) {
            Write-Log -Message "File XML tidak ditemukan: $xmlFilePath" -Level "ERROR"
            return $false
        }

        Write-Log -Message "Membaca konten file XML: $xmlFilePath" -Level "DEBUG"
        $xmlContent = Get-Content -Path $xmlFilePath -Raw
        
        $registerParams = @{
            Xml = $xmlContent
            TaskName = $taskName
            Force = $true
        }
        
        if ($userAccount -ne "SYSTEM") {
            $registerParams.User = $userAccount
            if ($password) {
                $registerParams.Password = $password
                Write-Log -Message "Menggunakan akun pengguna: $userAccount" -Level "DEBUG"
            }
        } else {
            Write-Log -Message "Menggunakan akun SYSTEM" -Level "DEBUG"
        }
        
        Write-Log -Message "Mendaftarkan task ke scheduler" -Level "DEBUG"
        Register-ScheduledTask @registerParams | Out-Null
        
        Write-Log -Message "Task '$taskName' berhasil diimpor!" -Level "INFO"
        return $true
    } catch {
        Write-Log -Message "Gagal mengimpor task '$taskName': $_" -Level "ERROR"
        return $false
    }
}

# Main script
try {
    # Inisialisasi log
    Write-Log -Message "================================================" -Level "INFO"
    Write-Log -Message "Memulai proses Task Scheduler Import" -Level "INFO"
    Write-Log -Message "Script versi 2.0 dengan logging ekstensif" -Level "INFO"
    Write-Log -Message "Log file: $LogPath" -Level "INFO"
    Write-Log -Message "Waktu mulai: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
    Write-Log -Message "================================================" -Level "INFO"

    # Memeriksa apakah script dijalankan sebagai admin
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Script harus dijalankan sebagai Administrator"
    }
    Write-Log -Message "Verifikasi hak akses administrator berhasil" -Level "INFO"

    Write-Log -Message "Daftar task yang akan diproses: $($TaskNames -join ', ')" -Level "INFO"

    foreach ($taskName in $TaskNames) {
        Write-Log -Message "------------------------------------------------" -Level "INFO"
        Write-Log -Message "Memproses task: $taskName" -Level "INFO"
        
        if (Test-TaskExists -taskName $taskName) {
            Write-Log -Message "Task '$taskName' sudah ada, dilewati." -Level "INFO"
            continue
        }

        # Dapatkan path file XML dari mapping
        $xmlFilePath = $taskMappings[$taskName]
        if (-not $xmlFilePath) {
            Write-Log -Message "Tidak ada file XML yang terdaftar untuk task '$taskName'" -Level "WARN"
            continue
        }

        # Jika task tidak ada, coba impor
        $importResult = Import-TaskFromXml -taskName $taskName -xmlFilePath $xmlFilePath
        
        if ($importResult) {
            # Verifikasi task setelah diimpor
            $importedTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($importedTask) {
                Write-Log -Message "Verifikasi task berhasil. Status: $($importedTask.State)" -Level "INFO"
                
                # Log detail task
                $taskDetails = @"
Task Name: $($importedTask.TaskName)
Task Path: $($importedTask.TaskPath)
State: $($importedTask.State)
Triggers: $($importedTask.Triggers | ForEach-Object { $_.ToString() })
Actions: $($importedTask.Actions | ForEach-Object { $_.ToString() })
"@
                Write-Log -Message "Detail task:`n$taskDetails" -Level "DEBUG"
            } else {
                Write-Log -Message "Task berhasil diimpor tetapi tidak dapat diverifikasi" -Level "WARN"
            }
        }
    }

    Write-Log -Message "================================================" -Level "INFO"
    Write-Log -Message "Proses selesai. Waktu selesai: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
    Write-Log -Message "================================================" -Level "INFO"
} catch {
    Write-Log -Message "ERROR GLOBAL: $_" -Level "ERROR"
    Write-Log -Message "Stack Trace: $($_.ScriptStackTrace)" -Level "DEBUG"
    exit 1
}