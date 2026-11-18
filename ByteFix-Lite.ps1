<#
.SYNOPSIS
    ByteFix Optimizer (Edición Lite) - Herramienta de optimización, telemetría y mantenimiento.
.DESCRIPTION
    Script profesional de PowerShell diseñado para técnicos y usuarios avanzados.
    Optimiza el rendimiento del sistema, reduce latencia en juegos, elimina telemetría,
    purga cachés temporales y configura planes de energía avanzados.
.NOTES
    Repositorio: https://github.com/Dxb-2004/ByteFix
    Ejecución directa: irm https://raw.githubusercontent.com/Dxb-2004/ByteFix/main/ByteFix-Lite.ps1 | iex
#>

# Forzar TLS 1.2/1.3 para descargas y peticiones seguras
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# ------------------------------------------------------------------------------
# 1. COMPROBACIÓN Y AUTO-ELEVACIÓN A ADMINISTRADOR
# ------------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ByteFix] Solicitando elevación a Administrador..." -ForegroundColor Yellow
    if ($PSCommandPath -and (Test-Path -Path $PSCommandPath)) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        $launchCmd = "irm https://raw.githubusercontent.com/Dxb-2004/ByteFix/main/ByteFix-Lite.ps1 | iex"
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$launchCmd`"" -Verb RunAs
    }
    exit
}

$Host.UI.RawUI.WindowTitle = "ByteFix Optimizer - [Administrador]"

# ------------------------------------------------------------------------------
# 2. FUNCIONES DE INTERFAZ Y UTILIDADES
# ------------------------------------------------------------------------------
function Show-Header {
    Clear-Host
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "               BYTEFIX OPTIMIZER - EDICIÓN TÉCNICA                " -ForegroundColor White
    Write-Host "         Optimización de Rendimiento, Latencia y Mantenimiento     " -ForegroundColor DarkCyan
    Write-Host "            https://github.com/Dxb-2004/ByteFix                   " -ForegroundColor DarkGray
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Set-RegDWord {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][int]$Value
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force | Out-Null
    } catch {
        Write-Host "    [!] Error al escribir en $Path\$Name : $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-RegString {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Value
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type String -Force | Out-Null
    } catch {
        Write-Host "    [!] Error al escribir en $Path\$Name : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ------------------------------------------------------------------------------
# 3. PUNTOS DE RESTAURACIÓN (CON BYPASS DEL LÍMITE DE 24 HORAS)
# ------------------------------------------------------------------------------
function Create-RestorePoint {
    Write-Host "`n[+] Creando punto de restauración de seguridad..." -ForegroundColor Cyan
    try {
        # Eliminar el límite de frecuencia de 1440 minutos impuesto por Windows
        Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0
        
        # Habilitar protección en la unidad del sistema
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        
        Checkpoint-Computer -Description "ByteFix_RestorePoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "    [OK] Punto de restauración 'ByteFix_RestorePoint' creado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "    [!] No se pudo crear el punto de restauración: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "        (Verifica si el servicio 'Volume Shadow Copy' (VSS) está deshabilitado)." -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# 4. TELEMETRÍA Y PRIVACIDAD PROFUNDA
# ------------------------------------------------------------------------------
function Disable-Telemetry {
    Write-Host "`n[+] Desactivando telemetría, diagnósticos y rastreo de Windows..." -ForegroundColor Cyan
    
    # Servicios de telemetría y diagnósticos
    $services = @("DiagTrack", "dmwappushservice", "diagnosticshub.standardcollector.service")
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "    [OK] Servicio '$svc' detenido y deshabilitado." -ForegroundColor Green
        }
    }

    # Desactivar telemetría en el registro
    Set-RegDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0
    Set-RegDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1

    # Desactivar Bing y Cortana en la búsqueda de Windows
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0

    # Desactivar historial de actividades y recopilación de retroalimentación
    Set-RegDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0

    Write-Host "    [OK] Telemetría, anuncios y diagnósticos en segundo plano desactivados." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 5. OPTIMIZACIÓN DE LATENCIA, RESPUESTA Y JUEGOS
# ------------------------------------------------------------------------------
function Optimize-GamingLatency {
    Write-Host "`n[+] Optimizando latencia del sistema, Game DVR y prioridad de procesos..." -ForegroundColor Cyan
    
    # Deshabilitar GameDVR y grabación en segundo plano de Xbox
    Set-RegDWord -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
    Set-RegDWord -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2
    Set-RegDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0

    # Activar Game Mode oficial de Windows
    Set-RegDWord -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1
    Set-RegDWord -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1

    # Desactivar estrangulamiento de red en juegos y elevar respuesta del sistema
    Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value -1 # 0xFFFFFFFF
    Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0

    # Prioridad de GPU y audio para juegos
    $gameTasks = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-RegDWord -Path $gameTasks -Name "GPU Priority" -Value 8
    Set-RegDWord -Path $gameTasks -Name "Priority" -Value 6
    Set-RegString -Path $gameTasks -Name "Scheduling Category" -Value "High"
    Set-RegString -Path $gameTasks -Name "SFIO Priority" -Value "High"

    # Desactivar la ventana emergente molesta de Sticky Keys (Shift presionado 5 veces)
    Set-RegString -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506"
    Set-RegString -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "122"

    # Desactivar P2P Delivery Optimization (evita que Windows Update use tu subida para otros PCs)
    Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0

    Write-Host "    [OK] Prioridad multimedia, GameDVR y parámetros de latencia configurados." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 6. LIMPIEZA PROFUNDA DE ARCHIVOS TEMPORALES Y CACHÉ
# ------------------------------------------------------------------------------
function Clean-SystemFiles {
    Write-Host "`n[+] Ejecutando limpieza de archivos temporales y cachés acumuladas..." -ForegroundColor Cyan
    
    $cleanPaths = @(
        "$env:TEMP\*",
        "C:\Windows\Temp\*",
        "C:\Windows\Prefetch\*",
        "C:\Windows\SoftwareDistribution\Download\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
    )

    $deletedCount = 0
    foreach ($path in $cleanPaths) {
        try {
            $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
            if ($items) {
                $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $deletedCount += $items.Count
            }
        } catch {}
    }

    # Vaciar papelera de reciclaje
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    # Purgar caché de resolución DNS
    Clear-DnsClientCache
    Write-Host "    [OK] Limpieza completada. Caché DNS purgada." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 7. PLANES DE ENERGÍA DE ALTO RENDIMIENTO
# ------------------------------------------------------------------------------
function Set-PowerPlan {
    Write-Host "`n[+] Configurando plan de energía..." -ForegroundColor Cyan
    try {
        # Desbloquear plan "Máximo Rendimiento" (Ultimate Performance)
        $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $highGuid     = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

        $plans = powercfg -list
        if ($plans -match $ultimateGuid) {
            powercfg -setactive $ultimateGuid | Out-Null
            Write-Host "    [OK] Plan 'Máximo Rendimiento' (Ultimate Performance) activado." -ForegroundColor Green
        } else {
            # Intentar duplicar esquema Ultimate Performance
            $dup = powercfg -duplicatescheme $ultimateGuid 2>$null
            if ($LASTEXITCODE -eq 0) {
                powercfg -setactive $ultimateGuid | Out-Null
                Write-Host "    [OK] Plan 'Máximo Rendimiento' generado y activado." -ForegroundColor Green
            } else {
                # Alternativa: Alto Rendimiento estándar
                powercfg -duplicatescheme $highGuid 2>$null | Out-Null
                powercfg -setactive $highGuid | Out-Null
                Write-Host "    [OK] Plan 'Alto Rendimiento' activado." -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "    [!] No se pudo modificar el plan de energía: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# 8. CONFIGURACIÓN DE DNS RÁPIDOS Y SEGUROS
# ------------------------------------------------------------------------------
function Set-FastDNS {
    param([string]$Provider)
    
    Write-Host "`n[+] Configurando servidores DNS ($Provider)..." -ForegroundColor Cyan
    $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
    
    if (-not $adapters) {
        Write-Host "    [!] No se encontraron adaptadores de red activos." -ForegroundColor Yellow
        return
    }

    $dnsServers = switch ($Provider) {
        "Cloudflare" { @("1.1.1.1", "1.0.0.1") }
        "Google"     { @("8.8.8.8", "8.8.4.4") }
        "DHCP"       { $null }
    }

    foreach ($adapter in $adapters) {
        try {
            if ($Provider -eq "DHCP") {
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses
                Write-Host "    [OK] Adaptador '$($adapter.Name)': DNS restablecido a Automático (DHCP)." -ForegroundColor Green
            } else {
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $dnsServers
                Write-Host "    [OK] Adaptador '$($adapter.Name)': Asignado $Provider ($($dnsServers -join ', '))." -ForegroundColor Green
            }
        } catch {
            Write-Host "    [!] Error en adaptador '$($adapter.Name)': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Clear-DnsClientCache
}

# ------------------------------------------------------------------------------
# 9. DIAGNÓSTICO BÁSICO DEL SISTEMA
# ------------------------------------------------------------------------------
function Show-SystemDiagnostics {
    Write-Host "`n[+] Obteniendo información de hardware del equipo..." -ForegroundColor Cyan
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
        $ramGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $freeRamGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)

        Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Sistema Operativo : $($os.Caption) (Build $($os.BuildNumber))"
        Write-Host "  Procesador (CPU)  : $($cpu.Name.Trim())"
        Write-Host "  Tarjeta de Video  : $($gpu.Name)"
        Write-Host "  Memoria RAM       : $ramGB GB Total ($freeRamGB GB Disponibles)"
        Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray
    } catch {
        Write-Host "    [!] No se pudo completar el diagnóstico: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# 10. MENÚ INTERACTIVO
# ------------------------------------------------------------------------------
do {
    Show-Header
    Write-Host "  1. Aplicar TODAS las optimizaciones recomendadas" -ForegroundColor Yellow
    Write-Host "  2. Crear Punto de Restauración del Sistema"
    Write-Host "  3. Desactivar Telemetría, Diagnósticos y Bing Search"
    Write-Host "  4. Optimizar Latencia para Juegos, Red y Game DVR"
    Write-Host "  5. Limpieza Profunda de Archivos Temporales y DNS"
    Write-Host "  6. Activar Plan de Energía de Máximo / Alto Rendimiento"
    Write-Host "  7. Configurar DNS de Cloudflare (1.1.1.1 / 1.0.0.1)"
    Write-Host "  8. Configurar DNS de Google (8.8.8.8 / 8.8.4.4)"
    Write-Host "  9. Restablecer DNS a Automático (DHCP)"
    Write-Host "  I. Ver Diagnóstico y Especificaciones del Equipo"
    Write-Host "  0. Salir" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Selecciona una opción [0-9, I]"

    switch ($choice.ToUpper()) {
        "1" {
            Create-RestorePoint
            Disable-Telemetry
            Optimize-GamingLatency
            Clean-SystemFiles
            Set-PowerPlan
            Write-Host "`n[ByteFix] ¡Optimizaciones aplicadas exitosamente!" -ForegroundColor Green
            Pause
        }
        "2" { Create-RestorePoint; Pause }
        "3" { Disable-Telemetry; Pause }
        "4" { Optimize-GamingLatency; Pause }
        "5" { Clean-SystemFiles; Pause }
        "6" { Set-PowerPlan; Pause }
        "7" { Set-FastDNS -Provider "Cloudflare"; Pause }
        "8" { Set-FastDNS -Provider "Google"; Pause }
        "9" { Set-FastDNS -Provider "DHCP"; Pause }
        "I" { Show-SystemDiagnostics; Pause }
        "0" { break }
        default { Write-Host "Opción inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "0")

Write-Host "`nGracias por usar ByteFix Optimizer. ¡Hasta pronto!" -ForegroundColor Cyan
