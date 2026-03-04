<#
Enable-LabMgmtFirewallRules.ps1
- Enumerates AD computer accounts
- Uses WinRM (5985 + Test-WSMan) to determine "reachable"
- Enables firewall rule groups needed for SCVMM/remote management
#>

param(
    # Adjust to your OU/container
    [string]$SearchBase = "dc=corp,dc=contoso,dc=com",

    # Optional: filter only certain names, e.g. "Compute*" or "S2D*"
    [string]$NameLike = "*",

    # Output CSV path
    [string]$CsvPath = ("C:\Temp\EnableFirewallRules_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss")),

    # WinRM port (SCVMM typically uses 5985 unless HTTPS configured)
    [int]$WinRMPort = 5985
)

Import-Module ActiveDirectory

# Rule groups you requested
$RuleGroups = @(
    "Windows Remote Management",
    "Windows Management Instrumentation (WMI)",
    "File and Printer Sharing",
    "Remote Service Management"
)

# Make sure output folder exists
$csvDir = Split-Path $CsvPath -Parent
New-Item -Path $csvDir -ItemType Directory -Force | Out-Null

# Get targets from AD (pattern based)
$Computers = Get-ADComputer -Filter * -SearchBase $SearchBase |
    Where-Object { $_.Name -like $NameLike } |
    Select-Object -ExpandProperty Name

Write-Host "Found $($Computers.Count) computer(s) in AD under: $SearchBase matching: $NameLike"
Write-Host "Output: $CsvPath"

# Helper: check TCP port quickly
function Test-TcpPort {
    param([string]$ComputerName, [int]$Port)
    try {
        return (Test-NetConnection -ComputerName $ComputerName -Port $Port -InformationLevel Quiet)
    } catch {
        return $false
    }
}

# Helper: check WinRM properly
function Test-WinRM {
    param([string]$ComputerName)
    try {
        Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Remote payload (executed on targets)
$RemoteScript = {
    param([string[]]$Groups)

    # Ensure Firewall service is not disabled (SCVMM/WinRM tooling relies on it)
    Set-Service -Name MpsSvc -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name MpsSvc -ErrorAction SilentlyContinue

    # Enable the requested firewall rule groups
    foreach ($g in $Groups) {
        Enable-NetFirewallRule -DisplayGroup $g -ErrorAction Stop | Out-Null
    }

    # OPTIONAL (usually not needed if "File and Printer Sharing" group is enabled)
    # If you want to guarantee SMB 445 explicitly, uncomment below.
    # Creating rules via PowerShell uses New-NetFirewallRule. 
    # New-NetFirewallRule -DisplayName "LAB - Allow SMB 445 In" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow -Profile Domain -ErrorAction SilentlyContinue | Out-Null

    # Return a small summary
    $summary = foreach ($g in $Groups) {
        [pscustomobject]@{
            Group        = $g
            EnabledRules = (Get-NetFirewallRule -DisplayGroup $g -ErrorAction SilentlyContinue |
                           Where-Object { $_.Enabled -eq "True" }).Count
        }
    }

    return $summary
}

# Collect results
$Results = foreach ($c in $Computers) {

    $tcpOk   = Test-TcpPort -ComputerName $c -Port $WinRMPort
    $wsmanOk = $false
    $status  = ""
    $FailureReason   = ""

    if (-not $tcpOk) {
        $status = "SKIPPED"
        $FailureReason  = "WinRM port $WinRMPort not reachable"
        [pscustomobject]@{ Computer=$c; Tcp5985=$tcpOk; WinRM=$wsmanOk; Result=$status; Error=$FailureReason }
        continue
    }

    $wsmanOk = Test-WinRM -ComputerName $c
    if (-not $wsmanOk) {
        $status = "SKIPPED"
        $FailureReason  = "Test-WSMan failed (WinRM not ready/auth/firewall)"
        [pscustomobject]@{ Computer=$c; Tcp5985=$tcpOk; WinRM=$wsmanOk; Result=$status; Error=$FailureReason }
        continue
    }

    try {
        Invoke-Command -ComputerName $c -ScriptBlock $RemoteScript -ArgumentList (, $RuleGroups) -ErrorAction Stop | Out-Null
        $status = "OK"
        [pscustomobject]@{ Computer=$c; Tcp5985=$tcpOk; WinRM=$wsmanOk; Result=$status; Error="" }
    }
    catch {
        $status = "FAILED"
        $FailureReason  = $_.Exception.Message
        [pscustomobject]@{ Computer=$c; Tcp5985=$tcpOk; WinRM=$wsmanOk; Result=$status; Error=$FailureReason }
    }
}

# Export CSV
$Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

Write-Host "`nDone. Summary:"
$Results | Group-Object Result | Select-Object Name,Count | Format-Table -AutoSize
Write-Host "`nCSV: $CsvPath"
