//DEfine the scope
targetScope='resourceGroup'

// Parameters
param resourceGroupLocation string // Specify the desired Azure region

param containerAppEnvName string //The name of the Container App Environment
param appInsightsName string // Name of the existing Application Insights instance
param serviceBusName string  
param sqlServerName string // Unique name for SQL Server
param keyVaultName string // Name of the existing Key Vault containing the secrets

param subscriptionId string 
param keyVaultResourceGroup string // Resource group containing the Key Vault

param containerAppLogAnalyticsName string // Unique name for the Log Analytics workspace
param sqlAdminUsername string // Default SQL admin username

param globalIntUiBaseUrl string

var tags = {
  environment: 'production'
  owner: 'British Library'
  application: 'Gateway'
}

// Retrieve SQL admin username and password from Key Vault
resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: keyVaultName
  scope: resourceGroup(subscriptionId, keyVaultResourceGroup)
}

module sql './sql.bicep' = {
  name: 'deploySQLDatabases'
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
var bothTopics = [
  'newrsimessagesubmitted.integrationevent'
  'rsimessagepublished.integrationevent'
]

var globalTopics = [
  'newrsimessagerecieved.integrationevent'
  'requeststatuschangedtocancelled.integrationEvent'
]

var gatewayTopics = [ 
  'stopconsumerrequest.integrationevent'
  'restartconsumerrequest.integrationevent'
]

var topics = union(bothTopics, globalTopics, gatewayTopics)

// Create each topic in the Service Bus Namespace
resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = [for topic in topics: {
  name: '${topic}'
  parent: serviceBusNamespace
  properties: {
    defaultMessageTimeToLive: 'P14D' // Example setting, adjust as necessary
  }
}]

module globalServiceBusSubscriptions './Subscriptions.bicep' = [for globtopic in globalTopics: {
  name: 'glSrvBusSubDep.${globtopic}'
  params: {
    servicebusNamespaceName: serviceBusNamespace.name
    topicName: globtopic
    subscriptions: [
      'gateway_global_integration_evts'
    ]
  }
  dependsOn: [
    serviceBusTopics
  ]
}]

module gatewayServiceBusSubscriptions './Subscriptions.bicep' = [for gatetopic in gatewayTopics: {
  name: 'gateServBusSubDeploy.${gatetopic}'
  params: {
    servicebusNamespaceName: serviceBusNamespace.name
    topicName: gatetopic
    subscriptions: [
      'gateway_integration_evts'
    ]
  }
  dependsOn: [
    serviceBusTopics
  ]
}]

module bothServiceBusSubscriptions './Subscriptions.bicep' = [for bothtopic in bothTopics: {
  name: 'bothServBusSubDeploy.${bothtopic}'
  params: {
    servicebusNamespaceName: serviceBusNamespace.name
    topicName: bothtopic
    subscriptions: [
      'gateway_integration_evts', 'gateway_global_integration_evts'
    ]
  }
  dependsOn: [
    serviceBusTopics
  ]
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

module gatewayReqApiContainerApp './gateway-container-app.bicep' = {
  name: 'gatewayReqApiContainerAppDeployment'
  params: {
    containerAppEnvName: containerAppEnvName
    location: resourceGroupLocation
    tags: tags
    appInsightsName: appInsightsName
    serviceBusName: serviceBusName
    sqlConnString: kv.getSecret('SqlDbConnectionString')
    dockerImage: 'attonbomb/gateway-request-api:latest'
    containerAppName: 'gateway-request-api-iac'
    gatewayUiBaseUrl: 'not-needed'
    gatewayApiBaseUrl: 'not-needed'
  }
  dependsOn: [
    kv
    sql
    logAnalyticsWithAppInsightsModule
    serviceBusNamespace
  ]
}

module globalIntApiContainerApp './gateway-container-app.bicep' = {
  name: 'globalIntApiContainerAppDeployment'
  params: {
    containerAppEnvName: containerAppEnvName
    location: resourceGroupLocation
    tags: tags
    appInsightsName: appInsightsName
    serviceBusName: serviceBusName
    sqlConnString: kv.getSecret('GlobalSqlDbConnectionString')
    dockerImage: 'attonbomb/gateway-global-integration-api:latest'
    containerAppName: 'gateway-global-int-api-iac'
    gatewayUiBaseUrl: globalIntUiBaseUrl
    gatewayApiBaseUrl: 'not-needed'
  }
  dependsOn: [
    gatewayReqApiContainerApp
  ]
}

module globalIntUiContainerApp './gateway-container-app.bicep' = {
  name: 'globalIntUiContainerAppDeployment'
  params: {
    containerAppEnvName: containerAppEnvName
    location: resourceGroupLocation
    tags: tags
    appInsightsName: appInsightsName
    serviceBusName: serviceBusName
    sqlConnString: 'no-db'
    dockerImage: 'attonbomb/systemadmin:latest'
    containerAppName: 'gateway-global-int-ui-iac'
    gatewayUiBaseUrl: 'not-needed'
    gatewayApiBaseUrl: globalIntApiContainerApp.outputs.containerAppBaseUrl
  }
  dependsOn: [
    globalIntApiContainerApp
  ]
}

module grpcContainerApp './gateway-container-app.bicep' = {
  name: 'grpcContainerAppDeployment'
  params: {
    containerAppEnvName: containerAppEnvName
    location: resourceGroupLocation
    tags: tags
    appInsightsName: appInsightsName
    serviceBusName: serviceBusName
    sqlConnString: kv.getSecret('GrpcSqlDbConnectionString')
    dockerImage: 'attonbomb/gatewaygrpcservice:latest'
    containerAppName: 'gateway-grpc-service-iac'
    gatewayUiBaseUrl: 'not-needed'
    gatewayApiBaseUrl: 'not-needed'
  }
  dependsOn: [
    globalIntUiContainerApp
  ]
}
