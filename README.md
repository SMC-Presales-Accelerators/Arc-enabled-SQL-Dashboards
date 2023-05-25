# Arc-enabled-SQL-Dashboards
This repository contains queries and workbooks to build out an Azure Dashboard to view Arc-enabled SQL Servers

## Deployment
1. Launch Azure Cloud Shell ([Quickstart for Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/quickstart?tabs=azurecli))
2. Run `wget https://github.com/Onesuretng/Arc-enabled-SQL-Dashboards/releases/download/latest/arc-enabled-sql-dashboards.zip` to download the most recent release
3. `unzip arc-enabled-sql-dashboards.zip -d arc-enabled-sql-dashboards` to extract the contents to arc-enabled-sql-dashboards
4. `cd arc-enabled-sql-dashboards` to change to the directory
5. `./deploy.ps1` to run the deployment script, it will walk you through some prompts to determine where to deploy the dashboards and workbooks.
