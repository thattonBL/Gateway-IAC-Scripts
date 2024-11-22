param servicebusNamespaceName string
param topicName string
param subscriptions array

resource sub 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = [for i in subscriptions: {
  name: '${servicebusNamespaceName}/${topicName}/${i}'
  properties: {
    lockDuration: 'PT5M' // Default settings for the subscription, adjust as necessary
  }
}]
