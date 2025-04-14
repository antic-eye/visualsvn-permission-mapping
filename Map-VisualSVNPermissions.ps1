#Requires -Modules ActiveDirectory, VisualSVN
<#
 .SYNOPSIS
 Map Active Directory permissions in VisualSVN repositories between different
 domains

 .DESCRIPTION
 This script helps you to map users and groups after a server has been moved to
 a different active directory environment.

 .PARAMETER Map
 Set this to a csv file containing the columns:
 "samaccountname","objectsid","extensionattribute1"
 The map file is used to creaste a relation between samaccountname in the
 source domain and samaccountname in the targetdomain which is stored as
 extentionattribute1 in the source domain object

 .PARAMETER LogFile
 Path to the log file to write to.

 .EXAMPLE
 .\Map-VisualSVNPermissions.ps1 -Map .\dump.csv.txt -LogFile svn-perm-mapping.log -WhatIf

 .LINK
 https://github.com/antic-eye/visualsvn-permission-mapping
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    $LogFile,
    $Map,
    $TARGETDOMAIN
)

enum LogLevel{
    DBG
    INF
    WAR
    ERR
    EXC
    OK
    NOK
}

Function Main{
    If($LogFile){ Start-Transcript -Path $LogFile }
    
    $sids = Import-Csv -Path $Map
    $rules = $(Get-SvnAccessRule)
    $iAll = $rules.Length
    $iCurrentRule = 0
    $iPercentage = 0
    
    foreach($repo in $rules){
        $rules = Get-SvnAccessRule -Repository $repo.Repository
        $iCurrentRule++
        $iPercentage = ($iCurrentRule / $iAll) * 100 
        Write-Progress -Activity "Migrating permissions" -PercentComplete $iPercentage -CurrentOperation "Working on $($repo.Repository)$($repository.Path)"

        foreach($rule in $rules){
            foreach($sid in $sids){
                if($sid -and (($sid.objectsId.TolowerInvariant() -eq $rule.AccountId.TolowerInvariant()))){ 
                    Log-Debug "`t$($sid.objectsId) matches $($rule.AccountId)"
                    $newsid = Get-ADObject -Filter { name -like "$($sid.extensionattribute1)" }
                    Log-Debug "`tMap $($sid.extensionattribute1) ($($newsid.ObjectGUID)) to $($rule.AccountId)"
                    try{
                        Add-SVNAccessRule -Repository $rule.Repository -Path $rule.Path -AccountName "$TARGETDOMAIN\$($sid.extensionattribute1)" -Access $rule.Access -AuthorizationProfile $rule.AuthorizationProfile -ErrorAction Stop -WhatIf:$WhatIfPreference
                        Log-OK "`tAdded new access rule for ""$TARGETDOMAIN\$($sid.extensionattribute1)"" ($($rule.Access), AuthProfile: $($rule.AuthorizationProfile)) on ""$($rule.Repository)$($rule.Path)"""
                    } catch{
                        Log-Warning "`t Error, rule was not added: $($_.Exception.Message)"
                    }
                }else{
                    Log-Debug "$($rule.AccountId) - $($rule.AccoutName) was not found in the mapping!"
                }
            }
        }
    }
    If($LogFile){ Stop-Transcript }
}

Function Log {
    param(
        [LogLevel]$Level,
        [string]$Message
    )
    If($Level -eq [Loglevel]::DBG -and($DebugPreference -eq "SilentlyContinue")){
        return
    }

    Write-Host "$(Get-date -format 'yyyy-MM-dd hh:mm:ss UTCz') [ " -NoNewline
    switch ($Level) {
        ([LogLevel]::WAR) {
            Write-Host "WAR"  -ForegroundColor Yellow -NoNewline
            break
        }
        ([LogLevel]::ERR) {
            Write-Host "ERR"  -ForegroundColor Red -NoNewline
            break
        }
        ([LogLevel]::DBG) {
            Write-Host "DBG"  -ForegroundColor Blue -NoNewline
            break
        }
        ([LogLevel]::EXC) {
            Write-Host "EXC"  -ForegroundColor DarkRed -NoNewline
            break
        }
        ([LogLevel]::OK) {
            Write-Host " OK"  -ForegroundColor Green -NoNewline
            break
        }
        ([LogLevel]::NOK) {
            Write-Host "NOK"  -ForegroundColor Red -NoNewline
            break
        }       
        Default {
            Write-Host "$($Level)"  -ForegroundColor Gray -NoNewline
        }
    }
    Write-Host " ] $Message"
}
Function Log-Ok($Message) {
    Log -Level OK -Message $Message
}
Function Log-Info($Message) {
    Log -Level INF -Message $Message
}
Function Log-Debug($Message) {
    Log -Level DBG -Message $Message
}
Function Log-Warning($Message) {
    Log -Level WAR -Message $Message
}
Function Log-Error($Message) {
    Log -Level ERR -Message $Message
}
Function Log-NOk($Message) {
    Log -Level NOK -Message $Message
}
Function Log-Exception($Message) {
    Log -Level EXC -Message $Message
}
Main
