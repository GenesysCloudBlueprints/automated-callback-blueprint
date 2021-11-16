<#
.Description
Deploy-ProactiveCallbacks script provisions Genesys Cloud objects for the automated-callback-blueprint.
https://github.com/GenesysCloudBlueprints/automated-callback-blueprint
#>

# Initialize the configuration data
$params = Get-Content 'config.json' | ConvertFrom-Json
$targetQueueName = $params.TargetQueue.name
$integrationName = $params.Integration.name
$edgeGroupId = $params.EdgeGroup.id
$callerIdName = $params.CallerID.name
$callerIdNumber = $params.CallerID.number

# Get the integration id where the data actions will be published under
$integrationId = (gc.exe integrations list -a | ConvertFrom-Json) | Where-Object { $_.name -eq $integrationName } | Select-Object id -ExpandProperty id

# Make sure 'No Answer' Wrap up code exists.
Write-Output '{"name":"No Answer"}' | gc.exe routing wrapupcodes create

# Load Data Actions and configure the integration category
$addContactToContactList = Get-Content './data-actions/Add-contact-to-contact-list.custom.json'
$addContactToContactList = $addContactToContactList.Replace('<integrationName>', $integrationName)
$addContactToContactList = $addContactToContactList.Replace('<integrationId>', $integrationId)
$createPlaceholderCallback = Get-Content './data-actions/Create-placeholder-callback.custom.json'
$createPlaceholderCallback = $createPlaceholderCallback.Replace('<integrationName>', $integrationName)
$createPlaceholderCallback = $createPlaceholderCallback.Replace('<integrationId>', $integrationId)
$executeWorkflow = Get-Content './data-actions/Execute-workflow.custom.json'
$executeWorkflow = $executeWorkflow.Replace('<integrationName>', $integrationName)
$executeWorkflow = $executeWorkflow.Replace('<integrationId>', $integrationId)
$getCallbacksWaiting = Get-Content './data-actions/Get-callbacks-waiting.custom.json'
$getCallbacksWaiting = $getCallbacksWaiting.Replace('<integrationName>', $integrationName)
$getCallbacksWaiting = $getCallbacksWaiting.Replace('<integrationId>', $integrationId)
$getInteractionState = Get-Content './data-actions/Get-interaction-state.custom.json'
$getInteractionState = $getInteractionState.Replace('<integrationName>', $integrationName)
$getInteractionState = $getInteractionState.Replace('<integrationId>', $integrationId)
$disconnectCallback = Get-Content './data-actions/Disconnect-callback.custom.json'
$disconnectCallback = $disconnectCallback.Replace('<integrationName>', $integrationName)
$disconnectCallback = $disconnectCallback.Replace('<integrationId>', $integrationId)

# Create and publish data actions into Genesys Cloud
$dataActionPublishBody = '{"version": 1}'
$dataAction = $addContactToContactList | gc.exe integrations actions drafts create | ConvertFrom-Json
$dataActionPublishBody | gc.exe integrations actions draft publish create $dataAction.id
$dataAction = $createPlaceholderCallback | gc.exe integrations actions drafts create | ConvertFrom-Json
$dataActionPublishBody | gc.exe integrations actions draft publish create $dataAction.id
$dataAction = $executeWorkflow | gc.exe integrations actions drafts create | ConvertFrom-Json
$dataActionPublishBody | gc.exe integrations actions draft publish create $dataAction.id
$dataAction = $getCallbacksWaiting | gc.exe integrations actions drafts create | ConvertFrom-Json
$dataActionPublishBody | gc.exe integrations actions draft publish create $dataAction.id
$dataAction = $getInteractionState | gc.exe integrations actions drafts create | ConvertFrom-Json
$dataActionPublishBody | gc.exe integrations actions draft publish create $dataAction.id
$dataAction = $disconnectCallback | gc.exe integrations actions drafts create | ConvertFrom-Json
$dataActionPublishBody | gc.exe integrations actions draft publish create $dataAction.id

# Load flow content and configure integrationName
$outboundFlow = (Get-Content './flows/Proactive callback connect.yaml').Replace('<integrationName>', $integrationName)
$inQueueFlow = (Get-Content './flows/Proactive callback offer.yaml').Replace('<integrationName>', $integrationName)
$workflow = (Get-Content './flows/Proactive callback workbin.yaml').Replace('<integrationName>', $integrationName)
$triggerProactiveCallback = (Get-Content './flows/Trigger proactive callback workflow.yaml').Replace('<integrationName>', $integrationName)

# Update targetQueueName in outbound and in-queue flows
$outboundFlow = $outboundFlow.Replace('<targetQueueName>', $targetQueueName)
$inQueueFlow = $inQueueFlow.Replace('<targetQueueName>', $targetQueueName)

# Load Campaign JSON and configure edgeGroup and caller ID.
$campaign = Get-Content 'campaign.json'
$campaign = $campaign.Replace('<edgeGroupId>', $edgeGroupId)
$campaign = $campaign.Replace('<callerIdName>', $callerIdName).Replace('<callerIdNumber>', $callerIdNumber)

# Create queue to hold callbacks then configure flows referencing it
$callbackQueue = Write-Output '{"name": "Waiting callbacks"}' | gc.exe routing queues create | ConvertFrom-Json
$inQueueFlow = $inQueueFlow.Replace('<callbackQueueId>', $callbackQueue.id)
$workflow = $workflow.Replace('<callbackQueueId>', $callbackQueue.id)

# Create contact list to receive callback requests and update campaign and workflow tokens
$contactList = gc.exe outbound contactlists create -f contactList.json | ConvertFrom-Json
$campaign = $campaign.Replace('<contactListId>', $contactList.id)
$workflow = $workflow.Replace('<contactListId>', $contactList.id)

# Write configured yaml data to temp files
$outboundFlow | Set-Content 'Proactive callback connect temp.yaml'
$inQueueFlow | Set-Content 'Proactive callback offer temp.yaml'
$workflow | Set-Content 'Proactive callback workbin temp.yaml'

# Publish the workflow and outboundCall flows
archy publish --file 'Proactive callback connect temp.yaml'
archy publish --file 'Proactive callback workbin temp.yaml'
Start-Sleep -s 10

# Get the workflow id then update the inbound flow to reference it.
$proactiveCallbackWorkbinId = gc.exe flows list --name 'Proactive callback workbin' | ConvertFrom-Json
$triggerProactiveCallback = $triggerProactiveCallback.Replace('<workflowId>', $proactiveCallbackWorkbinId.entities[0].id)
$triggerProactiveCallback | Set-Content 'Trigger proactive callback workflow temp.yaml'

# Publish the inbound and inQueue flows
archy publish --file 'Trigger proactive callback workflow temp.yaml'
archy publish --file 'Proactive callback offer temp.yaml'
Start-Sleep -s 3

# Clean up temp files
Remove-Item 'Proactive callback connect temp.yaml'
Remove-Item 'Proactive callback workbin temp.yaml'
Remove-Item 'Proactive callback offer temp.yaml'
Remove-Item 'Trigger proactive callback workflow temp.yaml'

# Create call analysis response that sends answered calls to Proactive callback offer outbound flow
$proactiveCallbackConnectId = gc.exe flows list --name 'Proactive callback connect' | ConvertFrom-Json
$callAnalysisResponse = (Get-Content 'callAnalysisResponse.json').Replace('<proactiveCallbackConnectId>', $proactiveCallbackConnectId.entities[0].id)
$callAnalysisResponseId = $callAnalysisResponse | gc.exe outbound callanalysisresponsesets create | ConvertFrom-Json
$campaign = $campaign.Replace('<callAnalysisId>', $callAnalysisResponseId.id)

# Create always running dialing campaign to dial callbacks when loaded into contact list
$campaign = $campaign | gc.exe outbound campaigns create
$campaign = $campaign.Replace("off","on")
$campaignId = $campaign | ConvertFrom-Json
$campaignId = $campaignId.id
$campaign | gc.exe outbound campaigns update $campaignId

# Update targetQueue in-queue flow to new proactive callback offer flow
$proactiveCallbackOfferId = gc.exe flows list --name 'Proactive callbacks' | ConvertFrom-Json | Select-Object -ExpandProperty entities | Select-Object id -First 1 -ExpandProperty id
$targetQueueId = gc.exe routing queues list --name $targetQueueName | ConvertFrom-Json | Select-Object -ExpandProperty entities | Select-Object id -First 1 -ExpandProperty id
$targetQueue = gc.exe routing queues get $targetQueueId | ConvertFrom-Json
if( $null -ne $targetQueue.queueFlow ) 
{
    $targetQueue.queueFlow = @{id=[String]$proactiveCallbackOfferId} 
}
else
{
    $targetQueue | Add-Member -MemberType NoteProperty -Name 'queueFlow' -Value @{id=[String]$proactiveCallbackOfferId} 
} 
$targetQueueJson = $targetQueue | ConvertTo-Json -Depth 10
$targetQueueJson | gc.exe routing queues update $targetQueueId

Write-Output 'Script Completed.'
