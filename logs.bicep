// Parameters
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string
param appInsightsName string
param logAnalyticsSkuName string = 'PerGB2018' // Options: 'PerGB2018', 'Free', etc.
param retentionInDays int = 30 // Retention in days for the Log Analytics workspace (1-730)


// Resource: Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: retentionInDays
  }
  sku: {
    name: logAnalyticsSkuName
  }
}

// Resource: Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id // Link to Log Analytics workspace
  }
}

// Output
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output appInsightsId string = appInsights.id
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
