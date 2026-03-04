# ================================
# 32 GB RAM – Smooth Demo Profile
# SCVMM Guided Labs on WS2022
# ================================

$LabConfig = @{
    DomainAdminName     = 'Labadmin'
    AdminPassword       = 'LS1setup!'
    Prefix              = 'LAB-'
    SwitchName          = 'LabSwitch'
    SecureBoot          = $true
    DCEdition           = '4'        # Datacenter
    Internet            = $true
    InstallSCVMM        = 'Yes'
    MGMTNICsInDC        = 2
    AdditionalNetworksConfig = @()
    VMs                 = @()
}

# ----------------------------
# Compute Hosts (GUI)
# ----------------------------
1..2 | ForEach-Object {
    $LabConfig.VMs += @{
        VMName              = "Compute$_"
        Configuration       = 'Simple'
        ParentVHD           = 'Win2022_G2.vhdx'
        MemoryStartupBytes  = 6GB
        VMProcessorCount    = 2
        NestedVirt          = $true
        MGMTNICs            = 2
    }
}

# ----------------------------
# Storage Nodes (WS2022 Core)
# ----------------------------

1..4 | ForEach-Object { 
       $VMNames="S2D";                              # Here you can bulk edit name of 4 VMs created. In this case will be s2d1,s2d2,s2d3,s2d4 created
       $LABConfig.VMs += @{ 
              VMName = "$VMNames$_" ; 
              Configuration = 'S2D' ;               # Simple/S2D/Shared/Replica
              ParentVHD = 'Win2022_G2.vhdx';        # VHD Name from .\ParentDisks folder
              VMProcessorCount    = 2
              MGMTNICs            = 2
              SSDNumber = 5;                        # Number of "SSDs" (its just simulation of SSD-like sized HDD, just bunch of smaller disks)
              SSDSize=800GB ;                       # Size of "SSDs"
              HDDNumber = 12;                       # Number of "HDDs"
              HDDSize= 4TB ;                        # Size of "HDDs"
              MemoryStartupBytes= 3GB             # Startup memory size
       } 
}
