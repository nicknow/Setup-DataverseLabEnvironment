function  Install-RequiredModules { param
    (
    [Parameter(Mandatory = $true)]
    [string]$module        
    )
    #Import-Module $module
    Install-Module $module -Scope CurrentUser -AllowClobber -Force
    
}

Install-RequiredModules -module 'Microsoft.PowerApps.Administration.PowerShell'
Install-RequiredModules -module 'Microsoft.PowerApps.PowerShell'
Install-RequiredModules -module 'MSOnline'


$user = "admin@tppscript766.onmicrosoft.com"
$pass = ConvertTo-SecureString "undfui#@9d92M" -AsPlainText -Force

Add-PowerAppsAccount -Username $User -Password $pass -Endpoint prod
