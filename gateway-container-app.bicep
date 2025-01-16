@description('The name of the Container App Environment')
param containerAppEnvName string

@description('The location to deploy all my resources')
param location string

@description('The tags to apply to this resource')
param tags object

@description('The name of the Application Insights workspace')
param appInsightsName string

@description('The name of the Azure Service Bus')
param serviceBusName string

@description('The name and tag of the dockerHub image')
param dockerImage string

@description('The name of the container app in Azure')
param containerAppName string

@description('The base url of the Global Int UI')
param gatewayUiBaseUrl string

@description('The base url of the Global Int API')
param gatewayApiBaseUrl string

@secure()
param sqlConnString string

resource env 'Microsoft.App/managedEnvironments@2023-11-02-preview' existing = {
  name: containerAppEnvName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-11-01' existing = {
  name: serviceBusName
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'Gateway-IAC-Identity'
  location: location
}

var serviceBusEndpoint = '${serviceBus.id}/AuthorizationRules/RootManageSharedAccessKey'
var serviceBusConnectionString = listKeys(serviceBusEndpoint, serviceBus.apiVersion).primaryConnectionString

resource containerApp 'Microsoft.App/containerApps@2023-08-01-preview' = {
  name: containerAppName
  tags: tags
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      ingress: {
        external: true
        clientCertificateMode: 'ignore'
        targetPort: 8080
        allowInsecure: false
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
          value: sqlConnString
        }
        {
          name: 'azure-service-bus-connection-string'
          value: serviceBusConnectionString
        }
        {
          name: 'app-insights-connection-string'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'client-base-url'
          value: gatewayUiBaseUrl
        }
        {
          name: 'api-base-url'
          value: gatewayApiBaseUrl
        }
      ]
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: dockerImage //'attonbomb/gateway-request-api:latest'
          env: [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'app-insights-connection-string'
            }
            {
              name: 'SQL_DB_CONNECTION_STRING'
              secretRef: 'sql-db-connection-string'
            }
            { 
              name: 'AZURE_SERVICE_BUS_CONNECTION_STRING'
              secretRef: 'azure-service-bus-connection-string'
            }
            {
              name: 'CLIENT_BASE_URL'
              secretRef: 'client-base-url'           
            }
            {
              name: 'BASE_URL'
              secretRef: 'api-base-url'           
            }
          ]
          probes: [
            {
              type: 'Liveness'
              tcpSocket: {
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              tcpSocket: {
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 20
            }
            {
              type: 'Startup'
              tcpSocket: {
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 20
            }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
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
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
}

output containerAppBaseUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
