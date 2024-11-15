@description('The name of the Container App Environment')
param containerAppEnvName string

@description('The location to deploy all my resources')
param location string

/*@description('The name of the Container Registry')
param containerRegistryName string*/

@description('The tags to apply to this resource')
param tags object

@description('The name of the Key Vault')
param keyVaultName string

@description('The name of the Application Insights workspace')
param appInsightsName string

@description('The name of the Azure Service Bus')
param serviceBusName string

@description('The name of the SQL Server')
param sqlServerName string

@description('The name of the SQL Database')
param sqlDatabaseName string

var containerAppName = 'gateway-request-api-iac'
//var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var keyVaultSecretUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource env 'Microsoft.App/managedEnvironments@2023-11-02-preview' existing = {
  name: containerAppEnvName
}

/*resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: containerRegistryName
}*/

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing =  {
  name: keyVaultName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-11-01' existing = {
  name: serviceBusName
}

resource containerApp 'Microsoft.App/containerApps@2023-08-01-preview' = {
  name: containerAppName
  tags: tags
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: true
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      /*registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          identity: 'system'
        }
      ]*/
      secrets: [
        {
          name: 'sql-db-connection-string'
          value: 'Server=tcp://${sqlServerName}.database.windows.net,1433;Initial Catalog=${sqlDatabaseName};Encrypt=true;Connection Timeout=30;'
        }
        {
          name: 'azure-service-bus-connection-string'
          value: serviceBus.properties.serviceBusEndpoint
        }
        {
          name: 'app-insights-key'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'app-insights-connection-string'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'sql-db-connection-string-kv'
          keyVaultUrl: 'https://${keyVault.name}.vault.azure.net/secrets/SqlDbConnectionString'
          identity: 'system'
        }
      ]
      activeRevisionsMode: 'Multiple'
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: 'attonbomb/gateway-request-api:latest'
          env: [
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              secretRef: 'app-insights-key'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'app-insights-connection-string'
            }
            {
              name: 'SQL_DB_CONNECTION_STRING'
              secretRef: 'sql-db-connection-string'
            }
            {
              name: 'SQL_DB_CONNECTION_KV'
              secretRef: 'sql-db-connection-string-kv'
            }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource keyVaultSecretUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerApp.id, keyVaultSecretUserRoleId)
  scope: keyVault
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: keyVaultSecretUserRoleId
    principalType: 'ServicePrincipal'
  }
}

/*resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, containerApp.id, acrPullRoleId)
  scope: acr
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: acrPullRoleId
    principalType: 'ServicePrincipal'
  }
}*/
