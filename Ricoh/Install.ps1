###Ricoh Find Me Installation######
<#Checks for Ricoh plotter driver, Ricoh Universal Driver
Install command for intune:
C:\Windows\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1

Detection Rule - File Exists
c:\Windows\System32\DriverStore\FileRepository\oemsetup.inf_amd64_70edaf2aad3f3b25\
oemsetup.inf

C:\Windows\System32\DriverStore\FileRepository\oemsetup.inf_amd64_c7674953e75f1cca\
oemsteup.inf



#>
#Build Log File appending System Date/Time to output
$Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
$Date = (Get-Date -Format "MM-dd-yyyy-hh-mm")


function Write-LogEntry {
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName = "",
        [switch]$Stamp
    )
    $fileCk = [string]::IsNullOrWhiteSpace($filename)
    if($fileCk -eq $true)
    {
        $LogFile = "C:\CompanyName\Logs\UpdatedPrinterDriversInstall_$date.log"
    }
    else {
        $Logfile = $FileName
    }

    If ($Stamp) {
        $LogText = "<$($Value)> <time=""$($Time)"" date=""$($Date)"">"
    }
    else {
        $LogText = "$($Value)"   
    }
	
    Try {
        Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFile -ErrorAction Stop
    }
    Catch [System.Exception] {
        Write-Warning -Message "Unable to add log entry to $LogFile.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    }
}

$ScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

Write-LogEntry -Value "##################################"
Write-LogEntry -Value "INF File 2 - Ricoh Universal: oemsetup.inf"
Write-LogEntry -Value "INF File 3  - Ricoh Plotter: oemsetup.inf"
Write-LogEntry -Value "Script Root: $ScriptRoot"
$dir = get-childitem -Path $ScriptRoot
Write-LogEntry -Value "Directory Listing of PSScriptRoot:"
Write-LogEntry -Value "$dir"
Write-LogEntry -Value "##################################"
Write-LogEntry -Stamp -Value "Installation started"
Write-LogEntry -Value "##################################"
Write-LogEntry -Value "Installing Printer drivers..."


$INFFile= "$ScriptRoot\Ricoh Universal\oemsetup.inf"
$INFFile2 = "$ScriptRoot\Ricoh Plotter\oemsetup.inf"

$INFARGS = @(
    "/add-driver"
    "$INFFile"
)

$INFARGS2 = @(
    "/add-driver"
    "$INFFile2"
)

##clear and set variables
$ThrowBad = $null

###Install Ricoh Universal Driver
try{
    #Stage driver to driver store
    Write-LogEntry -Stamp -Value "Staging Ricoh Driver to Windows Driver Store using INF ""$($INFFile)"""
    Write-LogEntry -Stamp -Value "Running command: Start-Process pnputil.exe -ArgumentList $($INFARGS) -wait -passthru"
    Start-Process "C:\Windows\System32\pnputil.exe" -ArgumentList $INFARGS -wait -passthru
    }
catch{
    Write-Warning "Error staging Ricoh driver to Driver Store"
    Write-Warning "$($_.Exception.Message)"
    Write-LogEntry -Stamp -Value "Error staging Ricoh driver to Driver Store"
    Write-LogEntry -Stamp -Value "$($_.Exception)"
    $ThrowBad = $True
}

If (-not $ThrowBad) {
    Try {
    
        #Install driver
        $DriverName = "RICOH PCL6 UniversalDriver V4.32"
        $DriverExist = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
        if (-not $DriverExist) {
            Write-LogEntry -Stamp -Value "Adding Printer Driver ""$($DriverName)"""
            Add-PrinterDriver -Name $DriverName -Confirm:$false
        }
        else {
            Write-LogEntry -Stamp -Value "Print Driver ""$($DriverName)"" already exists. Skipping driver installation."
        }
    }
    Catch {
        Write-Warning "Error installing Ricoh Printer Driver"
        Write-Warning "$($_.Exception.Message)"
        Write-LogEntry -Stamp -Value "Error installing Printer Driver"
        Write-LogEntry -Stamp -Value "$($_.Exception)"
        $ThrowBad = $True
    }
}


#check for Plotter driver existence
If (-not $ThrowBad) {
    Try {

        #Check for Plotter driver
        $DriverName = "Gestetner MP CW2201 PS"
        $DriverExist = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
        if (-not $DriverExist) {
            ###Stage Ricoh Plotter Driver
            try{
                #Stage driver to driver store
                Write-LogEntry -Stamp -Value "Staging Ricoh Plotter Driver to Windows Driver Store using INF ""$($INFFile2)"""
                Write-LogEntry -Stamp -Value "Running command: pnputil.exe /a $INFFile2"
                Start-Process "C:\Windows\System32\pnputil.exe" -ArgumentList $INFARGS2 -wait -passthru
            }
            catch{
                Write-Warning "Error staging Ricoh Plotter driver to Driver Store"
                Write-Warning "$($_.Exception.Message)"
                Write-LogEntry -Stamp -Value "Error staging Ricoh Plotter driver to Driver Store"
                Write-LogEntry -Stamp -Value "$($_.Exception)"
                $ThrowBad = $True
            }
            If (-not $ThrowBad) {
                Try {

                    #Install driver
                    $DriverName = "Gestetner MP CW2201 PS"
                    $DriverExist = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
                    if (-not $DriverExist) {
                        Write-LogEntry -Stamp -Value "Adding Printer Driver ""$($DriverName)"""
                        Add-PrinterDriver -Name $DriverName -Confirm:$false
                    }
                    else {
                        Write-LogEntry -Stamp -Value "Print Driver ""$($DriverName)"" already exists. Skipping driver installation."
                    }
                }
                Catch {
                    Write-Warning "Error installing Ricoh Plotter Driver"
                    Write-Warning "$($_.Exception.Message)"
                    Write-LogEntry -Stamp -Value "Error installing Plotter Driver"
                    Write-LogEntry -Stamp -Value "$($_.Exception)"
                    $ThrowBad = $True
                }
            }
            
        }
    }
    Catch {
        Write-Warning "Error installing Ricoh Plotter Driver"
        Write-Warning "$($_.Exception.Message)"
        Write-LogEntry -Stamp -Value "Error installing Ricoh Plotter Driver"
        Write-LogEntry -Stamp -Value "$($_.Exception)"
        $ThrowBad = $True
    }
}


If ($ThrowBad) {
    Write-Error "An error was thrown during printer installation. Installation failed."
    Write-LogEntry -Stamp -Value "Installation Failed"
}
