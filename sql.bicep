param sqlServerName string
param location string = resourceGroup().location
param sqlAdminUsername string
//param storageAccountName string = 'gatewayiacstorage'

@secure()
param sqlAdminPassword string

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

// List of database names to create
var databaseNames = [
  'Gateway'
  'Global_Integration'
  'Gateway_GRPC'
]

// Create each SQL Database
resource sqlDatabases 'Microsoft.Sql/servers/databases@2022-02-01-preview' = [for dbName in databaseNames:{
  name: '${sqlServer.name}/${dbName}'
  location: location
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB, adjust as needed
    zoneRedundant: false
    readScale: 'Disabled'
    autoPauseDelay: -1
    requestedBackupStorageRedundancy: 'Local'
    minCapacity: 1
    isLedgerOn: false
  }
  sku: {
    name: 'S0' // Basic tier, can be changed as needed
    tier: 'Standard'
  }
  kind: 'v12.0,user,vcore,serverless'
}]

resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2022-02-01-preview' = {
  name: '${sqlServer.name}/AllowAzureServices'
  dependsOn: [
    sqlDatabases
  ]
  location: location
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}
/*
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${resourceGroup().name}-identity'
  location: resourceGroup().location
}

resource sqlRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(sqlServer.id, userAssignedIdentity.id, 'Contributor')
  scope: sqlServer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')  // Contributor role
    principalId: userAssignedIdentity.properties.principalId
  }
}

var sqlScriptContent = loadTextContent('./init.sql')

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'initializeSqlDbScript'
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  dependsOn: [
    sqlServer
    sqlDatabases
    sqlServerFirewallRule
  ]
  properties: {
    azPowerShellVersion: '7.1'
    scriptContent: '''
    # Check if the SqlServer module is already installed
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Install-Module -Name SqlServer -Force -Scope CurrentUser
    }
    
    # Import the SqlServer module
    Import-Module SqlServer

    # Define SQL connection and script content
    echo "$sqlScriptContent" > init.sql
    $serverName = '${sqlServer.name}.database.windows.net'
    $databaseName = 'Gateway-IAC'  # Explicit database name '${sqlDb.name}'
    $userName = '${sqlAdminUsername}'
    $password = '${sqlAdminPassword}'
    $sqlQuery = Get-Content -Path 'init.sql' -Raw

    Invoke-Sqlcmd -ServerInstance $serverName -Database $databaseName -Username $userName -Password $password -Query $sqlQuery
    '''
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
    storageAccountSettings: {
      storageAccountName: storageAccountName
      storageAccountKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value
    }
  }
}
*/
