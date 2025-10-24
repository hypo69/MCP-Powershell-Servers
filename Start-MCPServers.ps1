## \file Start-MCPServers.ps1
# -*- coding: utf-8 -*-
#! .pyenv/bin/pwsh

<#
.SYNOPSIS
    Start-MCPServers для MCP PowerShell серверов
    
.DESCRIPTION
    Start-MCPServers автоматически запускает все MCP серверы в фоновых процессах.
    
.PARAMETER StopServers
    Остановить все запущенные MCP серверы
    
.PARAMETER ConfigPath
    Путь к директории с конфигурациями (по умолчанию: src/config)
    
.EXAMPLE
    .\Start-MCPServers.ps1
    
.EXAMPLE
    .\Start-MCPServers.ps1 -StopServers

.NOTES
    Version: 1.1.1
    Author: hypo69
    License: MIT (https://opensource.org/licenses/MIT)
    Copyright: @hypo69 - 2025
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$StopServers,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = 'src\config',
    
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

#region Global Variables

$script:LauncherVersion = '1.1.1'
$script:ServerProcesses = @{}
$script:LogFile = Join-Path $env:TEMP 'mcp-launcher.log'
$script:PidFile = Join-Path $env:TEMP 'mcp-servers.pid'

#endregion

#region Utility Functions

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $script:LogFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
    
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        'INFO'    { 'Cyan' }
        'DEBUG'   { 'Gray' }
        default   { 'White' }
    }
    
    $prefix = switch ($Level) {
        'SUCCESS' { '[✓]' }
        'WARNING' { '[!]' }
        'ERROR'   { '[✗]' }
        'INFO'    { '[i]' }
        'DEBUG'   { '[d]' }
        default   { '[-]' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Save-ServerPIDs {
    try {
        $processData = @{}
        foreach ($serverName in $script:ServerProcesses.Keys) {
            $process = $script:ServerProcesses[$serverName]
            if ($process -and -not $process.HasExited) {
                $processData[$serverName] = $process.Id
            }
        }
        
        if ($processData.Count -gt 0) {
            $processData | ConvertTo-Json | Set-Content -Path $script:PidFile -Encoding UTF8 -ErrorAction Stop
            Write-Log "Информация о процессах сохранена в файл: $script:PidFile" -Level 'DEBUG'
        } else {
            Write-Log "Нет активных процессов для сохранения" -Level 'DEBUG'
        }
    }
    catch {
        Write-Log "Ошибка сохранения информации о процессах: $($_.Exception.Message)" -Level 'WARNING'
    }
}

function Load-ServerPIDs {
    try {
        if (Test-Path $script:PidFile) {
            $processData = Get-Content -Path $script:PidFile -Raw -ErrorAction Stop | ConvertFrom-Json
            
            foreach ($property in $processData.PSObject.Properties) {
                $serverName = $property.Name
                $processId = $property.Value
                
                try {
                    $process = Get-Process -Id $processId -ErrorAction Stop
                    $script:ServerProcesses[$serverName] = $process
                    Write-Log "Загружен процесс для $serverName : PID $processId" -Level 'DEBUG'
                }
                catch {
                    Write-Log "Процесс $serverName (PID: $processId) не найден" -Level 'DEBUG'
                }
            }
        }
    }
    catch {
        Write-Log "Ошибка загрузки информации о процессах: $($_.Exception.Message)" -Level 'DEBUG'
    }
}

function Remove-PidFile {
    try {
        if (Test-Path $script:PidFile) {
            Remove-Item $script:PidFile -Force -ErrorAction Stop
            Write-Log "Файл PID удален" -Level 'DEBUG'
        }
    }
    catch {
        Write-Log "Ошибка удаления файла PID: $($_.Exception.Message)" -Level 'WARNING'
    }
}

function Show-Help {
    $helpText = @"

MCP PowerShell Server Launcher v$script:LauncherVersion

ОПИСАНИЕ:
    Автоматический запуск всех MCP PowerShell серверов.

ИСПОЛЬЗОВАНИЕ:
    .\Start-MCPServers.ps1 [параметры]

ПАРАМЕТРЫ:
    -StopServers            Остановить все запущенные MCP серверы
    -ConfigPath <путь>      Путь к директории с конфигурациями
    -Help                   Показать эту справку

ПРИМЕРЫ:
    .\Start-MCPServers.ps1
    .\Start-MCPServers.ps1 -StopServers

ЗАПУСКАЕМЫЕ СЕРВЕРЫ:
    - powershell-stdio
    - powershell-https
    - wordpress-cli
    - wordpress-mcp
    - huggingface-mcp

АВТОР:
    hypo69

ЛИЦЕНЗИЯ:
    MIT (https://opensource.org/licenses/MIT)

"@
    Write-Host $helpText -ForegroundColor Cyan
}

function Find-ServerScript {
    param([string]$ServerName)
    $possiblePaths = @(
        "src\servers\$ServerName.ps1",
        "servers\$ServerName.ps1",
        "$ServerName.ps1",
        $ServerName
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return (Resolve-Path $path).Path
        }
    }
    Write-Log "Файл $ServerName не найден" -Level 'DEBUG'
    return $null
}

function Test-ServerRunning {
    param([string]$ServerName)
    if ($script:ServerProcesses.ContainsKey($ServerName)) {
        $p = $script:ServerProcesses[$ServerName]
        if ($p -and -not $p.HasExited) { return $true }
    }
    return $false
}

function Start-MCPServer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [Parameter(Mandatory = $false)]
        [hashtable]$Environment = @{}
    )
    Write-Log "Запуск сервера: $ServerName" -Level 'INFO'
    if (-not (Test-Path $ScriptPath)) {
        Write-Log "ОШИБКА: файл не найден: $ScriptPath" -Level 'ERROR'
        return $false
    }
    if (Test-ServerRunning -ServerName $ServerName) {
        Write-Log "Сервер $ServerName уже запущен" -Level 'WARNING'
        return $true
    }
    try {
        $si = [System.Diagnostics.ProcessStartInfo]::new()
        $si.FileName = 'pwsh'
        $si.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`""
        $si.UseShellExecute = $false
        $si.RedirectStandardOutput = $true
        $si.RedirectStandardError  = $true
        $si.CreateNoWindow = $true
        foreach ($k in $Environment.Keys) { $si.EnvironmentVariables[$k] = $Environment[$k] }
        $p = [System.Diagnostics.Process]::new()
        $p.StartInfo = $si
        if (-not $p.Start()) { Write-Log "Не удалось запустить процесс $ServerName" -Level 'ERROR'; return $false }
        Start-Sleep -Milliseconds 800
        if ($p.HasExited) {
            $err = $p.StandardError.ReadToEnd()
            Write-Log "Ошибка запуска ${ServerName}: $err" -Level 'ERROR'
            return $false
        }
        $script:ServerProcesses[$ServerName] = $p
        Write-Log "Сервер $ServerName запущен (PID: $($p.Id))" -Level 'SUCCESS'
        Save-ServerPIDs
        return $true
    } catch {
        Write-Log "Ошибка запуска сервера ${ServerName}: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

function Stop-MCPServers {
    param([switch]$Force)
    Write-Log 'Остановка всех MCP серверов...' -Level 'INFO'
    Load-ServerPIDs
    $stopped = 0
    foreach ($s in $script:ServerProcesses.Keys) {
        $p = $script:ServerProcesses[$s]
        if ($p -and -not $p.HasExited) {
            try {
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
                Write-Log "$s остановлен" -Level 'SUCCESS'
                $stopped++
            } catch {
                Write-Log "Ошибка остановки ${s}: $($_.Exception.Message)" -Level 'ERROR'
            }
        }
    }
    Remove-PidFile
    Write-Log "Остановлено серверов: $stopped" -Level 'INFO'
}

function Show-ServerStatus {
    Write-Host ''
    Write-Host '=== СТАТУС MCP СЕРВЕРОВ ===' -ForegroundColor Cyan
    $running = 0
    foreach ($s in $script:ServerProcesses.Keys) {
        $p = $script:ServerProcesses[$s]
        if ($p -and -not $p.HasExited) {
            Write-Host "  ✓ $s (PID: $($p.Id))" -ForegroundColor Green
            $running++
        } else {
            Write-Host "  ✗ $s (остановлен)" -ForegroundColor Red
        }
    }
    Write-Host "Запущено серверов: $running / $($script:ServerProcesses.Count)" -ForegroundColor Yellow
}

#endregion

#region Main Logic

function Start-AllServers {
    Write-Host ''
    Write-Host "=== MCP PowerShell Server Launcher v$script:LauncherVersion ===" -ForegroundColor Cyan
    $servers = @{
        'powershell-stdio'  = @{ Script='McpStdioServer';       Description='STDIO сервер PowerShell' }
        'powershell-https'  = @{ Script='McpHttpsServer';       Description='HTTPS сервер REST API' }
        'wordpress-cli'     = @{ Script='McpWpCliServer';       Description='WordPress CLI сервер' }
        'wordpress-mcp'     = @{ Script='McpWpServer';          Description='WordPress MCP сервер (REST + HuggingFace)' }
        'huggingface-mcp'   = @{ Script='McpHuggingFaceServer'; Description='Hugging Face MCP сервер' }
    }
    $found=@{}
    foreach ($s in $servers.Keys) {
        $path = Find-ServerScript $servers[$s].Script
        if ($path) { $found[$s]=$path }
    }
    if ($found.Count -eq 0) { Write-Log "Не найдено ни одного серверного скрипта" -Level 'ERROR'; return $false }
    foreach ($s in $found.Keys) {
        Write-Log "Запуск $s ($($servers[$s].Description))" -Level 'INFO'
        $env=@{POWERSHELL_EXECUTION_POLICY='RemoteSigned';HF_TOKEN=$env:HF_TOKEN;WP_PATH='C:\xampp\htdocs\wordpress'}
        Start-MCPServer -ServerName $s -ScriptPath $found[$s] -Environment $env | Out-Null
        Start-Sleep -Milliseconds 300
    }
    Show-ServerStatus
    return $true
}

#endregion

#region Entry Point

try {
    if ($Help) { Show-Help; exit 0 }
    if ($StopServers) { Stop-MCPServers; exit 0 }

    Load-ServerPIDs
    if ($script:ServerProcesses.Count -gt 0) {
        Write-Log "Сервера уже запущены" -Level 'WARNING'
        Show-ServerStatus
        exit 1
    }

    if (-not (Start-AllServers)) { exit 1 }

    Write-Host "=== СЕРВЕРЫ УСПЕШНО ЗАПУЩЕНЫ ===" -ForegroundColor Green
    Write-Host "Для остановки: .\Start-MCPServers.ps1 -StopServers" -ForegroundColor Yellow

    $null = Register-EngineEvent -SourceIdentifier Console.CancelKeyPress -Action {
        Write-Host "`nСохранение PID..." -ForegroundColor Yellow
        Save-ServerPIDs
        Write-Host "Информация сохранена. Серверы продолжают работу." -ForegroundColor Green
        [Environment]::Exit(0)
    }

    while ($true) {
        Start-Sleep -Seconds 5
        $alive = ($script:ServerProcesses.Values | Where-Object { $_ -and -not $_.HasExited }).Count
        if ($alive -eq 0) { Write-Log "Все серверы завершены" -Level 'WARNING'; break }
    }
}
catch {
    Write-Log "Критическая ошибка: $($_.Exception.Message)" -Level 'ERROR'
    Stop-MCPServers
}
finally {
    Write-Log 'Launcher завершен' -Level 'INFO'
}
#endregion
