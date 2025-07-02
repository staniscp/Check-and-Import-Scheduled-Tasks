# Script dengan logging komprehensif
$logPath = "C:\Temp\Logs\PrinterInstall.log"
$printerName = "Canon-Lifung on VMSGGGTIDNPSP1"
$printerPath = "\\VMSGGGTIDNPSP1\Canon-Lifung"

# Buat folder log jika belum ada
if (!(Test-Path -Path (Split-Path $logPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $logPath -Parent) -Force | Out-Null
}

# Fungsi untuk menulis log
function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$level] $message" | Out-File -FilePath $logPath -Append
    Write-Host "$timestamp [$level] $message"

    # Hapus log lama jika ada
    if (Test-Path $logPath) {
        Remove-Item $logPath -Force
    }
    
    # Tulis log baru
    $logEntry | Out-File -FilePath $logPath -Append
}

# Mulai logging
Write-Log "Script dimulai"
Write-Log "Mengecek printer $printerName"

function Check-PrinterInstalled {
    param ([string]$printerName)
    try {
        $printer = Get-Printer -Name $printerName -ErrorAction SilentlyContinue
        if ($printer) {
            Write-Log "Printer $printerName sudah terinstall" -level "SUCCESS"
            return $true
        } else {
            Write-Log "Printer $printerName belum terinstall" -level "WARNING"
            return $false
        }
    }
    catch {
        Write-Log "Error saat mengecek printer: $_" -level "ERROR"
        return $false
    }
}

function Install-Printer {
    param ([string]$printerPath, [string]$printerName)
    try {
        Write-Log "Memulai proses install printer" -level "INFO"
        
        # Map printer share
        Write-Log "Menjalankan: net use $printerPath /persistent:yes"
        $netUseOutput = net use $printerPath /persistent:yes 2>&1
        Write-Log "Output net use: $netUseOutput"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Gagal mapping printer share (Exit Code: $LASTEXITCODE)"
        }
        
        # Add printer connection
        Write-Log "Menjalankan: rundll32 printui.dll,PrintUIEntry /ga /in /n $printerPath"
        $addPrinterOutput = cmd /c "rundll32 printui.dll,PrintUIEntry /ga /in /n `"$printerPath`"" 2>&1
        Write-Log "Output PrintUIEntry: $addPrinterOutput"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Gagal menambahkan printer (Exit Code: $LASTEXITCODE)"
        }
        
        # Set as default
        Write-Log "Menjalankan: rundll32 printui.dll,PrintUIEntry /ga /y /n $printerPath"
        $setDefaultOutput = cmd /c "rundll32 printui.dll,PrintUIEntry /ga /y /n `"$printerPath`"" 2>&1
        Write-Log "Output set default: $setDefaultOutput"
        
        Write-Log "Printer berhasil diinstall" -level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error saat install printer: $_" -level "ERROR"
        return $false
    }
}

# Eksekusi utama
if (Check-PrinterInstalled -printerName $printerName) {
    Write-Log "Printer sudah ada, tidak perlu install ulang" -level "INFO"
} else {
    $installResult = Install-Printer -printerPath $printerPath -printerName $printerName
    if ($installResult) {
        Write-Log "Verifikasi: Printer berhasil diinstall" -level "SUCCESS"
    } else {
        Write-Log "Verifikasi: Printer gagal diinstall" -level "ERROR"
    }
}

Write-Log "Script selesai"

# Tambahkan di bagian akhir script
if ($installResult) {
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Printer $printerName berhasil diinstall", 10, "Success", 0x0)
} else {
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Gagal menginstall printer $printerName. Lihat log di $logPath", 10, "Error", 0x10)
}

# Hapus log setelah 1 menit (memberi waktu untuk membaca log jika diperlukan)
Start-Sleep -Seconds 600
if (Test-Path $logPath) {
    Remove-Item $logPath -Force
}