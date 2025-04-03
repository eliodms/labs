$LabConfig=@{ DomainAdminName='LabAdmin'; AdminPassword='LS1setup!' ; Prefix = '_' ; DCEdition='4' ; Internet=$true ; TelemetryLevel='None' ; TelemetryNickname='' ; AdditionalNetworksConfig=@(); VMs=@()} 

# 2 HyperConverged Clusters 
1..2 | ForEach-Object {$VMNames="1-S2D"; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; ParentVHD = 'Win2022_G2.vhdx'; SSDNumber = 0; SSDSize=800GB ; HDDNumber = 12; HDDSize= 4TB ; MemoryStartupBytes= 2.2GB ; StaticMemory=$true ; NestedVirt=$True}} 
1..2 | ForEach-Object {$VMNames="2-S2D"; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; ParentVHD = 'Win2022_G2.vhdx'; SSDNumber = 0; SSDSize=800GB ; HDDNumber = 12; HDDSize= 4TB ; MemoryStartupBytes= 2.2GB ; StaticMemory=$true ; NestedVirt=$True}} 

# 1 Standalone server 
1 | ForEach-Object {$VMNames="Standalone"; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; ParentVHD = 'Win2022_G2.vhdx'; SSDNumber = 0; SSDSize=800GB ; HDDNumber = 12; HDDSize= 4TB ; MemoryStartupBytes= 2.2GB ; StaticMemory=$true ; NestedVirt=$True}} 

