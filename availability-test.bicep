@description('Location to deploy the availability test in')
param location string

@description('Name of the Application Insights instance the availability test will be shown in')
param appInsightsName string

@description('Name of the Container App the availability test is being created for')
param containerAppName string

@description('Endpoint that the availability test should check')
param testEndpoint string

@description('List of Azure locations to run the test from')
@allowed([
  'emea-au-syd-edge' // Australia East
  'latam-br-gru-edge' // Brazil South
  'us-fl-mia-edge' // Central US
  'apac-hk-hkn-azr' // East Asia
  'us-va-ash-azr' // East US
  'emea-ch-zrh-edge' // France South
  'emea-fr-pra-edge' // France Central
  'apac-jp-kaw-edge' // Japan East
  'emea-gb-db3-azr' // North Europe
  'us-il-ch1-azr' // North Central US
  'us-tx-sn1-azr' // South Central US
  'apac-sg-sin-azr' // Southeast Asia
  'emea-se-sto-edge' // UK West
  'emea-nl-ams-azr' // West Europe
  'us-ca-sjc-azr' // West US
  'emea-ru-msa-edge' // UK South
])
param testLocations array

@description('Seconds between test runs (default value is 300)')
param testFrequency int = 300

@description('Seconds until the test will timeout and fail (default value is 30)')
param testTimeout int = 30

var testName = '${containerAppName}-availability-test'

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource containerApp 'Microsoft.App/containerApps@2023-08-01-preview' existing = {
  name: containerAppName
}

resource availabilityTest 'Microsoft.Insights/webtests@2022-06-15' = {
  name: testName
  location: location
  kind: 'standard'
  tags: {
    'hidden-link:${appInsights.id}': 'Resource' // Links the test to Application Insights
  }
  properties: {
    Frequency: testFrequency
    Kind: 'standard'
    Locations: [for location in testLocations: {
      Id: location
    }]
    Name: testName
    Enabled: true
    RetryEnabled: true
    Timeout: testTimeout
    SyntheticMonitorId: testName // Unique ID for the test
    Request: {
      HttpVerb: 'GET'
      RequestUrl: 'https://${containerApp.properties.configuration.ingress.fqdn}${testEndpoint}'
    }
    ValidationRules: {
      ExpectedHttpStatusCode: 200
    }
  }
}
