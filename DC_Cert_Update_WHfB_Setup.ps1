#Use this script as part of the WHfB deployment to get DC's to pick up the updated certs for Smart Card auth

#Adjust this and use parts as needed if the server complains. Be smart and figure it out.
​
#Get local certificate store
$my=dir cert:\LocalMachine\My
​
#Get active certificate using "MP Kerberos Authentication" template
$dccert=$my | where-object {($_.Archived -eq $false) -and (($_.extensions.item("1.3.6.1.4.1.311.21.7").format(0)) -match "Domain Controller")  }
​
"INFO! Existing DC cert $($dccert.serialnumber) will be removed from local store"
​
#Delete existing cert
remove-item $dccert.pspath
​
If ($?)
    {"SUCCESS! Removed old certificate. Triggering autoenrolment for new cert.."
    
    #Trigger autoenrollment
    certutil -pulse
    
    #Get local certificate store
    $my=dir cert:\LocalMachine\My
​
    #Check for active certificate using Domain Controller Authentication template
    $dccert=$my | where-object {($_.Archived -eq $false) -and (($_.extensions.item("1.3.6.1.4.1.311.21.7").format(0)) -match "Domain Controller")  }   
    
    "INFO! DC certificate is now $($dccert.serialnumber)"
    }
​
Else
    {"ERROR! Unable to remove existing certificate"}