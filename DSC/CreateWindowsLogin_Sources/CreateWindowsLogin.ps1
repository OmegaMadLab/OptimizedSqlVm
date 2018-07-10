configuration CreateWindowsLogin
{
    param(
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName)
    )

    Import-DscResource -ModuleName SqlServerDsc
    [System.Management.Automation.PSCredential]$SqlAdministratorCredential = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    
    Node localhost
    {
        SqlServerLogin Add_WindowsUser
        {
            Ensure               = 'Present'
            Name                 = "$DomainNetbiosName\$($AdminCreds.UserName)"
            LoginType            = 'WindowsUser'
            ServerName           = $env:COMPUTERNAME
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
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
