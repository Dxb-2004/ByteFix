# ==============================================================================
# ByteFix Optimizer (Edicion Lite) - Herramienta de optimizacion y mantenimiento
# Repositorio: https://github.com/Dxb-2004/ByteFix
# Uso directo: irm https://raw.githubusercontent.com/Dxb-2004/ByteFix/main/ByteFix-Lite.ps1 | iex
# ==============================================================================

# Forzar TLS 1.2/1.3 para descargas y peticiones seguras
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# ------------------------------------------------------------------------------
# 1. COMPROBACION Y AUTO-ELEVACION A ADMINISTRADOR
# ------------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ByteFix] Solicitando elevacion a Administrador..." -ForegroundColor Yellow
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
# 2. FUNCIONES DE REGISTRO Y UTILIDADES
# ------------------------------------------------------------------------------
function Show-Header {
    Clear-Host
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "               BYTEFIX OPTIMIZER - EDICION TECNICA                " -ForegroundColor White
    Write-Host "         Optimizacion de Rendimiento, Latencia y Mantenimiento     " -ForegroundColor DarkCyan
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
        Write-Host "    [!] Error al escribir DWord en $Path\$Name : $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "    [!] Error al escribir String en $Path\$Name : $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-RegBinary {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][byte[]]$Value
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type Binary -Force | Out-Null
    } catch {
        Write-Host "    [!] Error al escribir Binary en $Path\$Name : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ------------------------------------------------------------------------------
# 3. PUNTOS DE RESTAURACION (CON BYPASS DEL LIMITE DE 24 HORAS)
# ------------------------------------------------------------------------------
function Create-RestorePoint {
    Write-Host "`n[+] Creando punto de restauracion de seguridad..." -ForegroundColor Cyan
    try {
        Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "ByteFix_RestorePoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "    [OK] Punto de restauracion 'ByteFix_RestorePoint' creado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "    [!] No se pudo crear el punto de restauracion: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "        (Verifica si el servicio 'Volume Shadow Copy' (VSS) esta deshabilitado)." -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# 4. TELEMETRIA Y PRIVACIDAD PROFUNDA
# ------------------------------------------------------------------------------
function Disable-Telemetry {
    Write-Host "`n[+] Desactivando telemetria, diagnosticos y rastreo de Windows..." -ForegroundColor Cyan
    
    $services = @("DiagTrack", "dmwappushservice", "diagnosticshub.standardcollector.service")
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "    [OK] Servicio '$svc' detenido y deshabilitado." -ForegroundColor Green
        }
    }

    Set-RegDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0
    Set-RegDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1

    Set-RegDWord -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0

    Set-RegDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0

    Write-Host "    [OK] Telemetria, anuncios y diagnosticos en segundo plano desactivados." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 5. OPTIMIZACION DE JUEGOS Y LATENCIA GENERAL
# ------------------------------------------------------------------------------
function Optimize-GamingLatency {
    Write-Host "`n[+] Optimizando latencia general, Game DVR y prioridad de procesos..." -ForegroundColor Cyan
    
    Set-RegDWord -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
    Set-RegDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
    Set-RegDWord -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0

    Set-RegDWord -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1
    Set-RegDWord -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1

    Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value -1
    Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0

    $gameTasks = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-RegDWord -Path $gameTasks -Name "GPU Priority" -Value 8
    Set-RegDWord -Path $gameTasks -Name "Priority" -Value 6
    Set-RegString -Path $gameTasks -Name "Scheduling Category" -Value "High"
    Set-RegString -Path $gameTasks -Name "SFIO Priority" -Value "High"

    Set-RegString -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506"
    Set-RegDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0

    Write-Host "    [OK] Prioridad multimedia, Game DVR y red optimizados para juegos." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 6. REDUCCION EXTREMA DE INPUT LAG (MOUSE, TECLADO, USB, GPU, TIMERS)
# ------------------------------------------------------------------------------
function Optimize-InputLag {
    Write-Host "`n[+] Aplicando optimizaciones para reduccion maxima de Input Lag..." -ForegroundColor Magenta

    # A) MOUSE: Entrada 1:1 directa (Raw Input) sin aceleracion ni suavizado
    Write-Host "    [>] Configurando respuesta 1:1 en el Mouse (sin aceleracion)..." -ForegroundColor Gray
    $mousePath = "HKCU:\Control Panel\Mouse"
    Set-RegString -Path $mousePath -Name "MouseSpeed" -Value "0"
    Set-RegString -Path $mousePath -Name "MouseThreshold1" -Value "0"
    Set-RegString -Path $mousePath -Name "MouseThreshold2" -Value "0"
    Set-RegString -Path $mousePath -Name "MouseSensitivity" -Value "10"

    # Curvas lineales planas (elimina aceleracion residual en aplicaciones antiguas)
    $flatCurveX = [byte[]]@(
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
        0x00,0xa0,0x00,0x00, 0x00,0x00,0x00,0x00,
        0x00,0x40,0x01,0x00, 0x00,0x00,0x00,0x00,
        0x00,0x80,0x02,0x00, 0x00,0x00,0x00,0x00,
        0x00,0x00,0x05,0x00, 0x00,0x00,0x00,0x00
    )
    $flatCurveY = [byte[]]@(
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00
    )
    Set-RegBinary -Path $mousePath -Name "SmoothMouseXCurve" -Value $flatCurveX
    Set-RegBinary -Path $mousePath -Name "SmoothMouseYCurve" -Value $flatCurveY

    # B) TECLADO: Reduccion de latencia de repeticion y sondeo
    Write-Host "    [>] Optimizando tasa de repeticion del teclado..." -ForegroundColor Gray
    $keyboardPath = "HKCU:\Control Panel\Keyboard"
    Set-RegString -Path $keyboardPath -Name "KeyboardDelay" -Value "0"
    Set-RegString -Path $keyboardPath -Name "KeyboardSpeed" -Value "31"
    Set-RegString -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "122"

    # C) USB: Desactivar suspension selectiva (evita micro-retrasos de sondeo en perifericos)
    Write-Host "    [>] Desactivando ahorro de energia y suspension selectiva USB..." -ForegroundColor Gray
    try {
        $usbSubgroup = "2a737441-1930-4402-8d77-b2bebba308a3"
        $usbSetting  = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
        powercfg /SETACVALUEINDEX SCHEME_CURRENT $usbSubgroup $usbSetting 0 2>$null
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT $usbSubgroup $usbSetting 0 2>$null
        powercfg /SETACTIVE SCHEME_CURRENT 2>$null
    } catch {}

    # D) GPU / DWM / PANTALLA COMPLETA EXCLUSIVA
    Write-Host "    [>] Activando HAGS y optimizaciones de entrega de cuadros de GPU..." -ForegroundColor Gray
    Set-RegDWord -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
    
    $gameConfig = "HKCU:\System\GameConfigStore"
    Set-RegDWord -Path $gameConfig -Name "GameDVR_FSEBehaviorMode" -Value 2
    Set-RegDWord -Path $gameConfig -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1
    Set-RegDWord -Path $gameConfig -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1
    Set-RegDWord -Path $gameConfig -Name "GameDVR_EFSEFeatureFlags" -Value 0

    $gameTasks = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-RegString -Path $gameTasks -Name "Latency Sensitive" -Value "True"

    # E) KERNEL Y POWER THROTTLING
    Write-Host "    [>] Desactivando Power Throttling en el programador de Windows..." -ForegroundColor Gray
    Set-RegDWord -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1
    Set-RegString -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0"

    # F) ESTABILIDAD DEL TEMPORIZADOR DE WINDOWS (Dynamic Tick Disable)
    Write-Host "    [>] Estabilizando temporizador de alta precision (BCDedit)..." -ForegroundColor Gray
    try {
        cmd.exe /c "bcdedit /set disabledynamictick yes" 2>$null
    } catch {}

    Write-Host "`n    [OK] Input Lag reducido al minimo en Mouse, Teclado, USB, DWM y CPU/GPU." -ForegroundColor Green
    Write-Host "    [*] Nota: Para aplicar completamente el cambio de HAGS y USB, se recomienda reiniciar el equipo." -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# 7. LIMPIEZA PROFUNDA DE ARCHIVOS TEMPORALES Y CACHE
# ------------------------------------------------------------------------------
function Clean-SystemFiles {
    Write-Host "`n[+] Ejecutando limpieza de archivos temporales y caches acumuladas..." -ForegroundColor Cyan
    
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

    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    Clear-DnsClientCache
    Write-Host "    [OK] Limpieza completada. Cache DNS purgada." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 8. PLANES DE ENERGIA DE ALTO RENDIMIENTO
# ------------------------------------------------------------------------------
function Set-PowerPlan {
    Write-Host "`n[+] Configurando plan de energia..." -ForegroundColor Cyan
    try {
        $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $highGuid     = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

        $plans = powercfg -list
        if ($plans -match $ultimateGuid) {
            powercfg -setactive $ultimateGuid | Out-Null
            Write-Host "    [OK] Plan 'Maximo Rendimiento' (Ultimate Performance) activado." -ForegroundColor Green
        } else {
            $dup = powercfg -duplicatescheme $ultimateGuid 2>$null
            if ($LASTEXITCODE -eq 0) {
                powercfg -setactive $ultimateGuid | Out-Null
                Write-Host "    [OK] Plan 'Maximo Rendimiento' generado y activado." -ForegroundColor Green
            } else {
                powercfg -duplicatescheme $highGuid 2>$null | Out-Null
                powercfg -setactive $highGuid | Out-Null
                Write-Host "    [OK] Plan 'Alto Rendimiento' activado." -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "    [!] No se pudo modificar el plan de energia: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# 9. CONFIGURACION DE DNS RAPIDOS Y SEGUROS
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
                Write-Host "    [OK] Adaptador '$($adapter.Name)': DNS restablecido a Automatico (DHCP)." -ForegroundColor Green
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
# 10. DIAGNOSTICO BASICO DEL SISTEMA
# ------------------------------------------------------------------------------
function Show-SystemDiagnostics {
    Write-Host "`n[+] Obteniendo informacion de hardware del equipo..." -ForegroundColor Cyan
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
        Write-Host "    [!] No se pudo completar el diagnostico: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# 11. MENU INTERACTIVO
# ------------------------------------------------------------------------------
do {
    Show-Header
    Write-Host "  1. Aplicar TODAS las optimizaciones recomendadas (Incluye Input Lag)" -ForegroundColor Yellow
    Write-Host "  2. REDUCIR INPUT LAG AL MAXIMO (Mouse, Teclado, USB, DWM, HAGS, Timers)" -ForegroundColor Magenta
    Write-Host "  3. Crear Punto de Restauracion del Sistema"
    Write-Host "  4. Desactivar Telemetria, Diagnosticos y Bing Search"
    Write-Host "  5. Optimizar Latencia para Juegos, Red y Game DVR"
    Write-Host "  6. Limpieza Profunda de Archivos Temporales y DNS"
    Write-Host "  7. Activar Plan de Energia de Maximo / Alto Rendimiento"
    Write-Host "  8. Configurar DNS de Cloudflare (1.1.1.1 / 1.0.0.1)"
    Write-Host "  9. Configurar DNS de Google (8.8.8.8 / 8.8.4.4)"
    Write-Host "  D. Restablecer DNS a Automatico (DHCP)"
    Write-Host "  I. Ver Diagnostico y Especificaciones del Equipo"
    Write-Host "  0. Salir" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Selecciona una opcion [0-9, D, I]"

    switch ($choice.ToUpper()) {
        "1" {
            Create-RestorePoint
            Disable-Telemetry
            Optimize-GamingLatency
            Optimize-InputLag
            Clean-SystemFiles
            Set-PowerPlan
            Write-Host "`n[ByteFix] Todas las optimizaciones e Input Lag aplicados exitosamente!" -ForegroundColor Green
            Pause
        }
        "2" { Optimize-InputLag; Pause }
        "3" { Create-RestorePoint; Pause }
        "4" { Disable-Telemetry; Pause }
        "5" { Optimize-GamingLatency; Pause }
        "6" { Clean-SystemFiles; Pause }
        "7" { Set-PowerPlan; Pause }
        "8" { Set-FastDNS -Provider "Cloudflare"; Pause }
        "9" { Set-FastDNS -Provider "Google"; Pause }
        "D" { Set-FastDNS -Provider "DHCP"; Pause }
        "I" { Show-SystemDiagnostics; Pause }
        "0" { break }
        default { Write-Host "Opcion invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "0")

Write-Host "`nGracias por usar ByteFix Optimizer. Hasta pronto!" -ForegroundColor Cyan
