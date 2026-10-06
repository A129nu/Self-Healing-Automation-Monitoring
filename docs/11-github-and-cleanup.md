# Phase 11 — GitHub and Azure Cleanup

Create the GitHub repository manually, upload the complete project folder, verify no secrets are present, then optionally delete the Azure resource group.

Before deletion:
```bash
az resource list --resource-group rg-selfhealing-monitoring --output table
az lock list --resource-group rg-selfhealing-monitoring --output table
az group show --name rg-selfhealing-monitoring --output table
```

Delete only after confirming:
```bash
az group delete --name rg-selfhealing-monitoring --yes
```
