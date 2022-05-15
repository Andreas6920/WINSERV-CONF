AD-user

Choose option:

1 ) Proof of concept - Automatic (From CSV file)
2 ) Proof of contect - Manual Mode
3 ) IRL - Automatic mode (From CSV file)
4 ) IRL - Manual mode



function POC_auto {

# OU creation

    # Downloading random CSV file
    Write-Host "`t`t- Downloading CSV file.." -f Green 
    $csv_file = $($env:ProgramData)+"\WindowsServer-Automation\aduser.csv"
    New-Item -ItemType Directory -Path ($csv_file | Split-Path) -ErrorAction Ignore | Out-Null
    iwr -useb "https://raw.githubusercontent.com/Andreas6920/WINSERV-CONF/main/res/adusers.csv" -Out $csv_file
    $csv = Import-Csv -Delimiter ";" -Path $csv_file
    Start-Sleep -s 3

    # Create new level 2 OU's
    Write-Host "`t`t- Creating level two OU's:" -f Green 
    $toplevel_ou = (Get-ADOrganizationalUnit -Filter * -SearchScope OneLevel | select -First 1).DistinguishedName.replace('OU=Domain Controllers,','')
    "Departments","Service Accounts" | % {if(!(Get-ADOrganizationalUnit -Filter "Name -eq '$_'")){ Write-Host "`t`t`t- Creating OU: $_" -f Yellow; New-ADOrganizationalUnit -Name  $_ -Path $toplevel_ou}}
    Start-Sleep -s 3

    # Create department OU's 
    Write-Host "`t`t- Scanner CSV file for other OU's:" -f Green; Sleep -s 2
    $csv_departments = $csv.Department | Sort | Get-Unique
    $csv_departments | % {if(!(Get-ADOrganizationalUnit -Filter "Name -eq '$_'")){ Write-Host "`t`t`t- Creating OU: $_" -f Yellow;New-ADOrganizationalUnit -Name  $_ -Path "OU=Departments,$toplevel_ou"}}
    Start-Sleep -s 3

# User creation

    Write-host "`t- Opretter Brugere.." -f green 
    # enter mail domainname "facebook.com", "lego.dk" etc.
    write-host "Enter your mail domain (example: @facebook.com):"
    $answer = Read-host " "
    $company = $answer.split(".")[0].Split("@")[1]
    $number = 1

    foreach($user in $csv)
    {
    #brugernavn
    $fornavn = $user.firstname
    $efternavn = $user.lastname
    $part1 = $fornavn.Substring(0,3).toUpper().replace("Æ","A").replace("Ø","O").replace("Å","A")+$efternavn.Substring(0,3).toUpper().replace("Æ","A").replace("Ø","O").replace("Å","A")
    #ou build
    $username = $Part1+"0"+$number
    $afdeling = $user.Department
    $ou = "OU="+$afdeling+",OU=Departments,OU=Users,OU=HEV,DC=HEV,DC=RM,DC=LOCAL"
    $title = $user.Title

    $eksisterende_bruger = Get-ADUser -Filter {sAMAccountName -eq $Username}
    If ($eksisterende_bruger -eq $Null)
    {Write-host "`t`t`t- Opretter"$fornavn" "$efternavn" til $afdeling afdelingen" -f green
    New-ADUser -Path $ou -Department $afdeling -Title $title -Name $username -UserPrincipalName $username$maildomain -DisplayName $username `
    -GivenName $fornavn -Surname $efternavn -Company $company -Office $office -AccountPassword (ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force) -PassThru| Enable-ADAccount}
    Else{
    Write-host "`t`t`t- $username findes allerede!" -f yellow
    $count=((Get-ADUser -Filter *).sAMAccountName -cMatch "$part1*").Count+1
    if($count -le 9){$username = $Part1+"0"+$count}
    else{$username = $Part1+$count}
    New-ADUser -Path $ou -Department $afdeling -Title $title -Name $username -UserPrincipalName $username$maildomain -DisplayName $username `
    -GivenName $fornavn -Surname $efternavn -Company $company -Office $office -AccountPassword (ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force) -PassThru| Enable-ADAccount}
    Write-host "`t`t`t`t- Bruger navngivet $username istedet!" -f green }

}