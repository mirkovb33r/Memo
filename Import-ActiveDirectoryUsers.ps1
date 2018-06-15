#Structure of Domain Users
#default values can be set here.
$DomainUser = @{
	# These are properties that provide additional information about the user; Nice to have, but not must have.
	OptionalPropteries=@{
		###											  ###
		#    Used for Setting Base Account Details      #
		###											  ###
		description=""
		#Email Address
		mail=""
		#Job Title
		title=""
		#Fax Number
		facsimileTelephoneNumber="+61 2 9383 6100"
		#Telephone number, as it appears in the General Tab
		telephoneNumber=""
		#Location
		l=""
		#Should be a DN eg. CN=Alex Falkowski,OU=Users,OU=Sydney,OU=Clients,OU=Windows 7,DC=9msn,DC=net
		Manager=""
		wWWHomePage=""
		###											  ###
		# Used for Setting Office Communications Server #
		###											  ###
		'msRTCSIP-PrimaryUserAddress'=""
		'msRTCSIP-Line'=""
		'msRTCSIP-PrimaryHomeServer'="CN=LC Services,CN=Microsoft,CN=ocspool1,CN=Pools,CN=RTC Service,CN=Microsoft,CN=System,DC=9msn,DC=net"
		'msRTCSIP-UserEnabled'="TRUE"
		'msRTCSIP-UserLocationProfile'=""
		'msRTCSIP-UserPolicy'=""
		'msRTCSIP-FederationEnabled'="TRUE"
		'msRTCSIP-InternetAccessEnabled'="TRUE"
		'msRTCSIP-OptionFlags'="385"
	}
	
    # User validation will fail if these properties are not set.
    RequiredProperties=@{
		###											     ###
		# Core properties for Setting Base Account Details #
		###											  	 ###
		#Common Name
        cn=""
		#First Name
        "givenName"=""
		#Surname
        "sn"=""
		#Windows 2000 System (legacy) account name eg. firstname.lastname
        "sAMAccountName"=""
		#Windows NT 4 account name, username@domain.com
        "userPrincipalName"=""
		#Account Password
        "Password"=""
    }
    
	Groups = New-Object System.Collections.ArrayList
}

$CSVColumnMap = @{
	#CSV Column Name = AD User property name
	Firstname="givenName"
	Surname="sn"
	"Job Title"="title"
	Manager="manager"
	Location="l"
	Telephone="telephoneNumber"
}

$status =@{
	validation= @{
		success = New-Object System.Collections.ArrayList
		fail    = New-Object System.Collections.ArrayList
	}
    activeDirectoryUser = @{
		added   = New-Object System.Collections.ArrayList
		updated = New-Object System.Collections.ArrayList
		failed  = New-Object System.Collections.ArrayList
	}
	mailbox = @{
		added   = New-Object System.Collections.ArrayList
		updated = New-Object System.Collections.ArrayList
		failed  = New-Object System.Collections.ArrayList
	}
    officeCommunicatorSettings = @{
		added   = New-Object System.Collections.ArrayList
		updated = New-Object System.Collections.ArrayList
		failed  = New-Object System.Collections.ArrayList
	}
}

function MapCSVToProperty {
	Param(
		$CSVColumnName = ""
	)
	if($CSVColumnMap.containsKey($CSVColumnName)) {
        return $CSVColumnMap[$CSVColumnName]
    }
    else {
        return $null
    }
}

function MapPropertyToCSV {
	Param(
		$ADPropertyName = ""
	)
}

function Import-ActiveDirectoryUsers {
	
	$newADUsersRawData = Get-NewUsers
	$newADUsers = Populate-ADUsers
	$validADUsers = Validate-ADUsers
}

function Validate-RequiredProperties {
	Param (
		$userToBeValidated
	)
	$status = $true
	$userToBeValidated.requiredProperties | 
	% {
		$userToBeValidated[$_] -match ""
	}
	
	return $status
}

function Populate-ADUsers {
	param (
		$ListOfADUsersRawData
	)
	$newADUsers = New-Object System.Collections.ArrayList
	
    $ListOfADUsersRawData |
    % {

        $user = $DomainUser.clone()
        $user.cn = "$($_.Firstname) $($_.Surname)"
        $user.displayName = "$($_.Firstname) $($_.Surname)"
        $user.givenName = "$($_.Firstname)"
        $user.sn = "$($_.Surname)"
        $user.sAMAccountName = "$($_.Firstname).$($_.Surname)"
        $user.mail = "$($user.sAMAccountName)@ninemsn.com.au"
        $user.title = "$($_.'Job Title')"
        $user.description = "$($_.'Job Title')"
        $user.l="$($_.'Location')"

        $manager = (Get-QADUser -Name $_.Manager)
        if($manager) {
            $user.Manager = $manager.DN
        } else {
            Write-Error "User named: $($_.Manager) was not found"
        }

        $listOfGroups = @($_.Groups -split "[\s]*,[\s]*")
        $listOfGroups | 
        #Filter out empty group names
        ? {$_ -notmatch '^$'} | 
        #or whitespace only groupnames
        ? {$_ -notmatch "^\s$"} |
        % {
            Write-Host "Searching for `'$_`'"
            $group = (Get-QADGroup -Name $_)
            if($group) {
                $user.groups.add($group.DN) | out-null
            } else {
                Write-Error "Group named: $($_) was not found"
            }
        }

        $user.Password = New-Password
        if($_.'Add Groups From User') {
            $user.groups += (Get-ADGroupsFromUser $_.'Add Groups From User')
        }

        #UPN
        $user.userPrincipalName = "$($_.Firstname).$($_.Surname)@$((Get-ADCurrentDomain).Name)"

        #OCS
        $user.telephoneNumber = "$($_.'Telephone')"
        $user.'msRTCSIP-PrimaryUserAddress'="sip:$($_.Firstname).$($_.Surname)@ninemsn.com.au"
        $user.'msRTCSIP-Line'="tel:$($_.'Telephone')"
        $OCSPolicy = Get-OCSPolicyFromLocation $user.l
        $OCSProfile = Get-OCSLocationProfileFromLocation $user.l
        $user.'msRTCSIP-UserPolicy' = $OCSPolicy
        $user.'msRTCSIP-UserLocationProfile' = $OCSProfile


        #output user values
        Write-Host "Created pending user with the following properties:"
        $user | Write-Output | format-table 
		
		$newADUsers.add($user)
    }
	
	return $newADUsers
}

	
	
function FlightCheck {
	#Check for Quest AD Snapin
	if ( (get-PSSnapIn -reg | ? {$_.Name -match "Quest.ActiveRoles.ADManagement"}) -and `
         (-not (get-PSSnapIn      | ? {$_.Name -match "Quest.ActiveRoles.ADManagement"})) 
		) {
		Add-PSSnapin "Quest.ActiveRoles.ADManagement"
	} else {
		#Snapin not found; take user to download page and die.
		$ie = New-Object -ComObject internetexplorer.application
		$ie.navigate("http://www.quest.com/powershell/activeroles-server.aspx")
		$ie.Visible = $true
		exit
	}
	
}	
	
function New-Password {
    return "Welcome@9msn"
}	

function Get-OCSPolicyForUser {
}
function Get-OCSLocationProfileForUser {

}
#ninemsn specific
function Get-OCSPolicyFromLocation {
    Param (
    $Location
    )

    Switch($Location) {
        Sydney    { return "B:8:02000000:CN={70E7CF23-7409-41DE-BBD6-FE832DFFF480},CN=Policies,CN=RTC Service,CN=Microsoft,CN=System,DC=9msn,DC=net" }
        Melbourne { return "B:8:02000000:CN={63FBB353-BFD9-4B13-960F-712219EA17AE},CN=Policies,CN=RTC Service,CN=Microsoft,CN=System,DC=9msn,DC=net" }
        default   { return "NULL" }
    }
}
#ninemsn specific
function Get-OCSLocationProfileFromLocation {
    Param (
    $Location
    )
    Switch($Location) {
        Sydney    { return "CN={64B3ED72-05BB-4FC3-A16B-7361A2AF0BC7},CN=Location Profiles,CN=RTC Service,CN=Microsoft,CN=System,DC=9msn,DC=net"}
        Melbourne { return "CN={E3CA86D6-4C9B-4DC0-9075-D9C007777DF9},CN=Location Profiles,CN=RTC Service,CN=Microsoft,CN=System,DC=9msn,DC=net"}
        default   { return "NULL" }
    }
}
#ninemsn specific
function Get-OUBasedOnLocation {
    Param(
        [Parameter(Position = 0)] 
        $Location
    )
	
	switch($Location) {
		"Sydney" 		{ return "OU=Users,OU=Sydney,OU=Clients,OU=Windows 7,DC=9msn,DC=net"}
		"Melbourne" 	{ return "OU=Users,OU=Melbourne,OU=Clients,OU=Windows 7,DC=9msn,DC=net"} 
		"New Zealand" 	{ return "OU=Users,OU=New Zealand,OU=Clients,OU=Windows 7,DC=9msn,DC=net" }
		default 		{ return "OU=Users,OU=Sydney,OU=Clients,OU=Windows 7,DC=9msn,DC=net"}
	}
}

function Get-MBXForUser {

}
#ninemsn specific
function Get-MBXfromUsername {
    param (
        $name
    )

	switch -regex ( $name ) {
		"[a-k]" { return "MBX1" }
		"[l-z]" { return "MBX2" }
		default  { return "NULL" }
	}
}

function Get-NewUsersRawData {
    $newUsersCSV = ".\newUsers.csv"

    if (-not (Test-Path $newUsersCSV)) {
        throw "$newUsersCSV not found."
    }

    $newUsers = Import-Csv $newUsersCSV
    return $newUsers
}