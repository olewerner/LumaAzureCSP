# Classic Azure
Import-Module -Name Azure -Verbose:$False

# Nedd to create Credential Asset with a user that is co-admin and has access to Azure VM Resources
# Automation account should also be created in the same "domain" as the VM resources 
$AACred = Get-AutomationPSCredential -Name 'AzureCredentials'
"Login into Azure Service Manager"

# Add name of VM not to start
$ExceptionVMList = Get-AutomationVariable -Name "VMStartExceptionList"
$ExceptionVMList = $ExceptionVMList.Split(',')

# Convert to correct time zone
$cstzone = [System.TimeZoneInfo]::FindSystemTimeZoneById("W. Europe Standard Time")
$UTCTime = (Get-Date).ToUniversalTime()
$LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCTime, $cstzone)
$day = $LocalTime.DayOfWeek

if ($day -eq 'Saturday' -or $day -eq 'Sunday')
{
    Write-Output ("It is " + $day + ". Cannot use a runbook to start VMs on a weekend.")
    Exit
}

$VMs = $Null
$VM = $Null
# Azure Resource Manager
Import-Module -Name AzureRM.Compute -Verbose:$False
"Login into Azure Resource Manager"
$Null = Login-AzureRmAccount -Credential $AACred

$VMs = Get-AzureRmVM
#$VMs = AzureResourceManager\Get-AzureResource -ResourceType "Microsoft.Compute/virtualMachines"
If(($VMs | Measure-Object).count -ge 1) {
    ForEach($VM in $VMs) {
	    If($ExceptionVMList -contains $VM.Name) {
		    "VM: $($VM.Name) is in exception list, will not start"
	    }
	    Else {
		    $ARMvm = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status
		    If($ARMvm.Statuses[-1].DisplayStatus -eq "VM running") {
			    "ARM VM: $($VM.Name) already started"
		    }
		    ElseIf($ARMvm.Statuses[-1].DisplayStatus -eq "VM deallocated" -or $ARMvm.Statuses[-1].DisplayStatus -eq "VM stopped") {
			    "Starting ARM VM: $($VM.Name) at time: $([System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $cstzone))"
			    Start-AzureRmVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name
		    }
		    Else {
			    "ARM VM: $($VM.Name) is changing status, will not force it to start"
		    }
	    }
    }
}
Else {
	"No ARM VMs found in this subscription"
}