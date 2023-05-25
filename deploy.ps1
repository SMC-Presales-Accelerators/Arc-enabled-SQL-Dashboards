<#
.Synopsis
DPi30 Decision and Deployment Tree

.Description
Script that will walk you through determining the proper DPi30 Template and help you deploy it step by step.
#>

#Validate yes or no question input
function BoolValidation {
    Param(
        #User input
        $UserInput
    )
    $validbool = @("y", "n", "yes", "no")
    $positiveresponse = @("y", "yess")
    if ($UserInput.ToLower() -in $validbool) {
        if($UserInput.toLower() -in $positiveresponse) {
            return @{Result=$true; Message="Valid"; Response=$true}
        } else {
            return @{Result=$true; Message="Valid"; Response=$false}
        }
    }
    else {
        return @{Result=$false; Message="Please answer Yes(y) or No(n)"}
    }
}

#Validate integer based question input both as an input value but also the number of options available
function IntValidation {
    Param(
        #User input
        $UserInput,
        #Options Count to verify its within range
        $OptionCount
    )
    $intref = 0
    if( [int32]::TryParse( $UserInput , [ref]$intref ) -and [int32]$UserInput -le $OptionCount -and [int32]$UserInput -gt 0) {
        return @{Result=$true; Message="Valid"}
    }
    else {
      return @{Result=$false; Message="Please enter a valid selection number"}
    }
}

#Validating the input of a yes no for continuing with deployment, more specific than a normal boolean situation.
function ProceedValidation {
    $InputMessage = "`r`nWould you like to continue? "
    Write-Host $InputMessage -NoNewLine
    $confirmation = Read-Host
    $valid = BoolValidation -UserInput $confirmation
    while(!($valid.Result)){
        Write-Host $valid.Message -ForegroundColor Yellow
        Write-Host $InputMessage -NoNewLine
        $confirmation = Read-Host
        $valid = BoolValidation -UserInput $confirmation
    }
    if($confirmation.ToLower().SubString(0,1) -eq "n"){
        #Stop script because they said no on continuing
        Write-Host "Stopping!!! Any resources that were created up until this point were not removed and would require you to cleanup if desired" -ForegroundColor Red
        exit
    } else {
        return $confirmation.ToLower().SubString(0,1)
    }
    
}

function SubscriptionSelection {
    $InputMessage = "`r`nSubscription number"
    $SubSelection = Read-Host $InputMessage
    $valid = IntValidation -UserInput $SubSelection
    while(!($valid.Result)) {
        Write-Host $valid.Message -ForegroundColor Yellow
        $SubSelection = Read-Host $InputMessage
        $valid = IntValidation -UserInput $SubSelection
    }
    while([int32]$SubSelection -ge $subcount) {
        Write-Host "Please select a valid subscription number, $SubSelection is not an option" -ForegroundColor Yellow
        $SubSelection = SubscriptionSelection
    }
    return $SubSelection
}

function DeployWorkbook {
    Param(
        #Workbook Display name
        $WorkbookDisplayName,
        #Gallery Template Json string to deploy
        $WorkbookJson,
        #resource group to deploy to
        $ResourceGroup
    )

    $SerializedTemplateJson = $WorkbookJson.psobject.BaseObject | ConvertTo-Json -Compress

    $WorkbookArmTemplate = @'
    {
        "contentVersion": "1.0.0.0",
        "parameters": {
          "workbookDisplayName": {
            "type": "string",
            "defaultValue": "{WorkbookDisplayName}",
            "metadata": {
              "description": "The friendly name for the workbook that is used in the Gallery or Saved List.  This name must be unique within a resource group."
            }
          },
          "workbookType": {
            "type": "string",
            "defaultValue": "workbook",
            "metadata": {
              "description": "The gallery that the workbook will been shown under. Supported values include workbook, tsg, etc. Usually, this is 'workbook'"
            }
          },
          "workbookSourceId": {
            "type": "string",
            "defaultValue": "Azure Monitor",
            "metadata": {
              "description": "The id of resource instance to which the workbook will be associated"
            }
          },
          "workbookId": {
            "type": "string",
            "defaultValue": "[newGuid()]",
            "metadata": {
              "description": "The unique guid for this workbook instance"
            }
          }
        },
        "resources": [
          {
            "name": "[parameters('workbookId')]",
            "type": "microsoft.insights/workbooks",
            "location": "[resourceGroup().location]",
            "apiVersion": "2022-04-01",
            "dependsOn": [],
            "kind": "shared",
            "properties": {
              "displayName": "[parameters('workbookDisplayName')]",
              "serializedData": "{SerializedJson}",
              "version": "1.0",
              "sourceId": "[parameters('workbookSourceId')]",
              "category": "[parameters('workbookType')]"
            }
          }
        ],
        "outputs": {
          "workbookId": {
            "type": "string",
            "value": "[resourceId( 'microsoft.insights/workbooks', parameters('workbookId'))]"
          }
        },
        "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
      }
'@
      $ArmTemplate = $WorkbookArmTemplate.Replace("{WorkbookDisplayName}", $WorkbookDisplayName)
      # Because we send this is a json object, we also have to remove the extra double quotes
      $ArmTemplate = $ArmTemplate.Replace("""{SerializedJson}""", $SerializedTemplateJson)

      $TemplateObject = ConvertFrom-Json $ArmTemplate -AsHashtable

      $Deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -TemplateObject $TemplateObject

      Write-Host "Finished Deploying Workbook $WorkbookDisplayName"

      return $Deployment.Outputs["workbookId"]
}

function CreateWorkbookLink {
    Param(
        $WorkbookId,
        $ResourceGroup
    )

    #To properly link to the Workbooks created above, we need to build the links based on the resource id
    $WorkbookLink = "https://portal.azure.com/#blade/AppInsightsExtension/UsageNotebookBlade/ComponentId/Azure%20Monitor/ConfigurationId/"
    $WorkbookLink = $WorkbookLink + [uri]::EscapeDataString($WorkbookId)
    #Then we need to get the Display Name also
    $WorkbookDisplayName = $(Get-AzApplicationInsightsWorkbook -Name $WorkbookId.Split("/")[-1] -ResourceGroupName $ResourceGroup).DisplayName
    $WorkbookLink = $WorkbookLink + "/Type/workbook/WorkbookTemplateName/" + [uri]::EscapeDataString($WorkbookDisplayName)

    return $WorkbookLink
}

function DeployResources {
    Param(
        #resource group to deploy to
        $ResourceGroup,

        # Best Practices Analysis Workspace Object
        $BpaWorkspace,

        #Performance Workspace Object
        $PerformanceInsightsWorkspace
    )
    $json = Get-Content -Path '.\Workbooks\SQL Licensing Summary.json' -Raw
    $LicensingWorkbookId = DeployWorkbook -WorkbookDisplayName "SQL Licensing Summary" -WorkbookJson $json -ResourceGroup $ResourceGroup

    $json = Get-Content -Path '.\Workbooks\SQL Best Practice Assessment Workbook.json' -Raw
    $json = $json.Replace("{BpaLogAnalyticsWorkspace}", $BpaWorkspace.ResourceId)
    $BpaWorkbookId = DeployWorkbook -WorkbookDisplayName "SQL Best Practice Assessment Workbook" -WorkbookJson $json -ResourceGroup $ResourceGroup

    # We need the RG Location to be able to create the Dashboard Deployment
    $RgLocation = $(Get-AzResourceGroup -Name $ResourceGroup).Location

    $json = Get-Content -Path '.\Dashboards\Arc SQL Server Instances.json' -Raw
    $json = $json.Replace("INSERT LOCATION", $RgLocation)
    $ArcSqlInstancesDashboardId = New-Guid
    $json | Out-File -Path "$ArcSqlInstancesDashboardId.json"
    $ArcInstanceDashboardResult = New-AzPortalDashboard -DashboardPath "$ArcSqlInstancesDashboardId.json" -Name $ArcSqlInstancesDashboardId -ResourceGroupName $ResourceGroup
    if($ArcInstanceDashboardResult) {
        Write-Host "Finished Deploying Arc SQL Server Instances Dashboard"
    }

    #To properly link to the Workbooks created above, we need to build the links based on the resource id
    $BpaWorkbookLink = CreateWorkbookLink -WorkbookId $BpaWorkbookId.Value -ResourceGroup $ResourceGroup
    $LicensingWorkbookLink = CreateWorkbookLink -WorkbookId $LicensingWorkbookId.Value -ResourceGroup $ResourceGroup

    $json = Get-Content -Path '.\Dashboards\Azure Arc Enabled SQL Server Demo Dashboard.json' -Raw
    $json = $json.Replace("INSERT LOCATION", $RgLocation)
    $json = $json.Replace("{BpaWorkbookLink}", $BpaWorkbookLink)
    $json = $json.Replace("{BpaLogAnalyticsWorkspace}", $BpaWorkspace.ResourceId)
    $json = $json.Replace("{BpaLogAnalyticsWorkspaceName}", $BpaWorkspace.Name)
    $json = $json.Replace("{PerformanceInsightsLogAnalyticsWorkspace}", $PerformanceInsightsWorkspace.ResourceId)
    $json = $json.Replace("{PerformanceInsightsWorkspaceName}", $PerformanceInsightsWorkspace.Name)
    $json = $json.Replace("{SQLLicensingWorkbookLink}", $LicensingWorkbookLink)
    $ArcSqlDashboardId = New-Guid
    $json | Out-File -Path "$ArcSqlDashboardId.json"
    $ArcSqlDashboardResult = New-AzPortalDashboard -DashboardPath "$ArcSqlDashboardId.json" -Name $ArcSqlDashboardId -ResourceGroupName $ResourceGroup
    if($ArcSqlDashboardResult) {
        Write-Host "Finished Deploying Azure Arc Enabled SQL Server Demo Dashboard"
    }

    Write-Host "`r`nResources have been fully deployed to your resource group " -NoNewLine
    Write-Host $ResourceGroup -ForegroundColor Cyan 
}

#Install Az-ConnectedMachine to allow for Extension Data Gathering
Install-Module -Name Az.ConnectedMachine

# Our code entry point, We verify the subscription and move through the steps from here.
Clear-Host
$currentsub = Get-AzContext
$currentsubfull = $currentsub.Subscription.Name + " (" + $currentsub.Subscription.Id + ")"
Write-Host "Welcome to the Azure Enabled SQL Dashboard Deployment Wizard!"
Write-Host "Before we get started, we need to select the subscription for this deployment:`r`n"

#Gathering subscription selection, validating input and changing to another subscription if needed
$rawsubscriptionlist = Get-AzSubscription | Where-Object {$_.State -ne "Disabled"} | Sort-Object -property Name | Select-Object Name, Id 
$subscriptionlist = [ordered]@{}
$subscriptionlist.Add(1, "CURRENT SUBSCRIPTION: $($currentsubfull)")
$subcount = 2
foreach ($subscription in $rawsubscriptionlist) {
    $subname = $subscription.Name + " (" + $subscription.Id + ")"
    if($subname -ne $currentsubfull) {
        $subscriptionlist.Add($subcount, $subname)
        $subcount++
    }
}
$subscriptionlist.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key))" "$($_.Value)"}

$InputMessage = "`r`nSubscription number"
$SubSelection = Read-Host $InputMessage
$valid = IntValidation -UserInput $SubSelection -OptionCount $subscriptionlist.Count
while(!($valid.Result)) {
    Write-Host $valid.Message -ForegroundColor Yellow
    $SubSelection = Read-Host $InputMessage
    $valid = IntValidation -UserInput $SubSelection -OptionCount $subscriptionlist.Count
}

if ($SubSelection -ne 1) {
    $selectedsub = $subscriptionlist.[int]$SubSelection
    $selectedsubid = $selectedsub.Substring($selectedsub.Length - 37).TrimEnd(")")
    $changesub = Select-AzSubscription -Subscription $selectedsubid
    Write-Host "`r`nSuccessfully changed to Subscription $($changesub.Name)" -ForegroundColor Green
} else {
    Write-Host "`r`nContinuing with current Subscription $($currentsubfull)" -ForegroundColor Green   
}
Start-Sleep -s 2 #Quick sleep before a new section and clear host

# Show them the RG with the most Arc resources and ask if they want to deploy the daskboards there
# Otherwise, ask for an RG name
$MostUsedArcRG = (Get-AzConnectedMachine | Group-Object ResourceGroupName | Sort-Object -Descending Count | Select-Object Name, Count)[0].Name
$SelectedRg = ""

Write-Host "`r`nWe see most of your Arc Resources are deployed in the Resource Group " -NoNewLine
Write-Host $MostUsedArcRG -ForegroundColor Cyan 
$InputMessage = "Should we deploy the workbooks and dashboards to the Resource Group named $MostUsedArcRG (y/n)?"
$RgResponse = Read-Host $InputMessage
$valid = BoolValidation -UserInput $RgResponse
while(!($valid.Result)) {
    Write-Host $valid.Message -ForegroundColor Yellow
    $RgResponse = Read-Host $InputMessage
}

if($valid.Result) {
    if($valid.Response) {
        $SelectedRg = $MostUsedArcRG
    } else {
        $RgOutput = $null
        while(!($RgOutput)) {
            $SelectedRg = Read-Host "Please enter your Resource Group (it must already exist)"
            $RgOutput = Get-AzResourceGroup -Name $SelectedRg 2>$null
            if(!($RgOutput)) {
                Write-Warning "Resource Group $SelectedRg does not exist in this subscription."
            }
        }
    }
    Write-Host $SelectedRg -ForegroundColor Cyan -NoNewline
    Write-Host " has been selected!"
}

# This grabs all the workspaces associated with SQL Best Practices Assessments

$SelectedBpaWorkspace = [PSCustomObject]@{
    Name = "";
    ResourceId = ""
}

$BpaWorkspaces = [System.Collections.ArrayList]@()
Get-AzConnectedMachine | 
    ForEach-Object {Get-AzConnectedMachineExtension -MachineName $_.Name -ResourceGroupName $_.ResourceGroupName -Name "WindowsAgent.SqlServer"} 2>$null | 
    ForEach-Object {ConvertFrom-Json $_.Setting} | 
    ForEach-Object { $_.AssessmentSettings.WorkspaceResourceId } | 
    Sort-Object | 
    Get-Unique |
    ForEach-Object { $BpaWorkspaces.add([PSCustomObject]@{Name = $_.split("/workspaces/")[1]; ResourceId = $_;}) }

# Logic to add: 
# If there is only one workspace used just show at end, if there are multiple have them choose

if($BpaWorkspaces.Count -eq 1) {
    $SelectedBpaWorkspace = $BpaWorkspaces[0]
} elseif ($BpaWorkspaces.Count -gt 1) {
    $WsCount = 1
    Write-Host "Please select the Best Practices Assessment Workspace you would like to show in this dashboard:"
    $BpaWorkspaces.GetEnumerator() | ForEach-Object { Write-Host "$($WsCount)$($WsCount++))" "$($_.Name)"}
    $InputMessage = "`r`nBPA Workspace number"
    $WsSelection = Read-Host $InputMessage
    $valid = IntValidation -UserInput $WsSelection -OptionCount $BpaWorkspaces.Count
    while(!($valid.Result)) {
        Write-Host $valid.Message -ForegroundColor Yellow
        $SubSelection = Read-Host $InputMessage
        $valid = IntValidation -UserInput $WsSelection -OptionCount $PerformanceInsights.Count
    }
    $SelectedBpaWorkspace = $BpaWorkspaces[$WsSelection-1]
} elseif($BpaWorkspaces.Count -eq 0) {
    Write-Error "You do not have SQL Best Practices Assessment configured for your subscription, please enable for at least one device and try again."
    exit
} 

Clear-Host

# Here we get our performance insights Workspaces, same logic as before, if there's only one let's confirm at the end
$PerformanceInsights = [System.Collections.ArrayList]@()
$AllLogAnalyticsWorkspaces = Get-AzOperationalInsightsWorkspace
$PerformanceInsightsWorkspaces = Get-AzConnectedMachine | ForEach-Object {Get-AzConnectedMachineExtension -MachineName $_.Name -ResourceGroupName $_.ResourceGroupName -Name "MicrosoftMonitoringAgent"} 2>$null | ForEach-Object {ConvertFrom-Json $_.Setting} | ForEach-Object { $_.WorkspaceId } | Sort-Object | Get-Unique
$AllLogAnalyticsWorkspaces | Where-Object {$_.CustomerId -in $PerformanceInsightsWorkspaces} | ForEach-Object {$PerformanceInsights.add([PSCustomObject]@{Name = $_.Name; ResourceId = $_.ResourceId})}

$SelectedPerformanceInsightsWorkspace = [PSCustomObject]@{
    Name = "";
    ResourceId = ""
}

if($PerformanceInsights.Count -eq 1) {
    $SelectedPerformanceInsightsWorkspace = $PerformanceInsights[0]
} elseif ($PerformanceInsights.Count -gt 1) {
    $WsCount = 1
    Write-Host "Please select the Performance Insights Workspace you would like to show in this dashboard:"
    $PerformanceInsights.GetEnumerator() | ForEach-Object { Write-Host "$($WsCount)$($WsCount++))" "$($_.Name)"}
    $InputMessage = "`r`nPerformance Insights Workspace number"
    $WsSelection = Read-Host $InputMessage
    $valid = IntValidation -UserInput $WsSelection -OptionCount $PerformanceInsights.Count
    while(!($valid.Result)) {
        Write-Host $valid.Message -ForegroundColor Yellow
        $SubSelection = Read-Host $InputMessage
        $valid = IntValidation -UserInput $WsSelection -OptionCount $PerformanceInsights.Count
    }
    $SelectedPerformanceInsightsWorkspace = $PerformanceInsights[$WsSelection-1]
} elseif($PerformanceInsights.Count -eq 0) {
    Write-Error "You do not have Performance Insights configured for your subscription, please enable for at least one device and try again."
    exit
} 

#Printing template based upon responses and confirming whether to proceed
Clear-Host

Write-Host "`r`nWe will be deploying the dashboards and workbooks to the Resource Group  " -NoNewLine
Write-Host $SelectedRg -ForegroundColor Cyan 
Write-Host "For BPA we will query the information from " -NoNewLine 
Write-Host $SelectedBpaWorkspace.Name -ForegroundColor Cyan 
Write-Host "For Performance Metrics we will query the information from " -NoNewLine 
Write-Host $SelectedPerformanceInsightsWorkspace.Name -ForegroundColor Cyan 

$confirmation = ProceedValidation

if ($confirmation -eq "y") {
    Write-Host "`r`nProceeding with the deployment!" -ForegroundColor Green
    Start-Sleep -s 2 #Quick sleep before a new section and clear host
    DeployResources -ResourceGroup $SelectedRg -BpaWorkspace $SelectedBpaWorkspace -PerformanceInsightsWorkspace $SelectedPerformanceInsightsWorkspace
} else {
  exit
}
