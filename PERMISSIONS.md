## Workbook Deployment Permission Requirements
The minimum Azure role required to deploy this workbook is Contributor on the resource group or subscription where the workbook will reside.

## Usage (Viewing) Permissions

Reader at subscription or resource group level encompassing all servers

# Granular permissions Dashboard Tab Breakdown

Below is a breakdown of each main dashboard tab in the Arc-enabled-SQL-Dashboards solution, listing the high-level Azure resource types that are queried.  
**Reader** permission is required on each listed resource (or their resource groups/subscription) to view the data in that tab.

---

## General Tab
- **Azure resources queried:**
  - Arc-enabled SQL Server Instances  
    `microsoft.azurearcdata/sqlserverinstances`
  - Azure SQL Databases  
    `Microsoft.Sql/servers/databases`
  - SQL Managed Instances  
    `microsoft.sql/managedinstances`
- **Permission needed:**  
  Reader on the above resource types.

---

## Best Practices Assessment Tab
- **Azure resources queried:**
  - Arc-enabled SQL Server Instances  
    `microsoft.azurearcdata/sqlserverinstances`
  - Hybrid Compute Extensions (for assessment status)  
    `microsoft.hybridcompute/machines/extensions`
- **Permission needed:**  
  Reader on Arc-enabled SQL and Hybrid Compute Extensions.

---

## Licensing Tab
- **Azure resources queried:**
  - Arc-enabled SQL Server Instances  
    `microsoft.azurearcdata/sqlserverinstances`
  - Azure SQL Virtual Machines  
    `microsoft.sqlvirtualmachine/sqlvirtualmachines`
  - Azure SQL Databases  
    `Microsoft.Sql/servers/databases`
  - SQL Managed Instances  
    `microsoft.sql/managedinstances`
  - SQL Elastic Pools  
    `Microsoft.Sql/servers/elasticpools`
- **Permission needed:**  
  Reader on all above resource types.

---

## Performance Tab
- **Azure resources queried:**
  - Arc-enabled SQL Server Instances  
    `microsoft.azurearcdata/sqlserverinstances`
  - Azure Compute VMs (for OS-level performance stats)  
    `microsoft.compute/virtualmachines`
- **Permission needed:**  
  Reader on Arc-enabled SQL and Compute VM resources.

---

## Security Tab
- **Azure resources queried:**
  - Arc-enabled SQL Server Instances  
    `microsoft.azurearcdata/sqlserverinstances`
  - Defender for SQL (status property surfaced on Arc SQL resources)
- **Permission needed:**  
  Reader on Arc-enabled SQL resources (Defender for SQL info is exposed as a property).

---

## Backups Tab
- **Azure resources queried:**
  - Arc-enabled SQL Server Instances  
    `microsoft.azurearcdata/sqlserverinstances`
  - Hybrid Compute Extensions (for backup status)  
    `microsoft.hybridcompute/machines/extensions`
- **Permission needed:**  
  Reader on Arc-enabled SQL and Hybrid Compute Extensions.

---

## Availability Groups Tab
- **Azure resources queried:**
  - Arc-enabled SQL Server Instances  
    `microsoft.azurearcdata/sqlserverinstances`
  - Arc-enabled SQL Databases  
    `microsoft.azurearcdata/sqlserverinstances/databases`
- **Permission needed:**  
  Reader on Arc-enabled SQL and related databases.

---

## Summary Table

| Dashboard Tab        | Required Azure Resource Types (Reader role needed)                              |
|----------------------|--------------------------------------------------------------------------------|
| General              | Arc-enabled SQL, Azure SQL DB, SQL MI                                          |
| Best Practices       | Arc-enabled SQL, Hybrid Compute Extensions                                     |
| Licensing            | Arc-enabled SQL, Azure SQL VM, Azure SQL DB, SQL MI, SQL Elastic Pools         |
| Performance          | Arc-enabled SQL, Azure Compute VM                                              |
| Security             | Arc-enabled SQL (Defender info)                                                |
| Backups              | Arc-enabled SQL, Hybrid Compute Extensions                                     |
| Availability Groups  | Arc-enabled SQL, Arc-enabled SQL Databases                                     |
