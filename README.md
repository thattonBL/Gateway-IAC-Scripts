# Gateway-IAC-Scripts
Infrastructure As Code Bicep Scripts for provisioning resources for the gateway demo application.

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
