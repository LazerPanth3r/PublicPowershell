Import-Module ActiveDirectory
Import-Module Az.Storage
# replace with your tenant ID
$tenant_id = ''
$subscription_id = ""
Connect-AzAccount -Identity
$AzureContext = Set-AzContext -SubscriptionId $subscription_id
$Today = Get-Date
$warnDays = 5 # How many days remaining to email from
# Get a list of AD accounts where enables and the password can expire
$ADUsers = Get-ADUser -SearchBase "OU=Users,DC=root,DC=domain,DC=com" -SearchScope OneLevel -Filter {Enabled -eq $true  -and PasswordNeverExpires -eq $false } -Properties 'msDS-UserPasswordExpiryTimeComputed', 'mail'
#Add an additional OU to search if needed
$ADUsers += Get-ADUser -SearchBase "OU=Users - Special,DC=root,DC=domain,DC=com" -SearchScope OneLevel -Filter {Enabled -eq $true  -and PasswordNeverExpires -eq $false } -Properties 'msDS-UserPasswordExpiryTimeComputed', 'mail'
$AlreadyExpiredList = ""
$outFileHeader = "Email," + "Name," + "MailSubject," + "DaysRemaining"
$outfileName = "expiring.csv"
$outfile = $env:TEMP + "\expiring.csv"
$expiredFile = $env:TEMP + "\expired.csv"
$expiredFileHeader = "Name," + "Email," + "ExpireDate"
$expiredFileName = "expired.csv"
$outFileHeader | Out-File $outfile
$expiredFileHeader | Out-File $expiredFile
foreach($user in $ADUsers)
    {
    # Get the expiry date and convert to date time
    $ExpireDate = [datetime]::FromFileTime( $User.'msDS-UserPasswordExpiryTimeComputed' )
    $ExpireDate_String = $ExpireDate.ToString("MM/dd/yyyy h:mm tt") # Format as USA
 
    # Calculate the days remaining
    $daysRmmaining  = New-TimeSpan -Start $Today -End $ExpireDate
    $daysRmmaining = $daysRmmaining.Days
 
    $usersName = $User.Name
    $userMail = $user.mail
    if ($daysRmmaining -le $warnDays -And $daysRmmaining -ge 0)
        {
            Write-host "$usersName is expiring"
            # Generate email subjet from days remaining
            if ($daysRmmaining -eq 0)
            {
                $mailSubject = "Your password expires today"
            } else {
                $mailSubject = "Your password expires in $daysRmmaining days"
            }
            if($null -eq $usermail)
            {
                Write-Output "Skipping Expiring $usersName, no email"
            }
            else{
            $output = "$usermail, $usersName, $mailSubject, $daysRmmaining"
            $output | out-file $outfile -Append
            }
        }
    elseif ($daysRmmaining -lt 0) {
            # Password already expired, add the users details to a list ready for email
            if($null -eq $usermail)
            {
                Write-Output "Skipping Expired $usersName, no email"
            }
            else{
            $AlreadyExpired ="$usersName, $userMail, $ExpireDate_String"
            $AlreadyExpired | out-file $expiredFile -Append
            }
        }  
}
###Connect to AZ Storage
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
$storageContext = New-AzStorageContext -ConnectionString $stringValueText
$blobs = Get-AzStorageBlob -Container $ContainerName -Context $storageContext
$ckExpiring = Test-Path $outfile
if($null -ne $ckExpiring)
{
    $testfile = import-csv $outfile | Measure-object
    $testcount = $testfile.count
    if($testcount -gt 0)
    {
        Write-Output "Writing expiring users file to blob storage"
        Set-AzStorageBlobContent -File $outfile -Container $ContainerName -BlobType "Block" -Context $storageContext -Verbose -force
    }
}
$ckExpired = Test-Path $expiredFile
if($null -ne $ckExpired)
{
    $test2file = import-csv $expiredFile | Measure-object
    $test2count = $test2file.count
    if($test2count -gt 0)
    {
        Write-Output "Writing expired users file to blob storage"
        Set-AzStorageBlobContent -File $expiredFile -Container $ContainerName -BlobType "Block" -Context $storageContext -Verbose -force
    }
}