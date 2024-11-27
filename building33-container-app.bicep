@description('The name of the Container App Environment')
param containerAppEnvName string

@description('The location to deploy all my resources')
param location string

@description('The tags to apply to this resource')
param tags object

@description('The name of the Application Insights workspace')
param appInsightsName string

@description('The url of the Redis Cache')
@secure()
param redisHostUrl string

@description('The name and tag of the dockerHub image')
param dockerImage string

@description('The name of the container app in Azure')
param containerAppName string


resource env 'Microsoft.App/managedEnvironments@2023-11-02-preview' existing = {
  name: containerAppEnvName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'Gateway-IAC-Identity'
  location: location
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
        clientCertificateMode: 'ignore'
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
          name: 'azure-redis-connection'
          value: redisHostUrl
        }
        {
          name: 'app-insights-connection-string'
          value: appInsights.properties.ConnectionString
        }
      ]
      activeRevisionsMode: 'Multiple'
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
              name: 'REDIS_HOST'
              secretRef: 'azure-redis-connection'
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
