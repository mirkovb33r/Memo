    function Get-StuckProfile{
<#
.SYNOPSIS
.DESCRIPTION
.PARAMETER 
.INPUTS
.OUTPUTS
.EtsMPLE
#>

    [CmdletBinding()]

    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter user's username.")]
        [alias("Username")]
        [string]$SamAccountName,

        [Parameter(Mandatory=$True,ParameterSetName="ComputerName",HelpMessage="Enter computer name(s)")]
        [Alias("Hostname")]
        [string[]]$ComputerName,

        [Parameter(Mandatory=$True,ParameterSetName="TerminalServers")]
        [switch]$TerminalServers
    )

    Begin{
        If($PSCmdlet.ParameterSetName -eq "TerminalServers"){
            $ComputerName = "ts01","ts02","ts03","ts04","ts05","ts06","ts07",
                            "ts08","ts09","ts10","ts11","ts12","ts13","ts14",
                            "ts15","ts16","ts17","ts18","ts19","ts20","ts21",
                            "ts22"
        }

        $ScriptUser = get-content env:username

        If($SamAccountName -eq $ScriptUser){
            Write-Warning "Cannot run command with specified user account at this time."; Return
        }
    }

    Process{
        Try{
            $SID = get-aduser $SamAccountName -ErrorAction Stop | Select -ExpandProperty SID | Select -ExpandProperty Value

            If($SID -eq $null){
                Write-Warning "User SID not obtained from Active Directory."; Return
            }
        }
        Catch{
            Write-Warning "User not found in Active Directry. Please check spelling and try again."; Return
        }

        $AllProfileInfo = invoke-command -ComputerName $ComputerName -ErrorAction SilentlyContinue -ErrorVariable ProfileError -ArgumentList $SamAccountName, $SID -ScriptBlock{
            Param($SamAccountName, $SID)

            $FolderTest = Test-Path -Path "c:\users\$SamAccountName*"

            $ProfileListRegistryTest = Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID*"

            If((Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileGUID" | Get-ItemProperty | where { $_.SidString -like "*$SID*" }) -ne $null){
                $ProfileGUIDTest = $True
            }
            Else{$ProfileGUIDTest = $False}

            If((Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PolicyGUID" | Get-ItemProperty | where { $_.SidString -like "*$SID*" }) -ne $null){
                $PolicyGUIDTest = $True
            }
            Else{$PolicyGUIDTest = $False}


            $Properties =@{
                "Stuck Profile Folders"=$FolderTest
                "Stuck ProfileList Registry Keys"=$ProfileListRegistryTest
                "Stuck ProfileGUID Registry Keys"=$ProfileGUIDTest
                "Stuck PolicyGUID Registry Keys"=$PolicyGUIDTest
            }

            $ProfileInfo = New-Object -TypeName PSObject -Property $Properties

            $ProfileInfo | where {($_."Stuck Profile Folders" -eq $True) -or ($_."Stuck ProfileList Registry Keys" -eq $True) -or ($_."Stuck ProfileGUID Registry Keys" -eq $True) -or ($_."Stuck PolicyGUID Registry Keys" -eq $True)}
        } 
    }

    End{
        If($AllProfileInfo -eq $null){
            Write-Host "No stuck profiles found for user."
        }
        Else{
            $AllProfileInfo | Select -Property PSComputerName, "Stuck Profile Folders", "Stuck ProfileList Registry Keys","Stuck ProfileGUID Registry Keys","Stuck PolicyGUID Registry Keys" | Sort-Object -Property PSComputerName
        }

        $ProfileError | %{Write-Warning "Cannot connect to $($_.TargetObject)"}
    } 
}

function Remove-StuckProfile{
<#
.SYNOPSIS
.DESCRIPTION
.PARAMETER 
.INPUTS
.OUTPUTS
.EtsMPLE
#>

    [CmdletBinding()]

    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter user's username.")]
        [alias("Username")]
        [string]$SamAccountName,

        [Parameter(Mandatory=$True,ParameterSetName="ComputerName",HelpMessage="Enter computer name(s)")]
        [Alias("Hostname")]
        [string[]]$ComputerName,

        [Parameter(Mandatory=$True,ParameterSetName="TerminalServers")]
        [switch]$TerminalServers
    )

    Begin{
        If($PSCmdlet.ParameterSetName -eq "TerminalServers"){
            $ComputerName = "ts01","ts02","ts03","ts04","ts05","ts06","ts07",
                            "ts08","ts09","ts10","ts11","ts12","ts13","ts14",
                            "ts15","ts16","ts17","ts18","ts19","ts20","ts21",
                            "ts22"
        }

        $ScriptUser = get-content env:username

        If($SamAccountName -eq $ScriptUser){
            Write-Warning "Cannot run command with specified user account."; Return
        }
    }

    Process{
        Try{
            $SID = get-aduser $SamAccountName -ErrorAction Stop | Select -ExpandProperty SID | Select -ExpandProperty Value

            If($SID -eq $null){
                Write-Warning "User SID not obtained from Active Directory."; Return
            }
        }
        Catch{
            Write-Warning "User not found in Active Directry. Please check spelling and try again."; Return
        }

        $AllProfileInfo = invoke-command -ComputerName $ComputerName -ErrorAction SilentlyContinue -ErrorVariable ProfileError -ArgumentList $SamAccountName, $SID -ScriptBlock{
            Param($SamAccountName, $SID)

            $Properties = @{
                "User Folders Removed"="N/A"
                "ProfileList Registry Keys Removed"="N/A"
                "ProfileGUID Registry Keys Removed"="N/A"
                "PolicyGUID Registry Keys Removed"="N/A"
            }

            $FolderTest = Test-Path -Path "c:\users\$SamAccountName*"

            $RegistryTest = Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID*"

            If($FolderTest){
                $Userfolders = get-childitem -Path c:\users | where {$_.Fullname -like "c:\users\$SamAccountName*"} | Select -ExpandProperty Fullname

                Foreach($Userfolder in $Userfolders){
                    cmd /c "rmdir $Userfolder /s /q"
                }

                $FolderTest2 = -not (Test-Path -Path "c:\users\$SamAccountName*")

                $Properties.Item("User Folders Removed")="$FolderTest2"
            }

            If($RegistryTest){
                Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID*" -Recurse -Force

                $RegistryTest2 = -not (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID*")

                $Properties.Item("ProfileList Registry Keys Removed")="$RegistryTest2"
            }

            If((Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileGUID" | Get-ItemProperty | where { $_.SidString -like "*$SID*" }) -ne $null){
                $Properties.Item("ProfileGUID Registry Keys Removed")="$False"

                Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileGUID" | Get-ItemProperty | where { $_.SidString -like "*$SID*" } |

                Remove-Item -Force -Recurse -Confirm:$false

                If((Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileGUID" | Get-ItemProperty | where { $_.SidString -like "*$SID*" }) -eq $null){
                    $Properties.Item("ProfileGUID Registry Keys Removed")="$True"
                }
            }

            If((Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PolicyGUID" | Get-ItemProperty | where { $_.SidString -like "*$SID*" }) -ne $null){
                $Properties.Item("PolicyGUID Registry Keys Removed")="$False"

                Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PolicyGUID" | Get-ItemProperty | where { $_.SidString -like "*$SID*" } |

                Remove-Item -Force -Recurse -Confirm:$false

                If((Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PolicyGUID" | Get-ItemProperty | where { $_.SidString -like "*$SID*" }) -eq $null){
                    $Properties.Item("PolicyGUID Registry Keys Removed")="$True"
                }
            }

            $ProfileInfo = New-Object -TypeName PSObject -Property $Properties

            $ProfileInfo | where {($_."User Folders Removed" -ne "N/A") -or ($_."ProfileList Registry Keys Removed" -ne "N/A")  -or ($_."ProfileGUID Registry Keys Removed" -ne "N/A")  -or ($_."PolicyGUID Registry Keys Removed" -ne "N/A")}      
        }
    }

    End{
        $AllProfileInfo | Select -Property PSComputerName, "User Folders Removed", "ProfileList Registry Keys Removed", "ProfileGUID Registry Keys Removed", "PolicyGUID Registry Keys Removed" | Sort-Object -Property PSComputerName

        $ProfileError | %{Write-Warning "Cannot connect to $($_.TargetObject)"}
    }
}
