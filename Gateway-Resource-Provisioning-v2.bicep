//DEfine the scope
targetScope='resourceGroup'

// Parameters
param resourceGroupLocation string = 'uksouth' // Specify the desired Azure region

param containerAppEnvName string = 'Gateway-Container-Environment-IAC' //The name of the Container App Environment
param appInsightsName string = 'gateway-iac-appinsights' // Name of the existing Application Insights instance
param serviceBusName string = 'gateway-iac-messaging'
param sqlServerName string = 'gateway-iac-sqlserver' // Unique name for SQL Server
param keyVaultName string = 'gateway-iac-keyvault'// Name of the existing Key Vault containing the secrets

param subscriptionId string = subscription().subscriptionId
param keyVaultResourceGroup string = 'gateway-resources-iac' // Resource group containing the Key Vault

param containerAppLogAnalyticsName string = 'log-${uniqueString(resourceGroup().id)}' // Unique name for the Log Analytics workspace
param sqlAdminUsername string = 'gatewaySqlAdmin' // Default SQL admin username

var tags = {
  environment: 'production'
  owner: 'Will Velida'
  application: 'lets-build-aca'
}

// Retrieve SQL admin username and password from Key Vault
resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: keyVaultName
  scope: resourceGroup(subscriptionId, keyVaultResourceGroup)
}

module sql './sql.bicep' = {
  name: 'deploySQL'
  params: {
    sqlServerName: sqlServerName
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: kv.getSecret('sqlAdminPassword')
  }
}

module logAnalyticsWithAppInsightsModule './logs.bicep' = {
  name: 'logAnalyticsWithAppInsightsDeployment'
  params: {
    location: resourceGroupLocation
    logAnalyticsWorkspaceName: 'myLogAnalyticsWorkspace'
    appInsightsName: appInsightsName
    logAnalyticsSkuName: 'PerGB2018'
    retentionInDays: 90
  }
}

//Not sure we need these but putting here just in case
//output logAnalyticsWorkspaceId string = logAnalyticsWithAppInsightsModule.outputs.logAnalyticsWorkspaceId
//output appInsightsId string = logAnalyticsWithAppInsightsModule.outputs.appInsightsId
//output appInsightsInstrumentationKey string = logAnalyticsWithAppInsightsModule.outputs.appInsightsInstrumentationKey

// Create an Azure Service Bus Namespace in the specified resource group
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: serviceBusName
  location: resourceGroupLocation
  sku: {
    name: 'Standard' // Options: 'Basic', 'Standard', or 'Premium'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: '1.2'
  }
  //dependsOn: [resourceGroupModule]
}

// Define topics to create within the namespace
var topics = [
  'newrsimessagerecieved.integrationevent'
  'newrsimessagesubmitted.integrationevent'
  'restartconsumerrequest.integrationevent'
  'rsimessagepublished.integrationevent'
  'stopconsumerrequest.integrationevent'
]

// Create each topic in the Service Bus Namespace
resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = [for topic in topics: {
  name: '${topic}'
  parent: serviceBusNamespace
  properties: {
    defaultMessageTimeToLive: 'P14D' // Example setting, adjust as necessary
  }
}]

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: containerAppLogAnalyticsName
  location: resourceGroupLocation
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

module containerApp './gat-req-api-container-app.bicep' = {
  name: 'containerAppDeployment'
  params: {
    containerAppEnvName: containerAppEnvName
    location: resourceGroupLocation
    tags: tags
    keyVaultName: keyVaultName
    appInsightsName: appInsightsName
    sqlServerName: sqlServerName
    sqlDatabaseName: 'Gateway'
    serviceBusName: serviceBusName
  }
  dependsOn: [
    kv
    sql
    logAnalyticsWithAppInsightsModule
    serviceBusNamespace
  ]
}
