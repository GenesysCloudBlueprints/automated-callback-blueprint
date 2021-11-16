<#
.Description
Remove-ProactiveCallbacks deletes the configuration and objects made by Deploy-ProactiveCallbacks
#>

Write-Host "Please wait..." -ForegroundColor Green -BackgroundColor Black

# Initialize the configuration data
$params = Get-Content 'config.json' | ConvertFrom-Json
$targetQueueName = $params.TargetQueue.name
$integrationName = $params.Integration.name

$dataActions = @(
    'Add contact to contact list'
    'Create placeholder callback'
    'Execute workflow'
    'Get callbacks waiting'
    'Get interaction state'
    'Disconnect callback'
)

$flowNames = @(
    'Proactive callback workbin',
    'Proactive callback connect',
    'Proactive callbacks',
    'Trigger proactive callback workflow'
)

$outputLog = ""

# Delete Queue
$queueId = (gc.exe routing queues list -a --name "Waiting callbacks" | ConvertFrom-Json) | Select-Object id -First 1 -ExpandProperty id
if ($queueId)
{
    gc.exe routing queues delete $queueId
    $outputLog += "-Waiting callbacks queue deleted. `n"
}
else 
{
    $outputLog += "-Waiting callbacks doesn't exist. No queue deleted. `n"
}

# Delete Data Actions
foreach ($dataAction in $dataActions) 
{
    $dataActionId = (gc.exe integrations actions list -a --category $integrationName --name $dataAction | ConvertFrom-Json) | 
                        Select-Object id -First 1 -ExpandProperty id
    if ($dataActionId)
    {
        gc.exe integrations actions delete $dataActionId
        $outputLog += "-" + $dataAction + " data action deleted. `n"
    }
    else 
    {
        $outputLog += "-" + $dataAction + " data action not found. `n"
    }
}

# Delete Outbound Campaign
$campaignId = (gc.exe outbound campaigns list -a --name "Proactive callbacks" | ConvertFrom-Json) | 
                    Select-Object id -First 1 -ExpandProperty id
if ($campaignId)
{
    $campaign = gc.exe outbound campaigns get $campaignId 
    $campaign = $campaign.Replace('"on"','"off"')
    $campaign | gc.exe outbound campaigns update $campaignId 
    Start-Sleep -s 3
    gc.exe outbound campaigns delete $campaignId
    $outputLog += "-Outbound campaign deleted. `n"
}
else 
{
    $outputLog += "-Outbound campaign not found. `n"
}

# Delete Contact List
$contactListId = (gc.exe outbound contactlists list -a --name "Proactive callbacks" | ConvertFrom-Json) | 
                        Select-Object id -First 1 -ExpandProperty id
if ($contactListId )
{
    gc.exe outbound contactlists delete $contactListId
    $outputLog += "-Contact List deleted. `n"
}
else 
{
    $outputLog += "-Contact List not found. `n"
}

# Delete Call Analysis Response
$carId = (gc.exe outbound callanalysisresponsesets list -a --name "Proactive callback" | ConvertFrom-Json) | 
                        Select-Object id -First 1 -ExpandProperty id
if ($carId )
{
    gc.exe outbound callanalysisresponsesets delete $carId
    $outputLog += "-Call analysis response deleted. `n"
}
else 
{
    $outputLog += "-Call analysis response not found. `n"
}

# Remove in-queue flow of the target Queue
$targetQueueId = (gc.exe routing queues list -a --name $targetQueueName | ConvertFrom-Json) | 
                    Select-Object id -First 1 -ExpandProperty id
$targetQueue = gc.exe routing queues get $targetQueueId | ConvertFrom-Json
$targetQueue.PSObject.Properties.Remove('queueFlow')
$targetQueueJson = $targetQueue | ConvertTo-Json -Depth 10
$targetQueueJson | gc.exe routing queues update $targetQueueId
$outputLog += "-Removed in-queue flow from configuration of: " + $targetQueueName + "`n"

# Delete Architect Flows
foreach ($flowName in $flowNames) {
    $flowId = (gc.exe flows list -a --name $flowName | ConvertFrom-Json) | 
                    Select-Object id -First 1 -ExpandProperty id
    if ($flowId)
    {
        gc.exe flows delete $flowId
        $outputLog += "-" + $flowName + " - flow deleted. `n"
    }
    else 
    {
        $outputLog += "-" + $flowName + " not found. `n"
    }
}

Write-Host "====== RESULTS =======" -ForegroundColor Green -BackgroundColor Black
Write-Output $outputLog
