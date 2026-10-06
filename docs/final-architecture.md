# Final Architecture

```text
Internet
   ↓
Azure VM (Ubuntu + Nginx)
   ↓
Azure Monitor Agent + DCR
   ↓
Log Analytics / Azure Monitor Workspace
   ↓
Azure Monitor Alerts
   ↓
Action Group
   ↓
Azure Automation Runbook
   ↓
Managed Identity
   ↓
VM Run Command
   ↓
Restart Nginx
   ↓
Service + Port + HTTP Health Check
   ↓
Recovery confirmed
```
