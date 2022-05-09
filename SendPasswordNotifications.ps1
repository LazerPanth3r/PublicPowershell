<#
.SYNOPSIS
Gather Password Expiration Data from on-prem and send emails via secondary runbook
Author: 
Michael Becker (mbecker@mpmaterials.com)
https://github.com/MrV8Rumble
.DESCRIPTION
Send password expiration notice mail utilizing Graph API
.EXAMPLE
​
.NOTES
#>
# Ensure that the runbook does not inherit an AzContext
Disable-AzContextAutosave -Scope Process
# replace with your tenant ID
$tenant_id = ''
​
# The mail subject and it's message
$mailSubject = 'Password Expiration Notice'
###### Don't change below ######
write-output -Message 'Importing Modules...'
Import-Module Az.Accounts
Import-Module Az.KeyVault
Import-Module Az.Storage
​
write-output -Message 'Connecting to Azure using Automation Account RunAs Account...'
$ConnectionName = 'AzureRunAsConnection'
try
{
    # Get the connection properties
    $ServicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName      
    $null = Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $ServicePrincipalConnection.TenantId `
        -ApplicationId $ServicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint 
}
catch 
{
    if (!$ServicePrincipalConnection)
    {
        # You forgot to turn on 'Create Azure Run As account' 
        $ErrorMessage = "Connection $ConnectionName not found."
        throw $ErrorMessage
    }
    else
    {
        # Something else went wrong
        Write-Error -Message $_.Exception.Message
        throw $_.Exception
    }
}
​
# replace with Azure Storage Account info
$KeyVaultName = "keyvault"
$StorageAccountName = "filesharesexternal"
$StringVaultSecretName = "FileShareConnectString"
$StorageVaultSecretName = "FileShareExternal"
$ContainerName = "notifications"
Write-Verbose -Message 'Retrieving values from Key Vault...'
$stringSecretValue = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $StringVaultSecretName).SecretValueText
$sasSecretValue = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $StorageVaultSecretName).SecretValueText
write-output -Message 'Getting the secrets...'
#storage connection string
$connectionString = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $StringVaultSecretName
$stPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($connectionString.SecretValue)
try {
   $stringValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($stPtr)
} finally {
   [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($stPtr)
}
#storage SAS token
$SasTokenValue = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $StorageVaultSecretName
$sasPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SasTokenValue.SecretValue)
try {
   $sasValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($sasPtr)
} finally {
   [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($sasPtr)
}
####get email list data###
$storageContext = New-AzStorageContext -ConnectionString $stringValueText
$blobs = Get-AzStorageBlob -Container $ContainerName -Context $storageContext
if($null -ne $blobs)
{
    Write-Output "Connected to Blob Storage"
}
foreach($blob in $blobs)
{
    if($blob.name -like "expiring.csv")
    {
        Get-AzStorageBlob -Container $ContainerName -Blob $blob.Name -Context $storageContext | Get-AzStorageBlobContent -Destination $env:temp -force
        $expiringFile=$env:TEMP + "\" + $blob.Name
        $ck1 = Test-Path $expiringFile
        if($null -eq $ck1)
        {
            write-output "Expiring Users File not found"
        }
        else{
            $expiringUsers = import-csv $expiringFile
            foreach($entry in $expiringUsers)
            {
                $toAddress = $entry.email
                $ExpireDate_String = $entry.DaysRemaining
                $name = $entry.name
                $mailSubject = $entry.mailSubject
                $mailMessage = "
                    $name,<br>
                    Your password expires in $ExpireDate_String days.</br></br>
                    It is important that you reset your password ASAP to avoid any disruption.</br></br>
                    
                    How do I reset my password?</br>
                    1. While logged on press CTRL + ALT + DELETE and click Change Password.</br>
                    3. Enter your current password, enter and confirm a new password that meets the password policy. Press Enter</br>
                    4. Press CTRL + ALT + DELETE and click Lock.</br>
                    5. Unlock your computer with your new password</br></br>
                    
                    Please note, you may be prompted for MS multifactor authentication.</br>
                    Additionally, you will likely be prompted for password updates on any mobile devices or other computers you may have signed into.</br></br>
                    Thank you for your co-operation.</br></br>
                "
                $mailmessage += "Please contact IT at help@stargatecommand.com if you have any questions or concerns.<br><br>"
                .\SendMail.ps1 -toaddress $toAddress -mailsubject $mailSubject -mailMessage $mailmessage
            }
        }
    }
    if($blob.name -like "expired.csv")
    {
        Get-AzStorageBlob -Container $ContainerName -Blob $blob.Name -Context $storageContext | Get-AzStorageBlobContent -Destination $env:temp -force
        $expiredFile=$env:TEMP + "\" + $blob.Name
        $ck2 = Test-Path $expiredFile
        if($null -eq $ck2)
        {
            write-output "Expired Users File not found"
        }
        else
        {
            # Send already expired, alert the IT department with the list of people
            $expiredUsers = import-csv $expiredFile
            # Provide the sender and recipient email address
            $toAddress = 'help@stargatecommand.com'
            # Specify the email subject and the message
            $mailSubject = 'These users passwords have expired. They may need assistance'
            $mailMessage = "These users passwords have expired. They may need assistance.</br></br>"
            foreach ($item in $expiredUsers) {
                    $name = $item.name
                    $email = $item.email
                    $date = $item.ExpireDate
                    $mailmessage += "$name, $email, $date </br>"
                }
            $mailMessage += "Automated Message from your comapnies Azure</br>"
            # Send the message
            .\SendMail.ps1 -toaddress $toAddress -mailsubject $mailSubject -mailMessage $mailmessage
        }
    }
    
}
if(($null -eq $ck1) -and ($null -eq $ck2))
    {
        break;
    }
​
if($null -ne $ck1)
{
    Remove-azstorageblob -Container $ContainerName -blob "expiring.csv" -Context $storageContext -force
}
if($null -ne $ck2)
{
    Remove-azstorageblob -Container $ContainerName -blob "expired.csv" -Context $storageContext -force
}
​