param sqlServerName string
param location string = resourceGroup().location
param sqlAdminUsername string

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
/*var databaseNames = [
  'Gateway-IAC'
  'Gateway-Global-IAC'
  'Gateway-GRPC-IAC'
]*/

// Create each SQL Database
//[for dbName in databaseNames: 
resource sqlDatabases 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  name: '${sqlServer.name}/Gateway-IAC'
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
}
//]

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${resourceGroup().name}-identity'
  location: resourceGroup().location
}

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
  properties: {
    azPowerShellVersion: '7.1'
    scriptContent: '''
    $serverName = '${sqlServer.name}.database.windows.net'
    $databaseName = '${sqlDb.name}'
    $userName = 'yourUserName'
    $password = 'yourPassword'
    $sqlQuery = Get-Content -Path './init.bicep' -Raw

    Invoke-Sqlcmd -ServerInstance $serverName -Database $databaseName -Username $userName -Password $password -Query $sqlQuery
    '''
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
  }
}
