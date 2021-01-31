# Configure-DataverseLabEnvironment
Please review the document [Creating Office 365 PowerApps Trial Environments.docx](/Creating%20Office%20365%20PowerApps%20Trial%20Environments.docx) if you require a Power Apps environment.

>__** ⚠ WARNING ⚠ **__ This script is intended for lab-like environments only. It will delete existing users, groups, Power Apps Environments/Dataverse Databases without warning. 

PowerShell scripts that will automate setting up one or more CDS users and Power Apps environments. The script will:
* Create one or more user accounts with UserXX usernames
* Assign licenses to the user accounts
* Create a new Power Apps environment for each new user
* Create a new CDS data base for each environment
* Optionally install the Sample Apps package
* Optionally create a security group for each environment and add the environment's user to the group

Before running this script, you will need to login to the [https://make.powerapps.com](https://make.powerapps.com) site at least once.

When setting up the database it does polling (based on the MaxRetryCount and SleepTime parameters) so that we don't flood the service with 20 requests in a matter of seconds. If the MaxRetryCount is hit before provisioning is completed it will report as an error but if it showed LinkedDatabaseProvisioning as status there is unlikely to be an issue. You will just need to wait for it to complete provisioning before a user can access it. This can be seen in the [Power Platform Administration Center](https://admin.powerplatform.microsoft.com/) or by running [`Get-AdminPowerAppEnvironment`](https://docs.microsoft.com/en-us/powershell/module/microsoft.powerapps.administration.powershell/get-adminpowerappenvironment).

This script was  forked from [Jim Novak's script](https://github.com/jamesnovak/SetupAIAD) which is based on those provided with the Microsoft [App In A Day](https://aka.ms/AIADEvent) trainer package.

## PARAMETERS

* `TargetTenant`
Name of the target tenant. Ex: `'contoso'` for admin@contoso.onmicrosoft.com

* `UserName`
The username with appropriate permission in the target tenant. Ex: `'admin'` for admin@contoso.onmicrosoft.com

* `Password`
The password for the user with appropriate permission in the target tenant

* `TenantRegion`
The region in which the target tenant is deployed

* `CDSLocation`
The location in which the target CDS environment is deployed. Default: `unitedstates`
Available CDSLocation values
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

* `NewUserPassword`
The default password for the new users that will be created in the target tenant. Default: `'pass@word1'`

* `UserCount`
The number new users that will be created in the target tenant. Default: `20`  
If you would simply like to clear out all users and environments, enter `0`

* `MaxRetryCount`
The number of retries when an error occurs. Default: `3`

* `SleepTime`
The time to sleep between retries when an error occurs. Default: `5`

* `ForceUpdateModule`
Flag indicating whether to force an update of the required PS modules.  Default: `false`

* `useSecurityGroup`
Flag indicating if each environment should have a security group generated and assigned. The user for the environment will be automatically added to the security group.

* `installSampleApps`
Flag indicating if the Power Apps Sample Apps should be installed with the database.

## EXAMPLE USAGE
>__** ⚠ WARNING ⚠ **__ This script is intended for lab-like environments only. It will delete existing users, groups, Power Apps Environments/Dataverse Databases without warning. 

`.\Setup-DataverseLabEnvironment.ps1 -TargetTenant 'mytenant' -UserName 'admin' -Password 'Admin Password' -TenantRegion 'US' -CDSLocation unitedstates -NewUserPassword 'password' -UserCount 2 -useSecurityGroup $true -installSampleApps $true
`