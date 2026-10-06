# Azure Automated Server Monitoring & Self-Healing System

A beginner-friendly Azure infrastructure project that monitors an Ubuntu Linux VM, detects infrastructure/application failures, triggers alerts, and demonstrates automated Nginx recovery.

## Project Goal

Build this flow:

**Azure VM → Azure Monitor → Metrics/Logs → Alerts → Action Group → Automation Runbook → VM Run Command → Nginx Restart → Health Check → Recovery Verification**

The project uses:
- Microsoft Azure
- Ubuntu Linux
- Nginx
- Azure Monitor
- Azure Monitor Agent (AMA)
- Data Collection Rules (DCR)
- Log Analytics Workspace
- Azure Monitor Workspace / OpenTelemetry metrics
- Application Insights Availability Test
- Azure Monitor Alerts
- Action Groups
- Azure Automation
- Managed Identity
- PowerShell Runbook
- Linux shell health checks

## Important Project Status

- Phase 1–6: Implemented as documented.
- Phase 7: Deferred because of Azure subscription/RBAC limitations.
- Phase 8: Health-check and recovery verification implemented.
- Phase 9: Dashboard work implemented.
- Phase 10: Skipped because failure scenarios were already tested repeatedly.
- Phase 11: GitHub packaging and Azure cleanup prepared.

> Before describing the project as fully unattended self-healing, verify that the Alert → Action Group → Runbook integration has actually been tested end-to-end.

## Main Azure Resources

| Resource | Name |
|---|---|
| Resource Group | `rg-selfhealing-monitoring` |
| VM | `vm-monitor-target` |
| Linux user | `azureadmin` |
| Log Analytics Workspace | `law-selfhealing-monitoring` |
| Data Collection Rule | `dcr-selfhealing-monitoring` |
| OTel DCR | `msvmi-eastus-vm-monitor-target` |
| Application Insights | `appi-selfhealing-monitoring` |
| Automation Account | `aa-selfhealing-monitoring` |
| Nginx Runbook | `runbook-restart-nginx` |
| Notification Action Group | `ag-selfhealing-monitoring` |
| Nginx remediation Action Group | `ag-selfhealing-nginx` |
| Dashboard | `Self-Healing Monitoring Dashboard` |

## Alert Coverage

- High CPU
- Low memory
- High filesystem utilization / low free disk
- VM unavailable
- Nginx/website unavailable
- Azure Monitor Agent heartbeat missing

## Repository Structure

```text
azure-self-healing-monitoring/
├── README.md
├── docs/
├── scripts/
├── runbooks/
├── architecture/
├── screenshots/
├── .gitignore
└── LICENSE
```

See `docs/PROJECT_DOCUMENTATION.md` for the complete implementation guide.
