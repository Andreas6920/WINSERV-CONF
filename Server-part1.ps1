CLS
## PART 1 - OPSÆTNING

    ## PART 1.1 - COMPUTERNAME
    CLS
    "";
    Write-host "PART 1.1 - PC NAME"
    Do {
            Write-Host "`tCurrent PC Name:" -f yellow -nonewline; Write-Host " $env:computername"
            Write-Host "`tWould you like to rename this PC? (y/n)" -nonewline -f green;
            $answer = Read-Host " " 
            Switch ($answer) { 
                Y {
                    
                    Write-Host "`t`tNew PC name" -f yellow -nonewline;
                    $PCname = Read-Host " "
                    $WarningPreference = "SilentlyContinue"
                    Rename-computer -newname $PCname
                    $WarningPreference = "Continue"
                    $reboot = $true
                    Write-Host "`t`tComputer description" -f yellow -NoNewline
                    $Description = Read-Host " " 
                    $ThisPCDescription=Get-WmiObject -class Win32_OperatingSystem
                    $ThisPCDescription.Description=$Description
                    $ThisPCDescription.put() | out-null
                    Write-Host "`t`tComputer renamed. PC will reboot after IP configuration." -f yellow
                    "";

                }
                N {Write-Host "`t`tNO - This PC will not be renamed." -f red -nonewline; $reboot = $false} 
            }   
        } While ($answer -notin "y", "n")    
    ## PART 1.2 - IP CONFIGURATION
    "";
    Write-host "PART 1.2 - IP CONFIGURATION"
    Do {
    Write-Host "`tWould you like to change your IP? (y/n)" -nonewline -f green;
    $answer = Read-Host " " 
    Switch ($answer) { 
        Y {
        ### Choice Network Adapter
        
        Do {
            Write-Host "`t`tCHOOSE NETWORK ADAPTER:" -f yellow; sleep -s 2;
            "";Write-Host "`t`t`t Your Network Adapters:" -f yellow
            $nic = Get-NetIPAddress -AddressFamily IPv4
            foreach ($n in $nic){write-host "`t`t`t" $n.InterfaceAlias "( IP:" $n.IPAddress")"}"";
            sleep -s 2
            Write-Host "`t`t`t Please enter the NAME of the primary network card" -nonewline -f yellow;
            $ethernetadaptername = Read-Host " " 
            } While ($ethernetadaptername -notin ((Get-NetIPAddress -AddressFamily IPv4).InterfaceAlias)) 



        ### Get adapter settings
        "";
        Write-Host "`t`tSET IP CONFIGURATION:" -f yellow; 
        $currentip = netsh interface ip show addresses $ethernetadaptername | select-string "IP Address"
        $currentsubnet = "/"+(Get-NetIPAddress -InterfaceAlias $ethernetadaptername -AddressFamily IPv4).PrefixLength
        $currentgateway = netsh interface ip show addresses $ethernetadaptername | select-string "Default gateway"
        $currentDNS = (Get-DnsClientServerAddress -InterfaceAlias Ethernet0).ServerAddresses
        "";
        Write-Host "`t`t`t Current IP Settings:" -f yellow
        Write-Host "`t`t`t Adapter:`t`t`t`t`t`t`t  "$ethernetadaptername
        Write-Host "`t`t`t"$currentip
        Write-Host "`t`t`t Subnet:`t`t`t`t`t`t`t  "$currentsubnet
        Write-Host "`t`t`t"$currentgateway[0];"";
        

        ### Enter New adapter settings
        Do {Write-Host "`t`t`t Enter new IP Address" -f yellow -NoNewline
        $newIP = Read-Host " " } While ($newIP -notmatch "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")
        Do {Write-Host "`t`t`t Enter new SUBNET VALUE (example: 24, 16, 8)" -f yellow -NoNewline
        $newSubnet = Read-Host " "} While ($newSubnet -notin 8..30)
        Do {Write-Host "`t`t`t Enter new gateway IP:" -f yellow -NoNewline
        $newGW = Read-Host " "} While ($newGW -notmatch "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")
        Do {Write-Host "`t`t`t Enter new DNS IP:" -f yellow -NoNewline
        $newDNS = Read-Host " "} While ($newDNS -notmatch "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")

        ### Configure new settings
        "";
        Write-Host "`t`tNEW CONFIGURATION IS BEING SET:" -f yellow;
        Write-Host "`t`t`t - Clearing current settings.." -f yellow;
        Set-ItemProperty -Path “HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\$((Get-NetAdapter -InterfaceAlias $ethernetadaptername).InterfaceGuid)” -Name EnableDHCP -Value 0 -ea SilentlyContinue
        Remove-NetIpAddress -InterfaceAlias $ethernetadaptername -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $ethernetadaptername -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        sleep -s 2

        Write-Host "`t`t`t - Setting new IP..." -f yellow; Sleep -s 1
        Write-Host "`t`t`t - Setting new Subnet..." -f yellow; Sleep -s 1
        Write-Host "`t`t`t - Setting new Gateway..." -f yellow; Sleep -s 1
        New-NetIpAddress -InterfaceAlias $ethernetadaptername -IpAddress $newIP -PrefixLength $newSubnet -DefaultGateway $newGW -AddressFamily IPv4 | out-null
        Write-Host "`t`t`t - Setting new DNS..." -f yellow; Sleep -s 1
        Set-DnsClientServerAddress -InterfaceAlias $ethernetadaptername -ServerAddresses $newDNS | out-null
        Write-Host "`t`tIP settings complete!" -f yellow; Sleep -s 1
        }
        N{Write-Host "`t`tNo, this step will be skipped." -f red; sleep -s 2;}
    } }While ($answer -notin "y", "n")
    
    if ($reboot -eq $true){
    Write-Host "`t`tComputer is renamed, rebooting in 5 seconds.." -f yellow; sleep -s 5;
    Restart-Computer -Force }