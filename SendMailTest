## PowerShell Runbook for Azure Automation to send mail securely using Key Vault, Azure AD App and Microsoft Graph API ##
## MartijnBrant.net ##
​
###### Change these values ######
​
    # Name of your Key Vault
    $KeyVaultName = "SecureEmailDemo"
​
    # Name of the secret in your Key Vault
    $KeyVaultSecretName = "AADAppSecret"
​
    # The Application ID of your Azure AD App Registraion
    $client_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
​
    # The Tenant ID (can be found at Azure AD App Registration
    $tenant_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    
    # The From Address needs to be a valid email address of an Exchange-Online/Office 365 mail-enabled user
    $fromAddress = 'MyDemoUser@MyDemoTenant.com'
​
    # Who should we email
    $toAddress = 'SGC@Tauri.Avalon'
    
    # The mail subject and it's message
    $mailSubject = 'This is a test message from Azure via Microsoft Graph API'
    $mailMessage = 'This is a test message from Azure via Microsoft Graph API'
​
​
###### Don't change below ######
​
Write-Verbose -Message 'Importing Modules...'
Import-Module Az.Accounts
Import-Module Az.KeyVault
​
Write-Verbose -Message 'Connecting to Azure using Automation Account RunAs Account...'
$ConnectionName = 'AzureRunAsConnection'
try
{
    # Get the connection properties
    $ServicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName      
​
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
​
Write-Verbose -Message 'Retrieving value from Key Vault...'
$KeyVaultSecretValue = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName).SecretValueText
​
Write-Verbose -Message 'Getting the secret...'
$secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
try {
   $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
   [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}
​
Write-Verbose -Message 'Getting a token from Graph...'
$client_secret = $secretValueText
$request = @{
        Method = 'POST'
        URI    = "https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token"
        body   = @{
            grant_type    = "client_credentials"
            scope         = "https://graph.microsoft.com/.default"
            client_id     = $client_id
            client_secret = $client_secret
        }
    }
$token = (Invoke-RestMethod @request).access_token
​
​
# Build the Microsoft Graph API request
$params = @{
  "URI"         = "https://graph.microsoft.com/v1.0/users/$fromAddress/sendMail"
  "Headers"     = @{
    "Authorization" = ("Bearer {0}" -F $token)
  }
  "Method"      = "POST"
  "ContentType" = 'application/json'
  "Body" = (@{
    "message" = @{
      "subject" = $mailSubject
      "body"    = @{
        "contentType" = 'Text'
        "content"     = $mailMessage
      }
      "toRecipients" = @(
        @{
          "emailAddress" = @{
            "address" = $toAddress
          }
        }
      )
    }
  }) | ConvertTo-JSON -Depth 10
}
​
Write-Verbose -Message 'Sending mail via Graph...'
Invoke-RestMethod @params -Verbose
​
Write-Verbose -Message 'All Done!'
