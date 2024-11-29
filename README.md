# Gateway-IAC-Scripts
Infrastructure As Code Bicep Scripts for provisioning resources for the gateway demo application.

# Manually Creating the Required Existing Azure Resources
Assuming you already have an Azure Subscription. Your Azure subscription needs to have the Key Vault Administrator Role. Go to your subscription and in the menu on the left select Access control (IAM). Select "Add" in the top tabs and search for the "Key Vault Administrator", select that row and click next at the bottom of the screen. Following the prompts to add the role.

Then the following additional Resources are also required:
  - Azure Resource Group ( with the following )
     - Container App Environment
     - Managed Identity
     - Keyvault
     - Azure Redis Cache

<img src="https://github.com/user-attachments/assets/6b105fb8-8d89-4b40-abb2-ca0f64ee79bb" width="400"/>

Resource Group - If you want the scripts to run with as little editing as possible then call the Resource group "Gateway-Resources-IAC" 

The Container App Environment - I do not know of a way of simply creating a Container App Environment on its own. Therefore we need to create a Container App that propmts us to create a Container App Environment and then delete the Container App itself leaving only the Environment behind.
You can create a Container App from any DockerHub image tag e.g. attonbomb/gateway-request-api:latest
