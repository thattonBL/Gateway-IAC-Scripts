# Gateway-IAC-Scripts
These are Infrastructure as Code bicep scripts for provisioning resources for the gateway demo application. Follow the steps below to setup your environment from scratch.

# Manually Creating the Required Existing Azure Resources
Assuming you already have an Azure Subscription. Your Azure subscription needs to have the Key Vault Administrator Role. Go to your subscription and in the menu on the left select Access control (IAM). Select "Add" in the top tabs and search for the "Key Vault Administrator", select that row and click next at the bottom of the screen. Following the prompts to add the role.

Within the region "UK South" the following additional Resources are also required:
  - Azure Resource Group ( with the following )
     - Container App Environment
     - Managed Identity
     - Keyvault
     - Azure Redis Cache

<img src="https://github.com/user-attachments/assets/6b105fb8-8d89-4b40-abb2-ca0f64ee79bb" width="400"/>

Resource Group - If you want the scripts to run with as little editing as possible then call the Resource group "Gateway-Resources-IAC" 

Container App Environment - I do not know of a way of simply creating a Container App Environment on its own. Therefore we need to create a Container App that propmts us to create a Container App Environment and then delete the Container App itself leaving only the Environment behind.
You can create a Container App from any DockerHub image tag e.g. attonbomb/gateway-request-api:latest

Managed Identity - Create a managed Identity and add the following Roles

![Gateway-Managed-Identity](https://github.com/user-attachments/assets/684022a1-1462-4fbe-b34b-f92d17c762e9)

Keyvault - Create a Keyvault and add a Secret (accepting the defaults) called sqlAdminPassword and provide a value.

Azure Cache for Redis - Azure Cache for Redis has to be created manually because only the Premium pricing teir allows you to provision this resource using Infrastructure as code. We want to use the "Standard" pricing tier. In the Advanced tab we Enable the Non-TLS port option and als enable the Access Keys Authentication which will prompt us to disable the Microsoft Entra Authentication. Once the resource has been created we need to get the connection string and add it to our previouslt created Keyvault. Open our Azure Redis Cache resource and go to Settings->Authentication and then the Acces Keys tab. From there we can take the Primary connection string and add it to our Keyvault as a new Secret named RedisHostUrl. The Redis Cache provides persistence for out Building 33 Mock Api application.

# Running The Scripts 
First thing we need to be clear about is that the scripts won't succeed in provisioning all the resources at the first time of asking... because some of the resources need to be created and values retrieved about those resources to allow the other resources to be correctly provisioned. It's a kind of chicken and egg situation. Fortunately the operation of provisioning these resources is idempotent which means we only recreate those thing which failed, existing successfully created resources are not recreated the second time we run the scripts.

The main script of the solution is the Gateway-Resource-Provisioning-v2.bicep this script references the other scripts in the solution which are bicep modules. Before the scripts can run successfully we need the three databases, Gateway, GRPC and Global to be created so that we can add the connection strings of these databases as secrets to our Keyvault. Beware that the connection string value will not include your password rather it will have {password} as a placeholder. Before you save the secret you need to paste the value into a text editor and replace this placeholder with the sql password you created before. See the completed list of secrets below:

![Secrets](https://github.com/user-attachments/assets/436d4c8c-977c-4bb3-8671-c3899a0850a8)

The other important file to be aware of at the point is the parameters.json file. This file defines names of resources that are going to be created by the script. The following values within this file are required to unique.
- subscriptionId  Your Azure Subscription guid ( Get this from Azure )
- serviceBusName
- sqlServerName
- keyVaultName
- redisCacheName (The name of the manually created Redis Cache )
- globalIntUiBaseUrl (Add this once the gateway-global-int-ui-iac has been successfully provisioned. Azure will create a unique host name for your services)

You may need to delete the Global Integration Api and the Global Integration UI once these final values have been added so that they are re-provisioned with the right connection string parameters to be able to talk to one another.

You will know if it is all working when you POST and message via the Gateway Request API and it appears in real-time in the Global Integration UI and also it is shown in the Building 33 Mock API when you refresh the page.
The format of the POST json for and RSI message is as follows. The "identifier" value must be unique:

{
  "message": {
    "collectionCode": "TST",
    "shelfmark": "tstMark",
    "volumeNumber": "123",
    "storageLocationCode": "33",
    "author": "Christopher James",
    "title": "A History of Yesterday",
    "publicationDate": "23-04-2024",
    "periodicalDate": "23-04-2024",
    "articleLine1": "hello",
    "articleLine2": "buddy",
    "catalogueRecordUrl": "http://some/catalog/url",
    "furtherDetailsUrl": "http://further/deets",
    "dtRequired": "23-04-2024",
    "route": "homeward bound",
    "readingRoomStaffArea": "true",
    "seatNumber": "15",
    "readingCategory": "fiction",
    "identifier": "ABC123",
    "readerName": "Herod Antipas",
    "readerType": "1",
    "operatorInformation": "Have a word",
    "itemIdentity": "The life and times of a silly boy"
  }
}

Run the script
