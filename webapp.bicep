@description('Name of the App Service Plan')
param appServicePlanName string

@description('Name of the Web App')
param webAppName string

@description('Location for the Azure resources')
param location string

@description('GitHub Repository URL')
param githubRepoUrl string

@description('Branch of the GitHub repository to deploy from')
param githubBranch string = 'main'

@description('GitHub personal access token')
@secure()
param githubAccessToken string

@description('SKU for the App Service Plan')
param skuName string = 'B1'

@description('Capacity of the App Service Plan')
param skuCapacity int = 1

@description('Runtime for the Web App (e.g., "DOTNET|8.0")')
param linuxFxVersion string = 'DOTNET|8.0'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: skuName
    tier: 'Basic'
    size: skuName
    family: 'B'
    capacity: skuCapacity
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
    }
  }
}

resource sourceControl 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
  name: 'web'
  parent: webApp
  properties: {
    repoUrl: githubRepoUrl
    branch: githubBranch
    isManualIntegration: false
    deploymentRollbackEnabled: true
    isGitHubAction: true
    gitHubActionConfiguration: {
      deploymentBranch: githubBranch
      tokenSecretName: 'githubAccessToken'
    }
  }
}

// Outputs
output webAppUrl string = 'https://${webAppName}.azurewebsites.net'
output appServicePlanId string = appServicePlan.id
