# 0) Prereqs / one-time checks (Domain Controller)
##################################################

    Get-KdsRootKey
    
    # AttributeOfWrongFormat : 
    # KeyValue               : {44, 50, 228, 201...}
    # EffectiveTime          : 20/12/2024 02:34:19
    # CreationTime           : 20/12/2024 12:34:19
    # IsFormatValid          : True
    # DomainController       : CN=DC01,OU=Domain Controllers,DC=corp,DC=demolab,DC=com
    # ServerConfiguration    : Microsoft.KeyDistributionService.Cmdlets.KdsServerConfiguration
    # KeyId                  : 060357dc-8b4c-e45e-10fc-d6d37394a1a5
    # VersionNumber          : 1
    
    # If no output, create one.
    # Add-KdsRootKey -EffectiveImmediately

# 1) Create the “allowed computers” group (recommended approach)
################################################################

    Import-Module ActiveDirectory
    
    $GroupName = "GRP-SQL-gMSA-AllowedComputers"
    $GroupPath = "CN=Users,DC=corp,DC=demolab,DC=com"   # <-- adjust to your OU
    
    New-ADGroup -Name $GroupName `
      -SamAccountName $GroupName `
      -GroupScope Global `
      -GroupCategory Security `
      -Path $GroupPath `
      -Description "Computers allowed to use sqlsvcgmsa$ gMSA for SQL services"

# 2) Ensure AD computer accounts exist (create DISABLED if missing with CORP\djoin), then add to group
######################################################################################################

    Import-Module ActiveDirectory
    
    $GroupName  = "GRP-SQL-gMSA-AllowedComputers"
    $CsvPath    = "\\fs01\VMMlibrary\Install-SQL.cr\ListOfSQLServers.csv"   # CSV with column 'ComputerName'
    $TargetPath = "CN=Computers,DC=corp,DC=demolab,DC=com"                  # where to (pre)create accounts
    $Creator    = "CORP\djoin"                                              # delegated account for creation
    
    if (-not (Test-Path $CsvPath)) {
        throw "CSV not found at '$CsvPath'. Please verify the path."
    }
    
    # Prompt once for CORP\djoin creds (only if we actually need to create objects)
    $creatorCred = $null
    
    # Build list from CSV → distinct ComputerName → sAMAccountName with trailing '$'
    $computers =
        Import-Csv -Path $CsvPath |
        Select-Object -ExpandProperty ComputerName |
        Where-Object { $_ -and $_.Trim() -ne '' } |
        Sort-Object -Unique |
        ForEach-Object {
            [PSCustomObject]@{
                ComputerName   = $_
                SamAccountName = "$_`$"   # AD computer sAMAccountName ends with '$'
            }
        }
    
    $toAddSam = @()
    $created  = @()
    $skipped  = @()
    
    foreach ($c in $computers) {
    
        # Does the computer account already exist?
        $existing = Get-ADComputer -LDAPFilter "(sAMAccountName=$($c.SamAccountName))" -ErrorAction SilentlyContinue
    
        if ($existing) {
            # Already exists — do not change its enabled/disabled state here
            $toAddSam += $c.SamAccountName
            continue
        }
    
        # Need to create it (DISABLED) using CORP\djoin
        if (-not $creatorCred) {
            $creatorCred = Get-Credential -Message "Enter credentials for $Creator" -UserName $Creator
        }
    
        try {
            # --- SPLATTING (no backticks) ---
            $NewADComputerParams = @{
                Name           = $c.ComputerName
                SamAccountName = $c.SamAccountName
                Path           = $TargetPath
                Enabled        = $false       # create DISABLED as requested
                Credential     = $creatorCred
                # Server       = 'dc01.corp.demolab.com'   # (optional) pin to one DC
            }
    
            New-ADComputer @NewADComputerParams
    
            $created  += $c.ComputerName
            $toAddSam += $c.SamAccountName
        }
        catch {
            Write-Warning "Failed to create AD computer '$($c.ComputerName)' in '$TargetPath' : $($_.Exception.Message)"
            $skipped += $c.ComputerName
        }
    }
    
    # Add all existing/new accounts to the group (in one call if possible)
    if ($toAddSam.Count -gt 0) {
        try {
            Add-ADGroupMember -Identity $GroupName -Members $toAddSam -ErrorAction Stop
            Write-Host "Added $($toAddSam.Count) computer account(s) to group '$GroupName'."
        }
        catch {
            Write-Warning "Group add failed in batch: $($_.Exception.Message). Retrying one-by-one..."
            foreach ($m in $toAddSam) {
                try { Add-ADGroupMember -Identity $GroupName -Members $m -ErrorAction Stop }
                catch { Write-Warning "  - Could not add '$m' : $($_.Exception.Message)" }
            }
        }
    } else {
        Write-Host "No accounts to add to '$GroupName'."
    }
    
    # Summary
    if ($created.Count) { Write-Host "`nCreated (disabled) accounts: $($created -join ', ')" }
    if ($skipped.Count) { Write-Warning "Skipped (create failed): $($skipped -join ', ')" }
    
    # Optional: Show current membership
    Get-ADGroupMember -Identity $GroupName | Select-Object Name, SamAccountName, ObjectClass

# 3) Create the gMSA: sqlsvcgmsa$
#################################

    Import-Module ActiveDirectory
    
    $gMSAName  = "sqlsvcgmsa"
    $DomainFqdn = "corp.demolab.com"
    $AllowedGroup = "GRP-SQL-gMSA-AllowedComputers"
    
    New-ADServiceAccount -Name $gMSAName `
      -DNSHostName "$gMSAName.$DomainFqdn" `
      -PrincipalsAllowedToRetrieveManagedPassword $AllowedGroup `
      -ManagedPasswordIntervalInDays 30 `
      -Enabled $true
    
    # Verify the gMSA properties
    
    Get-ADServiceAccount $gMSAName -Properties DNSHostName,Enabled,ManagedPasswordIntervalInDays,PrincipalsAllowedToRetrieveManagedPassword |
      Format-List DNSHostName,Enabled,ManagedPasswordIntervalInDays,PrincipalsAllowed


