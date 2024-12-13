// Define the scope
targetScope='resourceGroup'

// Parameters see parameters.json for values
param resourceGroupLocation string // Specify the desired Azure region
param containerAppEnvName string //The name of the Container App Environment
param appInsightsName string // Name of the existing Application Insights instance
param serviceBusName string // Name of the service Bus
param sqlServerName string // Unique name for SQL Server
param keyVaultName string // Name of the existing Key Vault containing the secrets
param subscriptionId string // Dynamically retrieved
param keyVaultResourceGroup string // Resource group containing the Key Vault
param containerAppLogAnalyticsName string // Unique name for the Log Analytics workspace
param sqlAdminUsername string // Default SQL admin username
param globalIntUiBaseUrl string
param redisCacheName string // Name of the Redis Cache instance
param b33MockApiName string // Name for the B33 Mock API container app
param gatewayReqApiName string // Name for the Gateway Request API container app
param globalIntApiName string // Name for the Global Integration API container app
param globalIntUiName string // Name for the Global Integration UI container app
param grpcServiceName string // Name for the GRPC service container app

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

// Creates the SQL Server and the three named databses
module sql './sql.bicep' = {
  name: 'deploySQLDatabases'
  params: {
    sqlServerName: sqlServerName
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: kv.getSecret('sqlAdminPassword')
  }
}

// Create a Log Analytics workspace with Application Insights
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

//Not deleting these just in case they are needed later
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
}

// Define topics to create within the namespace
//Topics used by both subscriptions
var bothTopics = [
  'newrsimessagesubmitted.integrationevent'
  'rsimessagepublished.integrationevent'
]

// Topics used only by the global Subscription
var globalTopics = [
  'newrsimessagerecieved.integrationevent'
  'requeststatuschangedtocancelled.integrationEvent'
]

// Topics used only by the gateway Subscription
var gatewayTopics = [ 
  'stopconsumerrequest.integrationevent'
  'restartconsumerrequest.integrationevent'
]

// Concatenate all topics
var topics = union(bothTopics, globalTopics, gatewayTopics)

// Create each topic in the Service Bus Namespace
resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = [for topic in topics: {
  name: '${topic}'
  parent: serviceBusNamespace
  properties: {
    defaultMessageTimeToLive: 'P14D' // Example setting, adjust as necessary
  }
}]

// Add Subcriptions for topics that require global only
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

// Add Subcriptions for topics that require gateway only
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

// Add Subcriptions for topics that require both
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

// Create a Log Analytics workspace for the container apps
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: containerAppLogAnalyticsName
  location: resourceGroupLocation
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Reference to the existing Redis Cache instance
resource redisCache 'Microsoft.Cache/Redis@2023-08-01' existing = {
  name: redisCacheName
}

// Create the Building 33 Mock API Container App
module build33ContainerApp './building33-container-app.bicep' = {
  name: 'building33ContainerAppDeployment'
  params: {
    containerAppName: b33MockApiName
    tags: tags
    location: resourceGroupLocation
    containerAppEnvName: containerAppEnvName
    appInsightsName: appInsightsName
    redisHostUrl: kv.getSecret('RedisHostUrl')
    dockerImage: 'attonbomb/building33mockapi:latest'
  }
  dependsOn: [
    redisCache
    logAnalyticsWithAppInsightsModule
  ]
}

// Create the Gateway Request API Container App
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
    containerAppName: gatewayReqApiName
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

// Create the Global Integration API Container App
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
    containerAppName: globalIntApiName
    gatewayUiBaseUrl: globalIntUiBaseUrl
    gatewayApiBaseUrl: 'not-needed'
  }
  dependsOn: [
    gatewayReqApiContainerApp
  ]
}

// Create the Global Integration UI Container App
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
    containerAppName: globalIntUiName
    gatewayUiBaseUrl: 'not-needed'
    gatewayApiBaseUrl: globalIntApiContainerApp.outputs.containerAppBaseUrl
  }
  dependsOn: [
    globalIntApiContainerApp
  ]
}

// Create the Gateway GRPC Service Container App
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
    containerAppName: grpcServiceName
    gatewayUiBaseUrl: build33ContainerApp.outputs.containerAppBaseUrl
    gatewayApiBaseUrl: 'not-needed'
  }
  dependsOn: [
    build33ContainerApp
    globalIntUiContainerApp
  ]
}

// List of all the applications to create availability tests for
var availabilityTestApps = [
  b33MockApiName
  gatewayReqApiName
  globalIntApiName
  grpcServiceName
]

// Create an availability test for each application in the list
module availabilityTests './availability-test.bicep' = [for app in availabilityTestApps: {
  name: 'availability-test-${app}'
  params: {
    location: resourceGroupLocation
    appInsightsName: appInsightsName
    containerAppName: app
    testEndpoint: '/health'
    testLocations: [
      'emea-ru-msa-edge' // UK South
    ]
  }
  dependsOn: [
    build33ContainerApp
    gatewayReqApiContainerApp
    globalIntApiContainerApp
    grpcContainerApp
  ]
}]
