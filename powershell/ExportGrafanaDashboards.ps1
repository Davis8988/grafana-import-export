﻿

# Psrerequisites:
#   Powershell v2 or higher
#   Get API Key from Grafana at: Settings -> API Keys (A viewer-key will suffice only for dashboards and folders. An admin-key will be required for datasources)

# If using powershell v2: $scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptPath = $PSScriptRoot

$grafana_home_url = "http://13.90.250.12:3000"
$api_key = "eyJrIjoiSzlEUUNvUG9kdGRvRWlFMXh2eWFuZ0VzV1NJNm0xaU0iLCJuIjoiZGFzaGJvYXJkc19leHBvcnRfaW1wb3J0X2FkbWluIiwiaWQiOjF9"


function grafanaApiCall() {
	Param(
		[parameter(Mandatory=$true, Position=0)]
		[String] $grafanaHost,
		[parameter(Mandatory=$true, Position=1)]
		[String] $apiType,
		[parameter(Mandatory=$true, Position=2)]
		[String] $apiKey
    )
	# Do not change unless you know what you are doing:
	$grafana_api_error_msg = "If you're seeing this Grafana has failed to load its application files"
	$basicAuth = [string]::Format("Bearer {0}", "${apiKey}")
	$headers = @{"Authorization" = $basicAuth }
	
	$grafanaFullUri = "$grafanaHost/api/$apiType"
	try {
		$resultData = Invoke-RestMethod -Uri $grafanaFullUri -Headers $headers -ContentType 'application/json'
		
		# Check for errors:
		if (($resultData -eq $null) -or ($resultData -Like "*${grafana_api_error_msg}*")) {Read-Host "Failed querying grafana api at: $grafanaFullUri using defined 'api_key' in this script"; exit 1}
		return $resultData
	} catch {
		# Note that value__ is not a typo.
		Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
		Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
		Read-Host "Exception Message:" $_.Exception.Message
		exit 1
	}
}


function exportDashboardsAndFolders() {
	$grafana_dashboards_api_url = "${grafana_home_url}/api/search"
	
	Write-Host "Exporting dashborads from: $grafana_home_url"

	Write-Host "Querying.."
	
	$dashboards = grafanaApiCall "$grafana_home_url" "search" "$api_key"
	
	Write-Host "Found $($dashboards.count) dashboards"

	Write-Host "Creating exported dashboards and folders dirs next to this script at: $scriptPath"
	New-Item -ItemType Directory -Path "$scriptPath\exported_dashboards" -Force
	New-Item -ItemType Directory -Path "$scriptPath\exported_folders" -Force

	foreach ($dash in $dashboards) {
		Write-Host "Exporting: $($dash.title)"
		$dash_url = "${grafana_home_url}/api/dashboards/uid/$($dash.uid)"
		
		$dash_Content = grafanaApiCall "$grafana_home_url" "dashboards/uid/$($dash.uid)" "$api_key"

		$dash_title = $dash_Content.dashboard.title
		$dash_Content.dashboard.id = $null   # When importing always assign $null to the dashboard.id field
		$dash_Content.dashboard.uid = $null  # When importing if setting dashboard.uid field to $null it will create a new dashboard. But will overwrite an existing dashboard otherwise
		$dash_Content.dashboard.version = 1  # Reset dashboard version
		$dash_Content.meta.version = 1

		Write-Host "Saving exported: $dash_title"
		if ($dash_Content.meta.isFolder) {$dash_Content | ConvertTo-Json | Out-File "$scriptPath\exported_folders\$dash_title.json"}
		else {$dash_Content | ConvertTo-Json | Out-File "$scriptPath\exported_dashboards\$dash_title.json"}

		Write-Host "`n"

	}
	
}

function exportDatasources() {
	
	Write-Host "Exporting datasources from: $grafana_home_url"
	Write-Host "Querying.."
	
	$datasources = grafanaApiCall "$grafana_home_url" "datasources" "$api_key"

	Write-Host "Found $($datasources.count) datasources"

	Write-Host "Creating exported datasources dir next to this script at: $scriptPath"
	New-Item -ItemType Directory -Path "$scriptPath\exported_datasources" -Force

	foreach ($dataSrc in $datasources) {
		Write-Host "Exporting: $($dataSrc.title)"
		$dataSrc_url = "${grafana_home_url}/api/datasources/$($dataSrc.id)"
		
		$dataSrc_Content = grafanaApiCall "$grafana_home_url" "datasources/$($dataSrc.id)" "$api_key"

		$dataSrc_Name = $dataSrc_Content.name
		$dataSrc_Content.id = $null   # When importing always assign $null to the datasource.id field

		Write-Host "Saving exported: $dataSrc_Name"
		$dataSrc_Content | ConvertTo-Json | Out-File "$scriptPath\exported_datasources\$dataSrc_Name.json"
		Write-Host "`n"

	}
	
}






function main() {
	Write-Host "Exporter Started"
	exportDashboardsAndFolders
	exportDatasources
	Write-Host "Exporter Finished"
	Read-Host
}


main










