# visualsvn-permission-mapping
Powershell script to migrate permissions in SVN access rules in Visual SVN

## Scenario

You have a source Active Directory domain and a target Active Directory domain.
You are running Subversion on a Windows server using VisualSVN.

The objective is to map all permissions in your repository from the source
domain to the respective user/group in the target domain.

## Prerequisites

### Migrate the server to the new domain

Your VisualSVN server has been migrated to the target domain already i.e. using
the Quest migration tool. The script should also work if you did no migration
but just a domain join in the new domain.

### Prepare source and target users
During the migration, you made sure to be able to map ADObjects properly between
domains i.e. by writing the source/target samaccountnames in extensionattributes
at the objects.

### Get a mapping file ready
You then created a csv file with this mapping. Ingredients we need for a proper
mapping are:

> :bulb: **Hint**: If you want to use different column names, you have to update
> the script accordingly!

```csv
"samaccountname","objectsid","extensionattribute1"
"user1old","S-1-5-...","user1new"
"user2old","S-1-5-...","user2new"
"group1old","S-1-5-...","group1new"
...
```

To learn more on SIDs check [https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-identifiers]

I created my mapping file with the following command on a server in the source
domain with RSAT tools for AD installed:

```powershell
Get-ADObject -Filter { extensionattribute1 -like '*' } -Properties samaccountname,extensionattribute1,objectsid | select samaccountname,objectsid,extensionattribute1| Export-Csv -Path .\dump.csv -NoClobber -NoTypeInformation
```

This will get all ADObjects (users and groups) where my extensionattribute is
set (so I am skipping data I do not need or want) putting it in a csv file I
can use as a map to match permissions.

### Check Powershell modules are available

The script uses VisualSVNs powershell modules, make sure you have them
available i.e. by running:

```powershell
Get-SvnServerConfiguration

ServerName                                : vsvn.contoso.com
RepositoriesRoot                          : C:\USERS\VISUAL_SVN_AGENT\REPOSITORIES\
RepositoriesURLPrefix                     : /svn
ListenPort                                : 9191
...
Server\Backup
```

You also need the Active Directory module to query the new AD. You can install
the module running:

```powershell
Add-WindowsCapability -online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

In an elevated powershell window on the VisualSVN server.

You can check if they are there, i.e. by running:

```powershell
 (Get-ADDomain).NetBIOSNAME
```

And you should get your target domain name back.

## Run the script

If you have your map file at hand, you can run the script (from an elevated
prompt) like this:

```powershell
.\Map-VisualSVNPermissions.ps1 -Map .\dump.csv -LogFile  "$(Get-Date -Format "yyyyMMddHHmmss")-$($env:USERNAME)-map-permissions.log"
```