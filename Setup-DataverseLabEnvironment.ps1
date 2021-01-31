<#
	.SYNOPSIS 
    Create new users and Power Apps environment environments in a given Tenant

	.NOTES  
    File Name  : Configure-DataverseLabEnvironment.ps1 
    Author     : Nicolas Nowinski - https://github.com/nicknow/ or https://nicknow.net
    Source     : https://github.com/nicknow/Setup-DataverseLabEnvironment
    Forked From: https://github.com/jamesnovak/SetupAIAD
    
    .PARAMETER TargetTenant 
    Name of the target tenant. Ex: 'contoso' for admin@contoso.onmicrosoft.com

    .PARAMETER UserName
    The username with appropriate permission in the target tenant. Ex: 'admin' for admin@contoso.onmicrosoft.com

    .PARAMETER Password
    The password for the user with appropriate permission in the target tenant

    .PARAMETER TenantRegion
    The region in which the target tenant is deployed

    .PARAMETER CDSLocation
    The location in which the target CDS environment is deployed.  Available CDSLocation values
        * `unitedstates`             (United States)
        * `europe`                   (Europe)
        * `asia`                     (Asia)
        * `australia`                (Australia)
        * `india`                    (India)
        * `japan`                    (Japan)
        * `canada`                   (Canada)
        * `unitedkingdom`            (United Kingdom)
        * `unitedstatesfirstrelease` (Preview (United States))
        * `southamerica`             (South America)
        * `france`                   (France)

    .PARAMETER NewUserPassword
    The default password for the new users that will be created in the target tenant

    .PARAMETER UserCount
    The number new users that will be created in the target tenant. Default: 20

    .PARAMETER MaxRetryCount
    The number of retries when an error occurs. Default: 5

    .PARAMETER SleepTime
    The time to sleep between retries when an error occurs. Default: 10

    .PARAMETER ForceUpdateModule
    Flag indicating whether to force an update of the required PS modules. Default: false

    .PARAMETER useSecurityGroup
    Flag indicating if each environment should have a security group generated and assigned. The user for the environment will be automatically added to the security group. Default: false

    .PARAMETER installSampleApps
    Flag indicating if the Power Apps Sample Apps should be installed with the database. Default: false

    .INPUTS
    None. You cannot pipe objects to Setup-DataverseLabEnvironment.ps1.

    .OUTPUTS
    None. Setup-DataverseLabEnvironment.ps1 does not generate any output.

    .EXAMPLE
    .\Setup-DataverseLabEnvironment.ps1 -TargetTenant 'mytenant' -UserName 'admin' -Password 'Admin Password' -TenantRegion 'US' -CDSLocation unitedstates -NewUserPassword 'password' -UserCount 2 -useSecurityGroup $true -installSampleApps $true
#>
param (
    [Parameter(Mandatory=$true, ParameterSetName="Credentials", HelpMessage="Enter the name of the target tenant. Ex: 'contoso' for admin@contoso.onmicrosoft.com.") ] 
    [string]$TargetTenant,

    [Parameter(Mandatory=$true, ParameterSetName="Credentials", HelpMessage="Enter the username with appropriate permission in the target tenant. Ex: 'admin' for admin@contoso.onmicrosoft.com.")]
    [string]$UserName,

    [Parameter(Mandatory=$true, ParameterSetName="Credentials", HelpMessage="Enter the password for the user with appropriate permission in the target tenant.")]
    [string]$Password,

    [Parameter(Mandatory = $true, ParameterSetName="Credentials", HelpMessage="Enter the region code in which the target tenant is deployed.")]
    [string]$TenantRegion="US",

    [Parameter(Mandatory = $true, ParameterSetName="Credentials", HelpMessage="Enter the location name in which the target CDS environment is deployed.")]
    [string]$CDSLocation="unitedstates",

    [Parameter(Mandatory=$false, HelpMessage="Enter the default password for the new users that will be created in the target tenant.")]
    [string]$NewUserPassword = 'pass@word1',

    [Parameter(Mandatory=$false, HelpMessage="Enter the number new users that will be created in the target tenant.")]
    [int]$UserCount = 20,

    [Parameter(Mandatory=$false, HelpMessage="Enter the number of retries when an error occurs.")]
    [int]$MaxRetryCount = 5,

    [Parameter(Mandatory=$false, HelpMessage="Enter the time to sleep between retries when an error occurs.")]
    [int]$SleepTime = 10,

    [Parameter(Mandatory=$false, HelpMessage="Flag indicating whether to force an update of the required PS modules.")]
    [bool]$ForceUpdateModule = $false,

    [Parameter(Mandatory=$false, HelpMessage="Flag indicates whether to create a security group for each environment.")]
    [bool]$useSecurityGroup = $false,

    [Parameter(Mandatory=$false, HelpMessage="Flag indicates whether to install the Sample Apps for each environment.")]
    [bool]$installSampleApps = $false
 )

# ***************** ***************** 
#  Set default parameters if null, 
#   global variables
# ***************** *****************
 
# Not sure why this is needed if parameters have default, but leaving just in case it was necessary for some use case
if ($NewUserPassword -eq $null) { $NewUserPassword = "pass@word1" }
if ($SleepTime -eq $null)       { $SleepTime = 10 }
if ($MaxRetryCount -eq $null)   { $MaxRetryCount= 5 }
if ($UserCount -eq $null)       { $UserCount = 20 }

Write-Host "SleepTime: " $SleepTime
Write-Host "MaxRetryCount: " $MaxRetryCount
Write-Host "UserCount: " $UserCount
Write-Host "Tenant: " $Tenant
Write-Host "CDSLocation: " $CDSLocation
Write-Host "ForceUpdateModule: " $ForceUpdateModule
Write-Host "Use Security Group: " $useSecurityGroup
Write-Host "Install Sample Apps: " $installSampleApps

$global:lastErrorCode = $null

#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

function Install-ExpectedModule
{
   param
    (
    [Parameter(Mandatory = $true)]
    [string]$mod,
    [Parameter(Mandatory = $false)]
    [bool]$Update=$true
    )
    if (Get-Module -ListAvailable -Name $mod) {
	
        if ($Update) 
        {
            Write-Host "Updating module: " $mod
            Update-Module $mod -Force            
        }
        else {
            Write-Host "Module already installed: " $mod
        }
    } 
    else {
        Write-Host "Installing module: " $mod
        Install-Module $mod -Scope CurrentUser -AllowClobber -Force
    }

    Write-Host "Importing module: " $mod
    Import-Module $mod

}

# ***************** ***************** 
# Create-CDSUsers
# ***************** ***************** 
function Create-CDSUsers
{
   param
    (
    [Parameter(Mandatory = $true)]
    [string]$Tenant=$TargetTenant,
    [Parameter(Mandatory = $true)]
    [int]$Count=$UserCount,
    [Parameter(Mandatory = $false)]
    [string]$Region=$TenantRegion,
    [Parameter(Mandatory = $false)]
    [string]$password=$NewUserPassword
    )

    $DomainName = $Tenant + ".onmicrosoft.com"
    
    Write-Host "Tenant: " $Tenant
    Write-Host "Domain Name: " $DomainName
    Write-Host "Count: " $Count
    Write-Host "Licence Plans: " (Get-MsolAccountSku).AccountSkuId
    Write-Host "Region: " $Region
    Write-Host "Location: " $CDSlocation
    Write-Host "password: " $password
  
    $securepassword = ConvertTo-SecureString -String $password -AsPlainText -Force
 
    Write-Host "Begin creating users " -ForegroundColor Green
   
    for ($i=1;$i -lt $Count+1; $i++) {        

        $firstname = 'User'
        $lastname = '{0:d2}' -f $i
        $displayname = $firstname + $lastname
        $email = ("user" + $lastname + "@" + $DomainName).ToLower()
       
         New-MsolUser -DisplayName $displayname -FirstName $firstname -LastName $lastname -UserPrincipalName $email -UsageLocation $Region -Password $password -LicenseAssignment (Get-MsolAccountSku).AccountSkuId -PasswordNeverExpires $true -ForceChangePassword $false         
         
        }
        Write-Host "***************** Lab Users Created ***************" -ForegroundColor Green
        
}

# ***************** ***************** 
# Create-CDSenvironment
# ***************** ***************** 
function Create-CDSenvironment {

    param(
    [Parameter(Mandatory = $false)]
    [string]$password=$NewUserPassword,
    [Parameter(Mandatory = $false)]
    [string]$Location="unitedstates"    
    )

    $starttime= Get-Date -DisplayHint Time
    Write-Host " Starting CreateCDSEnvironment :" $starttime  -ForegroundColor Green

    $securepassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $users = Get-MsolUser | where {$_.UserPrincipalName -like 'user*'} | Sort-Object UserPrincipalName
    
    ForEach ($user in $users) 
    { 
        if ($user.isLicensed -eq $false)
        {
            write-host " skiping user " $user.UserPrincipalName " - not licensed" -ForegroundColor Red
            continue
        }

        Add-PowerAppsAccount -Username $user.UserPrincipalName -Password $securepassword -Verbose


        $envDisplayname = $user.UserPrincipalName.Split('@')[0] + "-Trial"

        # call the helper function for the environment 
        new-Environment -Displayname $envDisplayname -sku Trial -Location $Location 

        # check to see if an error occurred in the overall user loop
        if ($lastErrorCode -ne $null) {
            break
        }
    }
    $endtime = Get-Date -DisplayHint Time
    $duration = $("{0:hh\:mm\:ss}" -f ($endtime-$starttime))
    Write-Host "End of CreateCDSEnvironment at : " $endtime "  Duration: " $duration -ForegroundColor Green
}

# ***************** ***************** 
# New-Environment
# ***************** ***************** 
function new-Environment {
    param(
    [Parameter(Mandatory = $true)]
    [string]$Displayname=$null,
    [Parameter(Mandatory = $true)]
    [string]$sku='Trial',
    [Parameter(Mandatory = $true)]
    [string]$Location
    )

    $global:incre = 1
    $currEnv=$null
    $secGroupObj = $null

    
    
    while ($currEnv.EnvironmentName -eq $null)
    {
        $errorVal = $null

        Write-Host "New environment for user: " $Displayname ", Location: " $Location ", Sku:" $sku ", Attempt number " $global:incre
        
        $currEnv = New-AdminPowerAppEnvironment -DisplayName  $Displayname -LocationName $Location -EnvironmentSku $sku -ErrorVariable errorVal # -Verbose 


        # check whether to retry or to break
        if ($currEnv.EnvironmentName -eq $null) 
        {
            if ($global:incre++ -eq $MaxRetryCount) 
            {
                Write-Host "Error creating environment:" $errorVal -ForegroundColor DarkYellow
                $global:lastErrorCode = $errorVal
                break
            }
            elseif ($errorVal -ne $null) 
            {
                # pause between retries
                Write-Host "Pause before retry" -ForegroundColor Yellow
                Start-Sleep -s $SleepTime
            }
        }
    }

    Write-Host "New Environment with id:" $currEnv.EnvironmentName ", Display Name" $currEnv.DisplayName -ForegroundColor Green
}

# ***************** ***************** 
# create-CDSDatabases
# ***************** ***************** 
function create-CDSDatabases {
param(
    [Parameter(Mandatory=$true)]
    [bool]$installSampleApps,
    [Parameter(Mandatory=$true)]
    [bool]$useSecurityGroup
)

    $starttime= Get-Date -DisplayHint Time
    Write-Host "Starting CreateCDSDatabases :" $starttime -ForegroundColor Green

    $CDSenvs = Get-AdminPowerAppEnvironment | where { ($_.CommonDataServiceDatabaseType -eq "none") -and ($_.EnvironmentType  -ne 'Default')} | Sort-Object displayname

    ForEach ($CDSenv in $CDSenvs) 
    {
        $global:incre = 1

        Write-Host "Creating CDS databases for environment '"$CDSenv.DisplayName"' with id '"$CDSenv.EnvironmentName"', Attempt number: " $global:incre -ForegroundColor White

        $Params = @{}

        if ($installSampleApps) {
            $Params.Add('Templates','D365_CDSSampleApp')
        }

        if ($useSecurityGroup)
        {
            $secGroupName = $CDSenv.DisplayName + "-PASecGroup"
            $secGroupDescription = "Security Group for Power Apps Environment " + $CDSenv.DisplayName
            $secGroupObj = New-MsolGroup -DisplayName $secGroupName -Description $secGroupDescription
            Start-Sleep -s 2
            $userId = (Get-MsolUser -UserPrincipalName $CDSenv.CreatedBy.userPrincipalName).ObjectId
            Add-MsolGroupMember -GroupObjectId $secGroupObj.ObjectId -GroupMemberType User -GroupMemberObjectId $userId
            $Params.Add('SecurityGroupId',$secGroupObj.ObjectId)
            Write-Host "Created Security Group : " $secGroupName " / " $secGroupObj.ObjectId
            Start-Sleep -s 5
        }

        $firstRun = $true

        # check whether to retry or to break
        while ($CDSenv.CommonDataServiceDatabaseType -eq "none")
        {
            $errorVal = $null

            Write-Host "Current CDS DBType: " $CDSenv.CommonDataServiceDatabaseType            

            if ($firstRun)
            {
                New-AdminPowerAppCdsDatabase -EnvironmentName $CDSenv.EnvironmentName -CurrencyName USD -LanguageName 1033 @Params -ErrorVariable errorVal -ErrorAction SilentlyContinue #-Verbose 
                $firstRun = $false
                Write-Host "Completed New Database Request" 
            }

            Start-Sleep -s $SleepTime

            $CDSenv=Get-AdminPowerAppEnvironment -EnvironmentName $CDSenv.EnvironmentName -ErrorVariable errorVal
            
            if ($CDSenv.CommonDataServiceDatabaseType -eq "none")
            {                

                # pause between retries
                if ($global:incre++ -eq $MaxRetryCount) 
                {
                    Write-Host "Error creating database:" $errorVal -ForegroundColor DarkYellow
                    $lastErrorCode = $errorVal
                    break
                }
                elseif ($errorVal -ne $null) 
                {
                    Write-Host "Error. Pause before retry" -ForegroundColor Yellow
                    Start-Sleep -s $SleepTime
                }
                else
                {
                    Write-Host "Provisioning Status: " $CDSenv.CommonDataServiceDatabaseProvisioningState
                    Write-Host "Pausing before next check" -ForegroundColor Yellow
                    Start-Sleep -s $SleepTime    
                }
            }
            else 
            {
                Write-Host "New '"$CDSenv.CommonDataServiceDatabaseType"' created for" $CDSenv.DisplayName -ForegroundColor White
            }

        }

        # check to see if an error occurred in the overall user loop
        if ($lastErrorCode -ne $null){
            break
        }
    }

    $endtime = Get-Date -DisplayHint Time
    $duration = $("{0:hh\:mm\:ss}" -f ($endtime-$starttime))
    Write-Host "End of CreateCDSDatabases at :" $endtime ", Duration: " $duration -ForegroundColor Green
}

# ***************** ***************** 
# Setup-CDSenvironments 
# ***************** ***************** 
function Setup-CDSenvironments 
{
    param(
    [Parameter(Mandatory = $false)]
    [string]$Location="unitedstates",
    [Parameter(Mandatory=$true)]
    [bool]$useSecurityGroup = $true,
    [Parameter(Mandatory=$true)]
    [bool]$installSampleApps
    )

    Create-CDSenvironment -Location $Location

    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password -Verbose

    Write-Host "Start creating the CDS Databases in a few seconds" -ForegroundColor Yellow
    Start-Sleep -s 10

    create-CDSDatabases -useSecurityGroup $useSecurityGroup -installSampleApps $installSampleApps    
}

# ***************** ***************** 
# Delete-CDSenvironment
# ***************** ***************** 
function Delete-CDSenvironment
{
    #Connect to Powerapps with your admin credential
    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password -Verbose

    #delete all environemnts
    $envlist=Get-AdminPowerAppEnvironment | where {$_.EnvironmentType  -ne 'Default'}

    ForEach ($env in $envlist) { 
        Write-Host "Delete CDS Environment :" $env.EnvironmentName -ForegroundColor Green
        Remove-AdminPowerAppEnvironment -EnvironmentName $env.EnvironmentName

        
    }

    #Clean up security groups
    Get-MsolGroup | Remove-MsolGroup -Force
}

# ***************** ***************** 
# Delete-CDSUsers
# ***************** ***************** 
function Delete-CDSUsers{

    Get-MsolUser | where {$_.UserPrincipalName -like 'user*' -and $_.UserPrincipalName -ne $user}|Remove-MsolUser -Force
    Write-Host "*****************Lab Users Deleted ***************" -ForegroundColor Green
}

# ***************** ***************** 
# Import required modules
# ***************** ***************** 
Import-Module Microsoft.PowerShell.Utility
Install-ExpectedModule -mod 'Microsoft.PowerApps.Administration.PowerShell' -Update $ForceUpdateModule
Install-ExpectedModule -mod 'Microsoft.PowerApps.PowerShell' -Update $ForceUpdateModule
Install-ExpectedModule -mod 'MSOnline' -Update $ForceUpdateModule

Write-Host "***************** Modules Installed/Updated ***************" -ForegroundColor Green


# ***************** ***************** 
# Build the username/pw for the module call
# ***************** ***************** 
$user = $UserName + "@" + $TargetTenant + ".onmicrosoft.com"
$pass = ConvertTo-SecureString $Password -AsPlainText -Force

Add-PowerAppsAccount -Username $User -Password $pass -Endpoint 'prod'

$UserCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $pass

# ***************** ***************** 
# IF YOU WANT TO BE PROMPTED, YOU CAN USE THIS
# $UserCredential = Get-Credential
# ***************** ***************** 
Connect-MsolService -Credential $UserCredential

Exit-PSSession 

#connect to powerapps
Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password -Endpoint 'prod' -Verbose

Write-Host "********** Existing CDS environments **************"
Get-AdminPowerAppEnvironment | Sort-Object displayname  | fl displayname


# BE AWARE THAT THIS WILL DELETE ALL ENVIRONMENTS EXCEPT DEFAULT
Delete-CDSenvironment

Delete-CDSUsers

Write-Host "***************** Cleanup Completed ***************" -ForegroundColor Green
Start-Sleep -s 5

if ($UserCount -gt 0) 
{
    Write-Host "***************** Starting Lab Setup ***************" -ForegroundColor Green

    Create-CDSUsers -Tenant $TargetTenant -Count $UserCount -Region $TenantRegion -password $NewUserPassword
    Write-Host "Start creating the Environments in a few seconds" -ForegroundColor Yellow
    Start-Sleep -s 5

    Setup-CDSenvironments -Location $CDSLocation -useSecurityGroup $useSecurityGroup -installSampleApps $installSampleApps

    Write-Host "***************** Lab Users Created ***************" -ForegroundColor Green
    Get-MsolUser | where {$_.UserPrincipalName -like 'user*'}|ft UserPrincipalName,licenses

    Write-Host "Password for Generated User Accounts: " $NewUserPassword
    
    Write-Host "***************** Environments Created ***************" -ForegroundColor Green
    Get-AdminPowerAppEnvironment | Sort-Object displayname  | ft displayname

}