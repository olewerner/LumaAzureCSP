
Import-Module -Name Azure -Verbose:$False

# Nedd to create Credential Asset with a user that is co-admin and has access to Azure VM Resources
# Automation account should also be created in the same "domain" as the VM resources 
$AACred = Get-AutomationPSCredential -Name 'AzureCredentials'

# Add name of VM not to stop
$ExceptionVMList = Get-AutomationVariable -Name "VMStopExceptionList"
$ExceptionVMList = $ExceptionVMList.Split(',')


# Convert to correct time zone
$cstzone = [System.TimeZoneInfo]::FindSystemTimeZoneById("W. Europe Standard Time")

$VMs = $Null
$VM = $Null

Import-Module -Name AzureRM.Compute -Verbose:$False
"Login to Azure Resource Manager"
$Null = Login-AzureRmAccount -Credential $AACred

$VMs = Get-AzureRmVM
#$VMs = Get-AzureRMResource -ResourceType "Microsoft.Compute/virtualMachines"
If(($VMs | Measure-Object).count -ge 1) {	
	ForEach($VM in $VMs) {	
		If($ExceptionVMList -contains $VM.Name) {
			"VM: $($VM.Name) is in exception list, will not stop"
		}
		Else {
			$ARMvm = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status
			If($ARMvm.Statuses[-1].DisplayStatus -eq "VM deallocated") {
				"ARM VM: $($VM.Name) already stopped and deallocated"
			}
			ElseIf($ARMvm.Statuses[-1].DisplayStatus -eq "VM running") {
				"Stopping & deallocating ARM VM: $($VM.Name) at time: $([System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $cstzone))"
				Stop-AzureRMVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force	
			}
			ElseIf($ARMvm.Statuses[-1].DisplayStatus -eq "VM stopped") {
				"Deallocating ARM VM: $($VM.Name) at time: $([System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $cstzone))"
				Stop-AzureRMVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force	
			}
			Else {
				"ARM VM: $($VM.Name) is changing status, will not force it to stop. Time: $([System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $cstzone))"
			}		
		}
	}
}
Else {
	"No ARM VMs found in this subscription"
}
