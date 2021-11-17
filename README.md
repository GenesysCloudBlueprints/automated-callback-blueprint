#  Automate callbacks using always-running campaigns and data actions (DRAFT)

> View the full [Automated Callback Blueprint article](https://developer.mypurecloud.com/blueprints/automated-callback-blueprint/) on the Genesys Cloud Developer Center.

This Genesys Cloud Developer Blueprint explains how to configure automated callbacks using data actions to direct interactions through a series of Architect flows. The process explained in this blueprint adds calls to a workbin or holding queue and calculates the estimated wait time (EWT), timing the callback to match the time the caller would have spent on hold as closely as possible. While a caller's number waits in the holding queue, you can view it and even delete it, if necessary. To initiate the callback after the EWT, a data action adds the number to an agentless always-running outbound dialing campaign on Genesys Cloud. You can choose to have the person receiving the callback confirm that they still need help or send the call directly to an agent. By using a specially-configured holding queue for callback numbers, you can easily filter for these callbacks in reports.

![Automate callbacks using agentless, always-running Campaigns and Data Actions](blueprint/images/bpAutoCallbkOverview.png)
