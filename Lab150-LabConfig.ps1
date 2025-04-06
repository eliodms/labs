$LabConfig=@{ DomainAdminName='LabAdmin'; AdminPassword='LS1setup!' ; Prefix = '_' ; DCEdition='4' ; Internet=$true ; TelemetryLevel='None' ; TelemetryNickname='' ; AdditionalNetworksConfig=@(); VMs=@()} 

1..5 | ForEach-Object { $VMNames="Storage" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D'      ; ParentVHD = 'Win2022Core_G2.vhdx'; SSDNumber = 0; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB } }
1..5 | ForEach-Object { $VMNames="Compute" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'Simple'   ; ParentVHD = 'Win2022Core_G2.vhdx'; MemoryStartupBytes= 1GB ; NestedVirt = $True} }

# Execution of Deploy.ps1 will need around 18 minutes
