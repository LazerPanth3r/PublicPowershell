<#
.SYNOPSIS
Author: Zscaler Support
Heavily modified by: Michael Becker (mbecker@mpmaterials.com)
https://github.com/MrV8Rumble

.DESCRIPTION
This script will prepare an new Zscaler NSS host in Azure

.EXAMPLE
.\deploy_nss.ps1 .\conf_file.txt

Example conf_file.txt:

name=znss01
location=southcentralus
rgname=ZScalerNSS
storename=<unique name zscalernssstorage>
vnetrg=<your vnet resource group>
vnetname=Vnet1
prisubnetname=AzureServers
prinetprefix=10.x.x.0/24
mgmtsubnetname=AzureManagementVlan
mgmtsubnetprefix=10.x.x.0/24
niccount=2vmsize=Standard_D2_v4dst
StorageURI=https://<unique name zscalernssstorage>.blob.core.windows.netdst
Container=virtual-hard-disks
srcOsURI=https://<unique name zscalernssstorage>.blob.core.windows.net/templates/znss_5_0_osdisk.vhd

#######
The field they show for "createstorage" andd "create rg (resource group)" are not actually in use in the script.

.NOTES
These modules are required:
    Install-Module -Name Az.Storage -Force -Scope AllUsers -AllowClobber
    Install-Module -Name Az.Compute -Force -Scope AllUsers -AllowClobber
    Install-Module -Name Az.Network -Force -Scope AllUsers -AllowClobber
    Install-Module -Name Az.Resources -Force -Scope AllUsers -AllowClobber

Source and destination URI for the OS vhd must be within the same storage account or storage context failure will occur.

#>

# MP Logo and script title 
(Write-Host "New ZScaler NSS Deployment"  -ForegroundColor "Blue" -BackgroundColor "White")



#Test if the azure powershell modules are present on the system
$scmd="Connect-AzAccount"
$cmdout=Get-Command $scmd -eA SilentlyContinue -EV $serr -OV $sout
if(!$cmdout.CommandType) {
    Write-Output "Required powershell modules are missing. Please install the azure modules and retry"
	exit
}

if (Get-Module -ListAvailable -Name Az.Resources) {} 
else {
	Write-Output "Please Install Module Az.Resources"
    exit
}
if (Get-Module -ListAvailable -Name Az.Compute) {} 
else {
    Write-Output "Please Install Module Az.Compute"
    exit
}
if (Get-Module -ListAvailable -Name Az.Storage) {} 
else {
    Write-Output "Please Install Module Az.Storage"
    exit
}
if (Get-Module -ListAvailable -Name Az.Network) {} 
else {
    Write-Output "Please Install Module Az.Network"
    exit
}

#Sign in for this session
Connect-AzAccount

#Fetch the config file to be loaded
if( $null -ne $args[0] ){
	$filename=$args[0]
	}
else
	{
		$filename="./conf_file.txt"
	}

$SubSelect = 'n'
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
Do {
	$subs=Get-AzSubscription

	Write-Output "Listing available subscriptions in your account"
	$subid=0
	$ProvisionSub=99999
	foreach ($sub in $subs) {
		Write-Output "Subscription $subid :"
		Write-Output $sub
		$subid++
	}

	if($subid -ge 1)
	{
    	$ProvisionSub=Read-Host -Prompt "Select one of the above for provisioning"
	}
	else
	{
    	$ProvisionSub=0
	}

	Write-Output "Selected subscription for provisioning :"
	Write-Output $subs[$ProvisionSub]
	$SubSelect=Read-Host -Prompt "Enter `"y`" to continue with this subscription or `"n`" to choose again"
} While($SubSelect -eq 'n' -or $SubSelect -eq 'N')

if($SubSelect -ne 'y' -and $SubSelect -ne 'Y') {
	Write-Output "You did not choose a subscription to deploy in, script will exit now"
	exit
}

$subscription=$subs[$ProvisionSub]
Write-Output "Script will continue to provision in the selected subscription $subscription "
Set-AzContext -SubscriptionId $subscription.Id
Write-Output "Azure Subscription for current session set to the following"
Get-AzContext
$select=Read-Host -Prompt "Do you wish to continue(y/n):"
if($select -ne 'y' -or $select -ne 'Y')	
{
	Write-Output "Script terminating per user input"
	exit
}
Write-Output "Provisioning will continue with the selected subscription"

if ( -not (Test-Path $filename))
{
		Write-Output "Config file not found at $filename"
		exit
}
else
    {
        Write-Output "Found the configuration file, populating deployment variables from $filename"
    }

#Sanity run, set this to n when running actual creation
$sanityrun='n'

#Initialize config entries from the configuration file provided
$name=''
$rgname=''
$niccount=1
$storename=''
$prisubnetname=''
$mgmtsubnetname=''
$svcsubnetname=''
$vnetname=''
$prinetprefix=''
$mgmtsnetprefix=''
$svcsubnetprefix=''
$vmsize=''
$location=''
$osimage=''
$dstStorageURI=''
$dstContainer=''
$vnetrgname=''
$avsetname=''
$avcheck="No"


#Parse the config file provided and load the values

foreach ($line in Get-Content $filename) {
    if($line -match "^#.*") {
        #Commented
        continue
    }
    if( [string]::IsNullOrWhitespace($line)) {
        #Empty line
        continue
    }
	$entries=$line.split("=",2,[StringSplitOptions]'RemoveEmptyEntries')
	#$entries=$line.split("=")
	$e1=$entries[0]
	$e2=$entries[1]
    Write-Host $e1 $e2 -Separator ","
	$key=$e1.Trim()
	$value=$e2.Trim()
	#Write-Output "Got entries" $entries[0] "->" $entries[1]
	if($key -eq "name") {
		$name=$value
		continue
		}
    if($key -eq "avset") {
		$avsetname=$value
		continue
		}
	if($key -eq "rgname") {
		$rgname=$value
		continue
		}
	if($key -eq "vnetrg") {
		$vnetrgname=$value
		continue
		}
	if($key -eq "storename") {
		$storename=$value
		continue
		}
    if($key -eq "prisubnetname"){
        $prisubnetname=$value
        continue
        }
	if($key -eq "mgmtsubnetname") {
		$mgmtsubnetname=$value
		continue
		}
    if($key -eq "svcsubnetname") {
        $svcsubnetname=$value
        continue
        }
	if($key -eq "vnetname") {
			$vnetname=$value
			continue
		}		
	if($key -eq "niccount") {
		$niccount=$value
		continue
		}
	if($key -eq "prinetprefix") {
		$prinetprefix=$value
		continue
		}
	if($key -eq "mgmtsubnetprefix") {
		$mgmtsnetprefix=$value
		continue
		}
    if($key -eq "svcsubnetprefix") {
        $svcsubnetprefix=$value
        continue
        }
	if($key -eq "vmsize") {
		$vmsize=$value
		continue
		}
	if($key -eq "location") {
		$location=$value
		continue
		}
	if($key -eq "dstStorageURI") {
		$dstStorageURI=$value
		continue
		}
	if($key -eq "srcOsURI") {
		$osimage=$value
		continue
		}    
     if($key -eq "dstContainer") {
        $dstContainer=$value
        continue
        }
	
}

Write-Output "Name=$name Rgname=$rgname Location=$location"
if($vnetrgname -eq '')
{
	$vnetrgname=$rgname
}

$loclist=Get-AzLocation
$loccheck=0

foreach($loc in $loclist.Location){
	if($loc -like $location){
		$loccheck=1
	}
}

if($loccheck -eq 1){
	Write-Host "The virtual instance will be deployed in $location"
} else {

	Write-Error -Message "The location provided in configuration file :- $location is not a valid input. Please correct the same and rerun the script"
	exit
}
	
#Fetch resource group and storage account configured in the conf file
$rg=Get-AzResourceGroup -ResourceGroupName $rgname -ev notPresent	-ea 0
$rgcreatechoice='n'
$storecreatechoice='n'

#If resource group does not exist, provision it before proceeding 
if($rg.ProvisioningState -ne "Succeeded") {
	Write-Output "The resource group $rgname does not exist, do you wish to create it in $location(y/n):"
	$rgcreatechoice=Read-Host
	if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y') {
		Write-Output "Creating resourcegroup $rgname in $location"
		$rg=New-AzResourceGroup -Name $rgname -Location $location
		if($rg.ProvisioningState -ne "Succeeded") {
			Write-Output "Error creating resource group. Script will exit now"
			exit
		}
		Write-Output "Created resource group. Continuing to provision the storage account"
		$storecreatechoice='y'
	}else
	{
		Write-Output "Resource group specified does not exist in the selected subscription. Exiting"
		exit
	}
}

if($rgcreatechoice -eq 'n')
{
	$store=Get-AzStorageAccount -ResourceGroupName $rgname -Name $storename -ev stnotPresent -ea 0
	if($store.ProvisioningState -ne "Succeeded"){
		Write-Output "The Storage account provided `"$storename`" doesn't exist in $rgname"
		Write-Output "Do you wish to provision the storage account now(y/n):"
		$storecreatechoice=Read-Host
		if($storecreatechoice -ne 'y' -or $storecreatechoice -ne 'Y'){
			Write-Output "VM creation cannot continue without storage account. Exiting."
			if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y'){
				Write-Output "Resource group $rgname was provisioned in $location while script executed"
				Write-Output "Please delete it if no longer in use"
			}
			exit
		}
	}
}
$storetype='Standard_LRS'
if($storecreatechoice -eq 'y' -or $storecreatechoice -eq 'Y'){
	Write-Output "Preparing to provision storage account $storename in resource group $rgname"
	Write-Output "Do you need geo redundant store or locally reduntant store"
	Write-Output "Enter 1 for geo reduntant(Standard_GRS) or 2 for locally reduntant(Standard_LRS), if you need"
	Write-Output "other options, enter `"n`" to exit now and provision the storage account manually "
	Write-Output "Enter your choice: "
	$storetypechoice=Read-Host
	if($storetypechoice -eq 1)
	{
		Write-Output "Store type set to Standard_GRS"
		$storetype="Standard_GRS"
	}
	if($storetypechoice -eq 2)
	{
		Write-Output "Store type set to Standard_LRS"
		$storetype="Standard_LRS"
	}
	if($storetypechoice -eq 'n' -or $storetypechoice -eq 'N')
	{
		Write-Output "Exiting deployment as per user input"
		exit
	}
	Write-Output "Creating storage account. This is a long operation. Please wait till it completes."
	$store=New-AzStorageAccount -ResourceGroupName $rgname -Name $storename -Location $location -SkuName $storetype
			
}

if($store.ProvisioningState -ne "Succeeded")
{
	Write-Output "Storage account creation did not complete successfully. Exiting deployment"
	if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y'){
		Write-Output "Resource group $rgname was provisioned in $location. Please delete it manually if not needed"
	}
	exit
}else
{
	#Check if the container exists in target account
	$containercheck=Get-AzStorageContainer -Name $dstContainer -Context $store.Context -ErrorAction SilentlyContinue
	if($containercheck.Name -ne $dstContainer)
	{
		#Create Storage container with the provided name
		Write-Output "Storage account creation successful, creating container for disk storage."
		New-AzStorageContainer -Name $dstContainer -Permission Off -Context $store.Context 
	}

}
#Availability set check
if($avsetname -ne '') {
    $avset=Get-AzAvailabilitySet -Name $avsetname -ResourceGroupName $rgname -ErrorAction SilentlyContinue
    if($avset.Name -eq $avsetname) {
        if($avset.Managed) {
            Write-Output "This availability set is not supported by the vm type being deployed,"
            Write-Output "Please use a classic availability set to deploy this VM"
            exit
        }
        Write-Output "Availability set present, vm instance will be provisioned within availability set"
        $avcheck="Yes"
        Start-Sleep 10
    }
}

if($avcheck -eq "No" -and $avsetname -ne '') {
    Write-Output "Creating availability set for the VM"
    $avset=New-AzAvailabilitySet -Name $avsetname -ResourceGroupName $rgname -Location $location -Sku classic
    Start-Sleep 10
    if($avset.Name -eq $avsetname) {
        Write-Output "Created availability set, deployment in progress"
        Start-Sleep 5
    }else
    {
        Write-Output "Deployment will stop now, failed to create availability set"
        Write-Output "To deploy, create a classic availability set in the required resource group"
        Write-Output "And execute the script again"
        exit
    }
    $avcheck="Yes"
}
    
    
#Network configuration for the virtual machine

#create the interface names
$nicnames=@()
if($niccount -gt 0) {
	Write-Output "Creating $niccount nic names"
	for($i=0; $i -lt $niccount; $i++) {
		$nicname=$name+"_nic_"+$i
		$nicnames+=$nicname
		
	}
}else {
	Write-Output "The vm needs at least 1 interface to be configured, current value is $niccount"
	Write-Output "Script will exit now. Please correct the config file as per recommendations and try again"
	exit
}

$ipnames=@()
if($niccount -gt 0) {
	Write-Output "Creating $niccount ip names"
	for($i=0; $i -lt $niccount; $i++) {
		$ipname=$name+"_ip_"+$i
		$ipnames+=$ipname
		
	}
}
if($vnetrgname -ne $rgname){
	#Validate the resource group for provisioning vnet exists
}
  
$vnet=Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $vnetrgname -ev vnetError -ea 0
$vnetcreate='n'
if($vnet.ProvisioningState -eq "Succeeded") 
{
		Write-Output "VirtualNetwork $vnetname exists, checking for subnet"
        $prisnet=Get-AzVirtualNetworkSubnetConfig -Name $prisubnetname -VirtualNetwork $vnet -ev snetPresent -ea 0
		$mgmtsnet=Get-AzVirtualNetworkSubnetConfig -Name $mgmtsubnetname -VirtualNetwork $vnet -ev snetPresent -ea 0
        $svcsnet=Get-AzVirtualNetworkSubnetConfig -Name $svcsubnetname -VirtualNetwork $vnet -ev snetPresent -ea 0
}else
{
	Write-Output "Do you wish to create the Virtual Network as per the configuration provided"
	$vnetcreate=Read-Host -Prompt "Enter y/n"
	if($vnetcreate -ne 'y' -and $vnetcreate -ne 'Y')
	{

		Write-Output "Virtual Network configuration for the VM instance is not provisioned"
		Write-Output "This script will now exit"
		if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y' ){
			Write-Output "Resource group $rgname was provisioned in $location "
			Write-Output "It can be removed if not in use"
		}
		if($storecreatechoice -eq 'y' -or $storecreatechoice -eq 'Y'){
			Write-Output "Storage account $storename was provisoned by this script"
			Write-Output "It can be removed if not used"
		}
		exit
	}
	Write-Output "New Virtual network $vnetname with prefix $prinetprefix will be created in $location"
	$vnetcreate=Read-Host -Prompt "Do you wish to continue (y/n)"
	if($vnetcreate -ne 'y' -and $vnetcreate -ne 'Y')
	{
		Write-Output "Script will exit now as per user input"
		if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y' ){
			Write-Output "Resource group $rgname was provisioned in $location "
			Write-Output "It can be removed if not in use"
		}
		if($storecreatechoice -eq 'y' -or $storecreatechoice -eq 'Y'){
			Write-Output "Storage account $storename was provisoned by this script"
			Write-Output "It can be removed if not used"
		}
		exit
	}
	$mgmtsnet=New-AzVirtualNetworkSubnetConfig -Name $mgmtsubnetname -AddressPrefix $mgmtsnetprefix -ev sNetCreate -ea 0
    if($mgmtsnetprefix -ne $svcsubnetprefix) {
        $svcsnet=New-AzVirtualNetworkSubnetConfig -Name $svcsubnetname -AddressPrefix $svcsnetprefix -ev sNetCreate -ea 0
        $vnet=New-AzVirtualNetwork -Name $vnetname -ResourceGroupName $vnetrgname -Location $location -AddressPrefix $prinetprefix -Subnet $mgmtsnet,$svcsnet -ev vNetCreate -ea 0
    }
    else
    {
        $vnet=New-AzVirtualNetwork -Name $vnetname -ResourceGroupName $vnetrgname -Location $location -AddressPrefix $prinetprefix -Subnet $mgmtsnet -ev vNetCreate -ea 0
        $svcsnet=$mgmtsnet
    }
	
}

if($vnet.ProvisioningState -ne "Succeeded"){
	Write-Output "Virtual network creation failed or script was unable to fetch"
	Write-Output "the Virtual network configuration. Please check the configuration"
	Write-Output "for possible errors and execute the script further"
	if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y' ){
		Write-Output "Resource group $rgname was provisioned in $location "
		Write-Output "It can be removed if not in use"
	}
	if($storecreatechoice -eq 'y' -or $storecreatechoice -eq 'Y'){
		Write-Output "Storage account $storename was provisoned by this script"
		Write-Output "It can be removed if not used"
	}
	exit
}

####Check for Primary Subnet in virtual network
$prinetcreate='n'

$prisnet=Get-AzVirtualNetworkSubnetConfig -Name $prisubnetname -VirtualNetwork $vnet -ev sNetPresent -ea 0
if($prisnet.ProvisioningState -ne "Succeeded") {

	Write-Output "A subnet $prisubnetname with the required configuration $prisnetprefix"
	Write-Output "Was not found in $vnetname "
	Write-Output "The instance provisioning will exit if subnet is not created"
    $prinetcreate='n'
	$prinetcreate=Read-Host -Prompt "Do you wish to create it now (y/n)"
	if($prinetcreate -ne 'y' -and $prinetcreate -ne 'Y') {
		Write-Output "You have chosen not to provision the subnet"
		Write-Output "The script will exit now"
		Write-Output "Please make sure all prerequisites are met and "
		Write-Output "execute the script to provision the instance"
		if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y' ){
			Write-Output "Resource group $rgname was provisioned in $location "
			Write-Output "It can be removed if not in use"
		}
		if($storecreatechoice -eq 'y' -or $storecreatechoice -eq 'Y'){
			Write-Output "Storage account $storename was provisoned by this script"
			Write-Output "It can be removed if not used"
		}
		exit
	}
	$prisnet=New-AzVirtualNetworkSubnetConfig -Name $prisubnetname -AddressPrefix $prisnetprefix -ev sNetCreate -ea 0
	Set-AzVirtualNetworkSubnetConfig -Name $prisubnetname -VirtualNetwork $vnet -ev sNetAssign -ea 0
}


##Check for Management Subnet in Virtual Network
$mgmtsnet=Get-AzVirtualNetworkSubnetConfig -Name $mgmtsubnetname -VirtualNetwork $vnet -ev sNetPresent -ea 0

if($mgmtsnet.ProvisioningState -ne "Succeeded") {

	Write-Output "A subnet $mgmtsubnetname with the required configuration $mgmtsnetprefix"
	Write-Output "Was not found in $vnetname "
	Write-Output "The instance provisioning will exit if subnet is not created"
	$snetcreate=Read-Host -Prompt "Do you wish to create it now (y/n)"
	if($snetcreate -ne 'y' -and $snetcreate -ne 'Y') {
		Write-Output "You have chosen not to provision the subnet"
		Write-Output "The script will exit now"
		Write-Output "Please make sure all prerequisites are met and "
		Write-Output "execute the script to provision the instance"
		if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y' ){
			Write-Output "Resource group $rgname was provisioned in $location "
			Write-Output "It can be removed if not in use"
		}
		if($storecreatechoice -eq 'y' -or $storecreatechoice -eq 'Y'){
			Write-Output "Storage account $storename was provisoned by this script"
			Write-Output "It can be removed if not used"
		}
		exit
	}
	$mgmtsnet=New-AzVirtualNetworkSubnetConfig -Name $subnetname -AddressPrefix $snetprefix -ev sNetCreate -ea 0
	Set-AzVirtualNetworkSubnetConfig -Name $mgmtsubnetname -VirtualNetwork $vnet -ev sNetAssign -ea 0
}


####Check for if Svc network is requested, then check for existance
IF([string]::IsNullOrWhiteSpace($svcsubnetname)) {            
    Write-Output "No Svc Subnet Required"
    $svccheck = "go"           
} else 
{                           
    $svcsnet=Get-AzVirtualNetworkSubnetConfig -Name $svcsubnetname -VirtualNetwork $vnet -ev sNetPresent -ea 0
    if($svcsnet.ProvisioningState -ne "Succeeded") {

        Write-Output "A subnet $svcsubnetname with the required configuration $svcsnetprefix"
        Write-Output "Was not found in $vnetname "
        Write-Output "The instance provisioning will exit if subnet is not created"
        $snetcreate='n'
        $snetcreate=Read-Host -Prompt "Do you wish to create it now (y/n)"
        if($snetcreate -ne 'y' -and $snetcreate -ne 'Y') {
            Write-Output "You have chosen not to provision the subnet"
            Write-Output "The script will exit now"
            Write-Output "Please make sure all prerequisites are met and "
            Write-Output "execute the script to provision the instance"
            if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y' ){
                Write-Output "Resource group $rgname was provisioned in $location "
                Write-Output "It can be removed if not in use"
            }
            if($storecreatechoice -eq 'y' -or $storecreatechoice -eq 'Y'){
                Write-Output "Storage account $storename was provisoned by this script"
                Write-Output "It can be removed if not used"
            }
            exit
        }
        $svcsnet=New-AzVirtualNetworkSubnetConfig -Name $svcsubnetname -AddressPrefix $svcsnetprefix -ev sNetCreate -ea 0
        Set-AzVirtualNetworkSubnetConfig -Name $svcsubnetname -VirtualNetwork $vnet -ev sNetAssign -ea 0
        if($svcsnet.ProvisioningState -eq "Succeeded")
            {
                $svccheck = "go"
            }
            else {
                $svccheck = "error"
            }
    }
}



if(($mgmtsnet.ProvisioningState -ne "Succeeded") -or ($prisnet.ProvisioningState -ne "Succeeded") -or ($svccheck -ne "go")){
	Write-Output "Subnet provisioning failed"
	Write-Output "Deployment cannot continue"
	if($rgcreatechoice -eq 'y' -or $rgcreatechoice -eq 'Y' ){
		Write-Output "Resource group $rgname was provisioned in $location "
		Write-Output "It can be removed if not in use"
	}
	if($storecreatechoice -eq 'y' -or $storecreatechoice -eq 'Y'){
		Write-Output "Storage account $storename was provisoned by this script"
		Write-Output "It can be removed if not used"
	}
	exit
}

if($sanityrun -eq 'y'){
    Write-Host "Exiting sanity check" -Foreground Green 
    exit
}

#Start creation of the VM object
Write-Output "Creating the vm object...."
#$cred=Get-Credential
if($avcheck -eq "Yes") {
    $vm = New-AzVMConfig -VMName $name -VMSize $vmsize -AvailabilitySetId $avset.Id
}else
{
   $vm = New-AzVMConfig -VMName $name -VMSize $vmsize
}
#$vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $name -Credential $cred

#Create interfaces and ip objects as per config file
$pip=@()
$pipopt='n'
Write-Output "Do you wish to allocate public ip address to the instance"
$pipopt=Read-Host -Prompt "Enter y or n to proceed"
Write-Output "Generating interface configuration and attaching ip addresses...."
if($pipopt -eq 'y' -or $pipopt -eq 'Y'){
	for($i=0; $i -lt $niccount ; $i++) {
			$pip=New-AzPublicIpAddress -Name $ipnames[$i] -ResourceGroupName $rgname -Location $location -AllocationMethod Static
			if($i -eq 0) {
                $nic=New-AzNetworkInterface -Name $nicnames[$i] -ResourceGroupName $rgname -Location $location -SubnetId $prisnet.Id -PublicIpAddressId $pip.Id
				$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id -Primary
			}
            if($i -eq 1)
            {
                $nic=New-AzNetworkInterface -Name $nicnames[$i] -ResourceGroupName $rgname -Location $location -SubnetId $mgmtsnet.Id -PublicIpAddressId $pip.Id
				$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
            }
            IF([string]::IsNullOrWhiteSpace($svcsubnetname)) {

            }
            else {
                $nic=New-AzNetworkInterface -Name $nicnames[$i] -ResourceGroupName $rgname -Location $location -SubnetId $svcsnet.Id -PublicIpAddressId $pip.Id
				$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
            }
			$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
		}
}
else {
	for($i=0; $i -lt $niccount ; $i++) {
		
		if($i -eq 0) {
            $nic=New-AzNetworkInterface -Name $nicnames[$i] -ResourceGroupName $rgname -Location $location -SubnetId $prisnet.Id
			$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id -Primary
		}
        if($i -eq 1)
        {
            $nic=New-AzNetworkInterface -Name $nicnames[$i] -ResourceGroupName $rgname -Location $location -SubnetId $mgmtsnet.Id
			$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
        }
        IF([string]::IsNullOrWhiteSpace($svcsubnetname)) {

        }
        else {
            $nic=New-AzNetworkInterface -Name $nicnames[$i] -ResourceGroupName $rgname -Location $location -SubnetId $svcsnet.Id
			$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
        }
		$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
	}
}

#Setting up disks for the VM

Write-Output "Setting up the disks."
$osdiskname=$name+"_"+"osdisk.vhd"
$blob="$dstStorageURI/$dstContainer"
$osDiskUri = "$blob/$osdiskname"
$osimageUri = "$osimage"

Write-Output "Disk info for the VM "
Write-Output "OS Disk : $osdiskname"
Write-Output "Blob : $blob"
Write-Output "OS disk URI : $osDiskUri"

Start-Sleep 10

Write-Output "Copying disks to the path"

$storecontext=$store.Context
Start-AzStorageBlobCopy -AbsoluteUri $osimageUri -Context $storecontext -DestContainer $dstContainer -DestBlob $osdiskname
$osstatus=Get-AzStorageBlobCopyState -Context $storecontext -Blob $osdiskname -Container $dstContainer
While($osstatus.Status -ne "Success") {
	Start-Sleep 20
	$osstatus=Get-AzStorageBlobCopyState -Context $storecontext -Blob $osdiskname -Container $dstContainer
	if($osstatus.Status -ne "Pending") {
		Break
	}
}

$vm=Set-AzVMOSDisk -VM $vm -Name $osdiskname -VhdUri $osDiskUri -CreateOption Attach -Linux
#Create the azure Virtual machine

Write-Output "Disk setup completed, vm object generated succesfully. Creating the instance."
New-AzVM -ResourceGroupName $rgname -Location $location -VM $vm -Verbose
