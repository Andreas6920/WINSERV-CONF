CLS
## PART 2 - AD ROLLE OPS�TNING
Write-host "PART 1.1 - PC NAME`t`t`t`t[COMPLETE]" -f DarkYellow; Sleep -s 1
Write-host "PART 1.2 - IP CONFIGURATION`t`t[COMPLETE]" -f DarkYellow; Sleep -s 1
Write-host "PART 2.1 - AD Install" -f Yellow

    ###################################################################
    ########  Rolle installation
    #####

    Write-host "`tPART 2.1 - AD Install"
    Do {
            Write-Host "`t`tWould you like to deploy a active directory? (y/n)" -nonewline -f green;
            $answer = Read-Host " " 
            Switch ($answer) { 
                Y { #Preparing reboot before ad setup
                    start-sleep -s 3 #Waiting for new DNS to respond
                    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                    $jobpath = 'C:\ProgramData\dc-setup.ps1'
                    Invoke-WebRequest -uri "https://raw.githubusercontent.com/Andreas6920/WINSERV-CONF/main/Server-part2.ps1" -OutFile $jobpath -UseBasicParsing
                    #Setting to start after reboot
                    $name = 'dc-setup'
                    if(Get-ScheduledTask -TaskName dc-setup){
                    Unregister-ScheduledTask -TaskName dc-setup -Confirm:$false | Out-Null; Sleep -s 1;}
                    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ep bypass -file $jobpath"
                    $principal = New-ScheduledTaskPrincipal -UserId $env:username -LogonType ServiceAccount -RunLevel Highest
                    $trigger = New-ScheduledTaskTrigger -AtLogOn
                    Register-ScheduledTask -TaskName $Name  -Principal $principal -Action $action -Trigger $trigger -Force | Out-Null 
                    
                    #install AD
                    $WarningPreference = "SilentlyContinue"
                    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | out-null
                    Write-Host "`t`t`t`tPlease choose a domain name" -nonewline -f yellow;
                    $domainname = Read-Host " " 
                    Import-Module ADDSDeployment
                    Install-ADDSForest `
                    -CreateDnsDelegation:$false `
                    -DatabasePath "C:\Windows\NTDS" `
                    -DomainMode "WinThreshold" `
                    -DomainName $domainname `
                    -DomainNetbiosName ($domainname.split(".")[0]).ToUpper() `
                    -ForestMode "WinThreshold" `
                    -Confirm:$false `
                    -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText "p@ssw0rd" -Force) `
                    -InstallDns:$true `
                    -LogPath "C:\Windows\NTDS" `
                    -NoRebootOnCompletion:$false `
                    -SysvolPath "C:\Windows\SYSVOL" `
                    -Force:$true
                    $WarningPreference = "Continue"
                }              
                N {Write-Host "`t`t`tNO - This step will be skipped." -f red; $reboot = $false} 
    
            }   
    } While ($answer -notin "y", "n")   

## PART 2.2 - AD KONFIGURATION
Write-host "`tPART 2.2 - AD Konfiguration"

    ###################################################################
    ########  CSV h�ndtering
    #####

    ### STEP 2.2.1 - SOURCE CSV FILE
        
        #Download csv fil
        $csvmappe = "C:\domainusers\" 
        $csvfil = "C:\domainusers\domain_users.csv"
        mkdir "C:\domainusers\" -force | out-null
        Invoke-WebRequest -uri "https://raw.githubusercontent.com/Andreas6920/WINSERV-CONF/main/domain_users.csv" -UseBasicParsing -OutFile $csvfil
        
        #L�s csv fil
        $Users = Import-Csv -Delimiter ";" -Path $csvfil
        write-host "`t`tCSV fil er placeret i" $csvfil -f green
        write-host "`t`tRediger denne efter behov og tast enter n�r den er f�rdig" -f green
        read-host "`t`tPress ENTER to continue..."

    ###################################################################
    ########  OU OPRETTELSE
    #####
    Write-Host "`t`t`tOU OPRETTELSE:" -f Green
    foreach($user in $users)
    {
    ##Lav v�rdierne i .csv filen til variabler
    $rootou=(Get-ADDomain).DistinguishedName 
    $oupath = $user.ADOU+','+$rootou

    #### Separere landforkortelse fra angivet ousti i .csv fil:
        $ou_branch1 = $oupath.Split("{,}")[-3] #Dette er med OU tegn
        $ou_branch2 = $ou_branch1.Split("=")[-1] #Dette er gruppen sepereret

    #### Separere undermappe fra angivet ousti i .csv fil:
        $ou_user1 = $oupath.Split("{,}")[0] #Dette er med OU tegn
        $ou_user2 = $ou_user1.Split("=")[-1] #dette er gruppen sepereret

    #### Kombinere stierne
        $newOU = "$ou_branch1,$rootou" #Branch+rootou
        $newOU1 = "$ou_user1,$ou_branch1,$rootou" #Users+Branch+rootou

    if (Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$newOU'") ## Findes branch??
            {if (!(Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$newOU1'"))
                {Write-Host "`t`t`tOU: " +$ou_user2+"oprettes.." -f yellow
                New-ADOrganizationalUnit -Name $ou_user2 -Path $newOU -ProtectedFromAccidentalDeletion $False   
                Write-Host "`t`t- ... '$ou_user2' er nu oprettet!" -f Green
                }} 
    else
            {Write-Host "`t`t`tOU:"$newOU" oprettes.." -f yellow
            New-ADOrganizationalUnit -Name $ou_branch2 -Path $rootou -ProtectedFromAccidentalDeletion $False
            New-ADOrganizationalUnit -Name $ou_user2 -Path $newOU -ProtectedFromAccidentalDeletion $False}
    }
    write-host "`t`t`tOU: " -f yellow -NoNewline ;
    write-host "[COMPLETE]" -f Green
    "";
    
    ###################################################################
    ########  BRUGER OPRETTELSE
    #####

    Write-Host "`t`t`tBRUGER OPRETTELSE:" -f Green
    foreach($user in $users)
    {
    ##Lav v�rdierne i .csv filen til variabler##
    $oupath = $user.ADOU+','+(Get-ADDomain).DistinguishedName
    $firstName = $user.firstname
    $lastName = $user.Lastname
    $displayName = $user.Firstname+' '+$user.Lastname
    $company = $user.Company
    $office = $user.Branch
    $department = $user.Department 
    $jobtitle = $user.Title
    $email = $user.'e-mail account'
    $username = $user.Initials
    
    ##Tjek om brugere eksistere, f�r de oprettes##
    $Userexists = Get-ADUser -Filter {sAMAccountName -eq $Username}
    
    If ($Userexists -eq $Null)
    {New-ADUser `
    -Path $oupath `
    -Department $department `
    -Title $jobtitle `
    -Name $username.ToUpper() `
    -UserPrincipalName $email `
    -DisplayName "$displayName" `
    -GivenName "$firstname" `
    -Surname "$lastname" `
    -Office $office `
    -AccountPassword (ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force) -PassThru| Enable-ADAccount 
    Write-host `t`t`t"BRUGER: "$firstname $lastname "oprettes.." -f yellow
    }
    Else
    {write-host "`t`t`tBRUGER: $username er allerede optaget af $firstname $lastname." -f red}

    }
    write-host "`t`t`tBRUGER: " -f yellow -NoNewline ;
    write-host "[COMPLETE]" -f Green
    "";
    ###################################################################
    ########  SECURITY GROUP OPRETTELSE
    #####
    Write-Host "`t`t`tSECURITY GROUP OPRETTELSE:" -f Green

    $secfoldername = "SecurityGroups"
    $sec_root =(Get-ADDomain).DistinguishedName
    $sec_dest = "OU=$secfoldername,$sec_root"

    # create security group OU and adding department to it
	write-host "`t`t`tSECURITY GROUP: Creating OU for security groups..." -f Yellow
    if (!(get-ADOrganizationalUnit -Filter {Name -eq $secfoldername})){
        New-ADOrganizationalUnit -Name $secfoldername -Path $sec_root -ProtectedFromAccidentalDeletion $False}
    

    $afdelinger = (get-aduser -filter * -property department).department | Sort-Object -Unique
    foreach ($afdeling in $afdelinger){
    $SecGroupName = "SecGroup_"+$afdeling.Replace(" ","")
    if (!(Get-ADGroup -Filter {Name -eq $SecGroupName})){
        Write-host "`t`t`tSECURITY GROUP: $SecGroupName oprettet.." -f Yellow
    New-ADGroup -Name $SecGroupName -SamAccountName $afdeling -GroupCategory Security -GroupScope Global -DisplayName $afdeling -Path "$sec_dest"
    Write-host "`t`t`tSECURITY GROUP: Tilføjer alle fra $afdeling til $SecGroupName.." -f Yellow
    Get-ADUser -Filter 'Department -eq $afdeling' | ForEach-Object {Add-ADGroupMember -Identity $afdeling -Members $_ }
        }}
    
    if (!(Get-ADGroup -Filter {Name -eq "SecGroup_CEO"})){
    New-ADGroup -Name "SecGroup_CEO" -SamAccountName "CEO Management" -GroupCategory Security -GroupScope Global -DisplayName "CEO Management" -Path $sec_dest
    Get-ADUser -Filter 'Title -eq "CEO"' | ForEach-Object {Add-ADGroupMember -Identity "CEO Management" -Members $_ }}
    write-host "`t`t`tSECURITY GROUP: " -f yellow -NoNewline ;
    write-host "[COMPLETE]" -f Green
    "";

    ###################################################################
    ########  SMB OPRETTELSE
    #####
    Write-Host "`t`t`tSMB OPRETTELSE:" -f Green
    Do {
        Write-Host "`t`t`tWould you like to create shares for the departments? (y/n)" -nonewline -f green;
        $answer = Read-Host " " 
        Switch ($answer) { 
            Y {
    #Lav en mappe til �nskede shares
    
    $Path = "C:\"
    $Name = "user_shares"
    $SharePath = "$Path$Name\"
    
    if(!(test-path $SharePath)) {
        New-Item -ItemType Directory -Force -Path $SharePath | out-null
        Write-Host "`t`t`tSMB SHARE: $SharePath er nu oprettet." -f yellow}
        
    
    
    #Lav shares i den oprettede mappe, S�t NTFS + Share rettigheder
    
    New-Item -ItemType Directory -Force -Path $SharePath\General | out-null
    $Users = Import-Csv -Delimiter ";" -Path "C:\domainusers\domain_users.csv"
    foreach($user in $users)
    {
    #variabler efter 'department' kolonnen i csv filen.
            $dep_folders = $user.Department
            $share_department_specific = "$SharePath$dep_folders"
    
    #Lav en mappe pr. afdeling
            if(!(test-path $share_department_specific)) {
            Write-host "`t`t`tSMB SHARE: creating $share_department_specific folder" -f yellow
            New-Item -ItemType Directory -Force -Path $share_department_specific | out-null}
            
          
          #RETTIGHEDER: Shares     
            New-Smbshare -Name $dep_folders  -Description "Shared folders for $dep_folders and managers" `
            -Path $share_department_specific -ea SilentlyContinue | out-null
            Grant-SmbShareAccess -AccountName $dep_folders -Name $dep_folders -AccessRight Change -Force | out-null
            Grant-SmbShareAccess -AccountName "Management" -Name $dep_folders -AccessRight Read -Force | out-null
            Grant-SmbShareAccess -AccountName "CEO Management" -Name $dep_folders -AccessRight Change -Force | out-null
            
            
            #RETTIGHEDER: NTFS
            
            $ntfs = Get-Acl \\$env:COMPUTERNAME\$dep_folders
            $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$dep_folders","Modify","Allow")
            $AccessRule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("Management","Read","Allow")
            $AccessRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("CEO Management","Modify","Allow")
            $ntfs.SetAccessRule($AccessRule) 
            $ntfs.SetAccessRule($AccessRule1)
            $ntfs.SetAccessRule($AccessRule2)
            $ntfs | Set-Acl $share_department_specific 
            
            
        }
        
    Write-host "`t`t`tSMB SHARE: Modifying SMB access.." -f yellow
    Write-host "`t`t`tSMB SHARE: Modifying NTFS permissions.." -f yellow
    write-host "`t`t`tSMB SHARE: " -f yellow -NoNewline ;
    write-host "[COMPLETE]" -f Green
    
    }              
            N {Write-Host "`t`t`tNO - This step will be skipped." -f red; $reboot = $false} 
    
        }   
    } While ($answer -notin "y", "n")  