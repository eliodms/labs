#Variables

#clusterconfig
$Clusters=@()
$Clusters+=@{Nodes="1-S2D1","1-S2D2" ; Name="Cluster1" ; IP="10.0.0.211" ; Volumenames="CL1Mirror1","CL1Mirror2" ; VolumeSize=2TB}
$Clusters+=@{Nodes="2-S2D1","2-S2D2" ; Name="Cluster2" ; IP="10.0.0.212" ; Volumenames="CL2Mirror1","CL2Mirror2" ; VolumeSize=2TB}

# Install features for management
    $WindowsInstallationType=Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\' -Name InstallationType
    if ($WindowsInstallationType -eq "Server"){
        Install-WindowsFeature -Name RSAT-Clustering,RSAT-Clustering-Mgmt,RSAT-Clustering-PowerShell,RSAT-Hyper-V-Tools,RSAT-Feature-Tools-BitLocker-BdeAducExt,RSAT-Storage-Replica,RSAT-AD-PowerShell
    }elseif ($WindowsInstallationType -eq "Server Core"){
        Install-WindowsFeature -Name RSAT-Clustering,RSAT-Clustering-PowerShell,RSAT-Hyper-V-Tools,RSAT-Storage-Replica,RSAT-AD-PowerShell
    }

# Install features on servers
    Invoke-Command -computername $clusters.nodes -ScriptBlock {
        Install-WindowsFeature -Name "Failover-Clustering","Hyper-V-PowerShell","Hyper-V" -IncludeAllSubFeature -IncludeManagementTools
    }

# Same on standalone1
    Invoke-Command -computername "Standalone1" -ScriptBlock {
        Install-WindowsFeature -Name "Failover-Clustering","Hyper-V-PowerShell","Hyper-V" -IncludeAllSubFeature -IncludeManagementTools
    }

#reboot servers to finish Hyper-V install
    Restart-Computer $clusters.nodes -Protocol WSMan -Wait -For PowerShell
    start-sleep 20 #failsafe
    Restart-Computer "Standalone1" -Protocol WSMan -Wait -For PowerShell 
    start-sleep 20 #failsafe

#create clusters
    foreach ($Cluster in $clusters){
        New-Cluster -Name $Cluster.Name -Node $Cluster.Nodes -StaticAddress $Cluster.IP
    }

#add file share witnesses
    foreach ($Cluster in $clusters){
        #Create new directory
            $WitnessName=$Cluster.name+"Witness"
            Invoke-Command -ComputerName DC -ScriptBlock {new-item -Path c:\Shares -Name $using:WitnessName -ItemType Directory}
            $accounts=@()
            $accounts+="corp\$($Cluster.Name)$"
            $accounts+="corp\Domain Admins"
            New-SmbShare -Name $WitnessName -Path "c:\Shares\$WitnessName" -FullAccess $accounts -CimSession DC
        #Set NTFS permissions
            Invoke-Command -ComputerName DC -ScriptBlock {(Get-SmbShare $using:WitnessName).PresetPathAcl | Set-Acl}
        #Set Quorum
            Set-ClusterQuorum -Cluster $Cluster.name -FileShareWitness "\\DC\$WitnessName"
    }


#enable s2d
    foreach ($Cluster in $clusters){
        Enable-ClusterS2D -CimSession $Cluster.Name -confirm:0 -Verbose
    }

#create volumes
    Foreach ($Cluster in $clusters){
        New-Volume -StoragePoolFriendlyName "S2D on $($Cluster.Name)" -FriendlyName $Cluster.VolumeNames[0] -FileSystem CSVFS_ReFS -StorageTierFriendlyNames Capacity -StorageTierSizes $Cluster.VolumeSize -CimSession $Cluster.Name
        New-Volume -StoragePoolFriendlyName "S2D on $($Cluster.Name)" -FriendlyName $Cluster.VolumeNames[1]  -FileSystem CSVFS_ReFS -StorageTierFriendlyNames Capacity -StorageTierSizes $Cluster.VolumeSize -CimSession $Cluster.Name
    }
