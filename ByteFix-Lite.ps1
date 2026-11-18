<#
.SYNOPSIS
    ByteFix Optimizer - Herramienta de optimización y mantenimiento de Windows.
.DESCRIPTION
    Script ligero para optimizar el rendimiento de Windows, reducir latencia en juegos,
    desactivar telemetría innecesaria y realizar limpieza del sistema.
    Puede ejecutarse remotamente: irm <url>/ByteFix-Lite.ps1 | iex
.NOTES
    Nombre: ByteFix-Lite.ps1
    Versión: 1.0.0
#>

# Requerir privilegios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ByteFix] Elevando privilegios a Administrador..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "ByteFix Optimizer - [Administrador]"

function Show-Header {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                    BYTEFIX OPTIMIZER                      " -ForegroundColor White
    Write-Host "         Optimización de Rendimiento y Limpieza             " -ForegroundColor DarkCyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Create-RestorePoint {
    Write-Host "[+] Creando punto de restauración de seguridad..." -ForegroundColor Cyan
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "ByteFix_RestorePoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "    [OK] Punto de restauración 'ByteFix_RestorePoint' creado con éxito." -ForegroundColor Green
    } catch {
        Write-Host "    [!] No se pudo crear el punto de restauración: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Disable-Telemetry {
    Write-Host "[+] Desactivando telemetría y diagnósticos de Windows..." -ForegroundColor Cyan
    
    # Servicios de telemetría
    $services = @("DiagTrack", "dmwappushservice", "diagnosticshub.standardcollector.service")
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "    [OK] Servicio '$svc' detenido y deshabilitado." -ForegroundColor Green
        }
    }

    # Políticas de privacidad en el Registro
    $regPaths = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Value = 1; Type = "DWord" }
    )

    foreach ($reg in $regPaths) {
        if (-not (Test-Path $reg.Path)) {
            New-Item -Path $reg.Path -Force | Out-Null
        }
        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type $reg.Type -Force
    }
    Write-Host "    [OK] Registro de telemetría optimizado." -ForegroundColor Green
}

function Optimize-Gaming {
    Write-Host "[+] Optimizando ajustes para juegos y latencia..." -ForegroundColor Cyan
    
    # Deshabilitar GameDVR (Game Bar en segundo plano)
    $gameDvrPaths = @(
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR"; Value = 0 }
    )
    foreach ($item in $gameDvrPaths) {
        if (-not (Test-Path $item.Path)) { New-Item -Path $item.Path -Force | Out-Null }
        Set-ItemProperty -Path $item.Path -Name $item.Name -Value $item.Value -Type DWord -Force
    }

    # Activar Game Mode
    $gameModePath = "HKCU:\Software\Microsoft\GameBar"
    if (-not (Test-Path $gameModePath)) { New-Item -Path $gameModePath -Force | Out-Null }
    Set-ItemProperty -Path $gameModePath -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force

    # Prioridad multimedia y latencia de red
    $netThrottling = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    if (Test-Path $netThrottling) {
        Set-ItemProperty -Path $netThrottling -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
        Set-ItemProperty -Path $netThrottling -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
    }

    Write-Host "    [OK] Game DVR deshabilitado y prioridades multimedia ajustadas." -ForegroundColor Green
}

function Clean-TempFiles {
    Write-Host "[+] Limpiando archivos temporales y caché..." -ForegroundColor Cyan
    
    $tempFolders = @(
        "$env:TEMP\*",
        "C:\Windows\Temp\*",
        "C:\Windows\Prefetch\*",
        "C:\Windows\SoftwareDistribution\Download\*"
    )

    foreach ($folder in $tempFolders) {
        try {
            Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    # Vaciar papelera de reciclaje
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    } catch {}

    # Flush DNS
    Clear-DnsClientCache
    Write-Host "    [OK] Caché, DNS y archivos temporales purgados." -ForegroundColor Green
}

function Set-HighPerformancePower {
    Write-Host "[+] Configurando plan de energía de alto rendimiento..." -ForegroundColor Cyan
    try {
        # Duplicar plan de alto rendimiento si no existe o activarlo
        $scheme = powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Write-Host "    [OK] Plan de energía 'Alto Rendimiento' activado." -ForegroundColor Green
    } catch {
        Write-Host "    [!] No se pudo cambiar el plan de energía." -ForegroundColor Yellow
    }
}

# Bucle del Menú
do {
    Show-Header
    Write-Host "  1. Aplicar TODAS las optimizaciones recomendadas" -ForegroundColor Yellow
    Write-Host "  2. Crear Punto de Restauración del Sistema"
    Write-Host "  3. Desactivar Telemetría y Diagnósticos"
    Write-Host "  4. Optimizar Latencia para Juegos (GameDVR, Multimedia)"
    Write-Host "  5. Limpiar Archivos Temporales, Caché y DNS"
    Write-Host "  6. Activar Plan de Energía 'Alto Rendimiento'"
    Write-Host "  0. Salir" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Selecciona una opción [0-6]"

    switch ($choice) {
        "1" {
            Create-RestorePoint
            Disable-Telemetry
            Optimize-Gaming
            Clean-TempFiles
            Set-HighPerformancePower
            Write-Host "`n[ByteFix] ¡Optimizaciones aplicadas exitosamente!" -ForegroundColor Green
            Pause
        }
        "2" { Create-RestorePoint; Pause }
        "3" { Disable-Telemetry; Pause }
        "4" { Optimize-Gaming; Pause }
        "5" { Clean-TempFiles; Pause }
        "6" { Set-HighPerformancePower; Pause }
        "0" { break }
        default { Write-Host "Opción inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "0")

Write-Host "`nGracias por usar ByteFix Optimizer. ¡Hasta pronto!" -ForegroundColor Cyan
