# Optimized SQL Server VM for Azure IaaS

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

This template allows you to deploy a SQL Server on Windows VM on Azure IaaS, following best practices explained on [official documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sql/virtual-machines-windows-sql-performance).

A DSC resource will execute domain join, if requested.

After the deployment, an Azure Custom Script extension will be launched to:
- create SQL optimized storage pools, if striping is enabled for data or log disks</li>
- create SQL optimized volumes</li>
- create folder for data files, log files, backup and errorlog
- change SQL Server default data paths
- move system DBs, errorlog and traces to appropriate volumes
- apply SQL Server optimizations like trace flags, max server memory, TempDB multiple data files provisioning.

The template isn't yet tested on all the possible scenarios, expecially in the CSE context which is indeed quite complex.
It should works correctly on the vast majority of scenarios, but please be aware you may face into small bugs.

## Parameters
Parameter|Description
---------|-----------
**vmName**|Name assigned to the VM.
**availabilitySetName**|Name of the availability set you want to join; it will be created if it doesn't already exist. Leave empty if availability set is not needed.
**adDomain**|DNS name of the AD domain you want to join. Leave empty if you don't want to join a domain during provisioning.
**adminUsername**|Admin username for the Virtual Machine. If a domain is specified in the appropriate parameter, this user will be used both for local admin and to join domain.
**adminPassword**|Admin password for the Virtual Machine.
**vnetName**|The existing virtual network you want to connect to. Leave empty to create a new ad hoc virtual network.
**vnetResourceGroup**|If using an existing vnet, specify the resource group which contains it. Leave empty if you're creating a new ad hoc network.
**subnetName**|The subnet you want to connect to.
**privateIp**|The private IP address assigned to the NIC. Specify DHCP to use a dynamically assigned IP address.
**enableAcceleratedNetworking**|Choose YES to enable accelerated networking on VM which supports it. **Please note that enabling this feature on a virtual machine family that doesn't support it will prevent template from being deployed.**
**enablePublicIp**|Choose YES to assign a public IP to this VM.
**dnsLabelPrefix**|If a public IP is enabled for this VM, assign a DNS label prefix for it. Leave empty if public IP is not enabled.
**asgIds**|Array of Application Security Groups where the VM must be inserted into. Leave empty if not necessary.
**sqlVersion**|The Azure Marketplace SQL Server image used as base to deploy this VM.
**vmSize**|The family and size for this VM.
**useAHB**|Choose YES to enable Azure Hybrid Benefits for this VM, and use an already owned Windows Server license on it. Choose NO if Windows Server licensing fee must be included on VM cost.
**timeZone**|The time zone for this VM.
**osDiskSuffix**|The suffix used to compose the OS disk name. Final disk name will be composed as *[vmName-osDiskSuffix]*.
**additionalDiskSuffix**|The suffix used to compose the additional disk (data, log, backup) name. Final disk name will be composed as *[vmName]-[dataDiskSuffix][number of the disk, starting with 1]*
**osDiskStorageSKU**|The kind of storage used for OS disk used by this VM. Values can be *Standard_LRS*, *StandardSSD_LRS*, *Premium_LRS*, *UltraSSD_LRS*.
**dataDiskStorageSKU**|The kind of storage used for data disks used by this VM. Values can be *Standard_LRS*, *StandardSSD_LRS*, *Premium_LRS*, *UltraSSD_LRS*. Please note that storage sku backup disks is governed by a template variable.
**workloadType**|The kind of workload which will tipically run on this VM. It's used to configure various paramters like stripe size, SQL trace flags, etc.
**#ofDataDisks**|Number of managed disks which will host SQL Server data files. Cache will be set to 'ReadOnly' for Premium disks or 'None' for Standard disks.
**dataDisksSize**|Size of managed disks which will host SQL Server data files.
**stripeDataDisks**|Choose YES to configure a striped Storage Pool on all data disks.
**#ofLogDisks**|Number of managed disks which will host SQL Server log files. Cache will be set to 'None' both for Premium and Standard disks.
**logDisksSize**|Size of managed disks which will host SQL Server log files.
**stripeLogDisks**|Choose YES to configure a striped Storage Pool on all log disks.
**#ofAdditionalDisks**|Number of managed disks which will be used for generic workloads like backup. These will be always provisioned as Standard managed disks and cache will be set to 'None'.
**AdditionalDisksSize**|Size of managed disks which will be used for generic workloads like backup.
**diagStorageAccountName**|The name of the storage account used to store diagnostic data for this VM; if it doesn't exist, it will be created. Leave it empty to create an ad hoc storage account.
**EnableSqlIaasExtension**|Choose YES to install the official SQL IaaS Extension on the VM. It currently works only on default instances, so if you plan to deploy a named instance you can choose NO to avoid its deployment.
