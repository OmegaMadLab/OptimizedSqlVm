configuration SqlDscConfig
{
    param
    (
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, PSDesiredStateConfiguration, SqlServerDsc
    [System.Management.Automation.PSCredential]$SqlAdministratorCredential = New-Object System.Management.Automation.PSCredential ("$env:COMPUTERNAME\$($Admincreds.UserName)", $Admincreds.Password)

    $RebootVirtualMachine = $true

    if ($DomainName)
    {
        [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
        [System.Management.Automation.PSCredential]$DomainFQDNCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    }

    Node localhost
    {
        if ($DomainName)
        {
            WindowsFeature ADPS
            {
                Name = "RSAT-AD-PowerShell"
                Ensure = "Present"
            }

            xWaitForADDomain DscForestWait 
            { 
                DomainName = $DomainName 
                DomainUserCredential= $DomainCreds
                RetryCount = $RetryCount 
                RetryIntervalSec = $RetryIntervalSec 
                DependsOn = "[WindowsFeature]ADPS"
            }
            
            xComputer DomainJoin
            {
                Name = $env:COMPUTERNAME
                DomainName = $DomainName
                Credential = $DomainCreds
                DependsOn = "[xWaitForADDomain]DscForestWait"
            }

            SqlServerLogin Add_WindowsUser
            {
                Ensure               = 'Present'
                Name                 = "$DomainNetbiosName\$($AdminCreds.UserName)"
                LoginType            = 'WindowsUser'
                ServerName           = $env:COMPUTERNAME
                InstanceName         = 'MSSQLSERVER'
                PsDscRunAsCredential = $SqlAdministratorCredential
                DependsOn = "[xComputer]DomainJoin"
            }

            SqlServerRole Add_ServerRole_SysAdmin
            {
                Ensure               = 'Present'
                ServerRoleName       = 'sysadmin'
                MembersToInclude     = "$DomainNetbiosName\$($AdminCreds.UserName)"
                ServerName           = $env:COMPUTERNAME
                InstanceName         = 'MSSQLSERVER'
                PsDscRunAsCredential = $SqlAdministratorCredential
                DependsOn = "[SqlServerLogin]Add_WindowsUser"
            }
        }

        Registry CredSSP1 {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
            ValueName = "AllowFreshCredentials"
            ValueData = "1"
            ValueType = "Dword"
        }

        Registry CredSSP2 {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
            ValueName = "AllowFreshCredentialsWhenNTLMOnly"
            ValueData = "1"
            ValueType = "Dword"
        }

        Registry CredSSP3 {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials"
            ValueName = "1"
            ValueData = "WSMAN/*.$DomainName"
            ValueType = "String"
            DependsOn = "[Registry]CredSSP1"
        }

        Registry CredSSP4 {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly"
            ValueName = "1"
            ValueData = "WSMAN/*.$DomainName"
            ValueType = "String"
            DependsOn = "[Registry]CredSSP2"
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $true
        }

    }
}
function Get-NetBIOSName
{ 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}
