# Azure Automated Server Monitoring & Self-Healing System — Complete Documentation

## 1. Architecture

```text
Internet
   |
   v
Azure VM: vm-monitor-target
Ubuntu Linux
   |
   +--> Nginx :80
   |
   +--> Azure Monitor Agent
             |
             +--> Data Collection Rules
             |
             +--> Log Analytics / Azure Monitor Workspace
                         |
                         v
                   Azure Monitor
                         |
             +-----------+-----------+
             |                       |
          Metrics                    Logs
             |                       |
             +-----------+-----------+
                         |
                         v
                       Alerts
                         |
                    Action Group
                         |
                         v
                 Azure Automation
                    Runbook
                         |
                         v
                  VM Run Command
                         |
                         v
                 Restart Nginx
                         |
                         v
                  Health Check
                         |
             +-----------+-----------+
             |                       |
          HEALTHY                 UNHEALTHY
             |                       |
        Recovery confirmed       Retry/escalate
```

---

# Phase 1 — Azure Infrastructure Setup

## 1.1 Create Resource Group

Create:

- Name: `rg-selfhealing-monitoring`
- Region: East US

Purpose: keep all project resources together so they can be managed and deleted as one unit.

## 1.2 Create Ubuntu VM

Create:

- VM name: `vm-monitor-target`
- Image: Ubuntu
- Username: `azureadmin`
- Authentication: SSH key
- Allow SSH (22)
- Allow HTTP (80)

Do not expose unnecessary ports.

## 1.3 Connect to VM

```bash
ssh azureadmin@<VM_PUBLIC_IP>
```

Verify:

```bash
hostname
uname -a
```

## 1.4 Verify networking

```bash
ss -lnt
ip addr
```

---

# Phase 2 — Linux Server and Nginx Setup

## 2.1 Update Ubuntu

```bash
sudo apt update
sudo apt upgrade -y
```

## 2.2 Install Nginx

```bash
sudo apt install nginx -y
```

Check:

```bash
sudo systemctl status nginx
```

Expected:

```text
active (running)
```

## 2.3 Create project web page

```bash
sudo nano /var/www/html/index.html
```

Use:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Azure Self-Healing Server</title>
</head>
<body>
    <h1>Azure Self-Healing Monitoring System</h1>
    <p>Server Status: ONLINE</p>
    <p>Environment: Azure</p>
    <p>Application: Nginx</p>
</body>
</html>
```

Verify locally:

```bash
curl http://127.0.0.1/
```

Verify from browser:

```text
http://<VM_PUBLIC_IP>/
```

---

# Phase 3 — Linux Failure Simulation and Troubleshooting

## 3.1 Service management

```bash
sudo systemctl status nginx
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
```

## 3.2 CPU investigation

```bash
top
uptime
nproc
```

Install test utility:

```bash
sudo apt install stress-ng -y
```

CPU test:

```bash
stress-ng --cpu 2 --timeout 60s
```

## 3.3 Memory investigation

```bash
free -h
```

Safe test:

```bash
stress-ng --vm 1 --vm-bytes 80% --timeout 3m
```

Stop:

```bash
pkill stress-ng
```

Do not intentionally consume 100% of memory.

## 3.4 Disk investigation

```bash
df -h
```

Earlier baseline was approximately 8% usage.

Safe temporary disk test:

```bash
df -h /
sudo fallocate -l 23G /var/tmp/disk-test
df -h /
sudo rm -f /var/tmp/disk-test
```

Only use the allocation size after confirming sufficient free space.

## 3.5 Processes

```bash
ps aux
ps aux | grep nginx
```

## 3.6 Network ports

```bash
sudo ss -tulpn
sudo ss -tulpn | grep :80
```

## 3.7 Nginx logs

```bash
sudo tail -20 /var/log/nginx/error.log
sudo tail -f /var/log/nginx/error.log
```

Systemd:

```bash
sudo journalctl -u nginx
sudo journalctl -u nginx --since "10 minutes ago"
```

## 3.8 Simulate Nginx failure

```bash
sudo systemctl stop nginx
sudo systemctl status nginx
curl -I http://127.0.0.1/
```

Restore:

```bash
sudo systemctl start nginx
```

---

# Phase 4 — Azure Monitoring Setup

## 4.1 Log Analytics Workspace

Create:

```text
law-selfhealing-monitoring
```

Use the same project resource group.

## 4.2 Data Collection Rule

Create:

```text
dcr-selfhealing-monitoring
```

Linux Syslog collection was configured.

Verify AMA association with the VM.

## 4.3 OpenTelemetry metrics

The VM was associated with:

```text
msvmi-eastus-vm-monitor-target
```

This DCR provides OTel performance metrics.

Important filesystem metrics:

```text
system.filesystem.usage
system.filesystem.utilization
```

The filesystem utilization metric was explicitly enabled for disk-capacity alerting.

## 4.4 Verify Azure Monitor Agent

In Log Analytics:

```kusto
Heartbeat
| where TimeGenerated > ago(10m)
| project TimeGenerated, Computer, OSType
| order by TimeGenerated desc
```

Expected:

```text
vm-monitor-target
Linux
```

---

# Phase 5 — Monitoring and Alerting

## 5.1 High CPU alert

Resource:

```text
vm-monitor-target
```

Signal:

```text
Percentage CPU
```

Settings:

- Aggregation: Average
- Operator: Greater than
- Threshold: 80
- Frequency: 1 minute
- Lookback: 5 minutes
- Severity: Sev 2
- Auto-resolve: enabled
- Action Group: `ag-selfhealing-monitoring`

Name:

```text
alert-high-cpu
```

Important: `Percentage CPU` can represent host/VM-level CPU. If Linux `top` shows high guest CPU but this alert does not trigger, verify the metric source rather than randomly changing the threshold.

## 5.2 Low memory alert

Use a guest memory metric available to the VM's monitoring configuration.

Potential metrics include:

```text
Available Memory Bytes
```

OTel memory metrics can include:

```text
system.memory.utilization
mem/available
mem/available_percent
```

Do not confuse memory utilization with disk utilization.

## 5.3 Low disk alert

Enable:

```text
system.filesystem.utilization
```

PromQL:

```text
{"system.filesystem.utilization"}
```

Alert condition:

```text
Average > 0.80
```

Frequency:

```text
1 minute
```

Lookback:

```text
5 minutes
```

Name:

```text
alert-low-disk
```

Interpretation:

```text
0.05 = 5% used
0.50 = 50% used
0.80 = 80% used
0.95 = 95% used
```

Multiple lines can represent multiple filesystems.

Do NOT use disk IOPS metrics to represent disk capacity. IOPS measures activity, not remaining space.

## 5.4 VM unavailable alert

Use the VM Availability signal:

```text
VM Availability Metric
```

Name:

```text
alert-vm-unavailable
```

The VM stop/start test can validate it.

## 5.5 Website/Nginx availability

Application Insights:

```text
appi-selfhealing-monitoring
```

Availability test:

```text
nginx-website-health
```

URL:

```text
http://<VM_PUBLIC_IP>/
```

Expected HTTP:

```text
200
```

Metric alert:

```text
nginx-website-health-appi-selfhealing-monitoring
```

Condition:

```text
Failed locations >= 2
```

This is preferable to treating the presence of an Nginx syslog error as definitive service-down detection.

Standard availability testing may incur charges; review pricing before long-term use.

## 5.6 AMA heartbeat alert

Recommended query:

```kusto
Heartbeat
| summarize LastHeartbeat=max(TimeGenerated) by Computer, _ResourceId
| extend MinutesSinceLastHeartbeat = datetime_diff('minute', now(), LastHeartbeat)
| where Computer == "vm-monitor-target"
    and MinutesSinceLastHeartbeat >= 5
```

Alternative zero-row detection:

```kusto
Heartbeat
| where Computer == "vm-monitor-target"
| where TimeGenerated > ago(5m)
| summarize HeartbeatCount = count()
| where HeartbeatCount == 0
```

Alert configuration:

- Query type: Custom log search
- Measure: Number of results
- Operator: Greater than
- Threshold: 0
- Frequency: 1 minute
- Lookback: 5 minutes
- Action Group: `ag-selfhealing-monitoring`
- Name: `alert-ama-heartbeat`
- Severity: Sev 2

---

# Phase 6 — Automated Self-Healing

## 6.1 Automation Account

Create:

```text
aa-selfhealing-monitoring
```

Enable:

```text
System-assigned Managed Identity
```

## 6.2 Runbook

Create:

```text
runbook-restart-nginx
```

Type:

```text
PowerShell
```

Runbook:

```powershell
param(
    [string]$ResourceGroup = "rg-selfhealing-monitoring",
    [string]$VMName = "vm-monitor-target"
)

Write-Output "======================================"
Write-Output "Azure Self-Healing - Nginx Remediation"
Write-Output "======================================"

Write-Output "Resource Group: $ResourceGroup"
Write-Output "VM Name: $VMName"

Write-Output "Authenticating using Managed Identity..."

Connect-AzAccount -Identity

Write-Output "Authentication successful."

Write-Output "Executing Nginx restart command..."

$result = Invoke-AzVMRunCommand `
    -ResourceGroupName $ResourceGroup `
    -VMName $VMName `
    -CommandId "RunShellScript" `
    -ScriptString "sudo systemctl restart nginx && sudo systemctl is-active nginx"

Write-Output "Run Command completed."

$result.Value | ForEach-Object {
    Write-Output $_.Message
}

Write-Output "Nginx remediation completed."
```

Save and publish the runbook before testing.

## 6.3 Why a separate remediation Action Group is recommended

The existing:

```text
ag-selfhealing-monitoring
```

is used for notifications.

Do not attach the Nginx restart runbook to that same group if CPU, memory, disk, VM and heartbeat alerts also use it.

Otherwise an unrelated CPU alert could restart Nginx.

Recommended:

```text
ag-selfhealing-monitoring
```

= notifications

```text
ag-selfhealing-nginx
```

= Nginx remediation only

The Nginx website alert can invoke both groups.

## 6.4 Intended self-healing flow

```text
Nginx stops
   ↓
Application Insights detects failed HTTP checks
   ↓
Nginx availability alert fires
   ↓
ag-selfhealing-nginx
   ↓
runbook-restart-nginx
   ↓
Managed Identity authentication
   ↓
Invoke-AzVMRunCommand
   ↓
sudo systemctl restart nginx
   ↓
health check
   ↓
HTTP 200
   ↓
alert resolves
```

---

# Phase 7 — Security and Access Control

This phase was planned but deferred because the Azure subscription did not allow the required advanced RBAC/custom-role configuration.

Do not claim custom least-privilege roles were implemented.

The project currently uses the available Azure managed identity and existing access configuration.

Future implementation:

- Managed Identity
- Least privilege
- Automation Account identity
- Monitoring Reader where appropriate
- VM Command execution permissions only where required
- No passwords stored in scripts
- No service-principal secrets in GitHub

---

# Phase 8 — Health Checks and Recovery Verification

## 8.1 Health criteria

The Nginx service is healthy only when all three pass.

### Service

```bash
systemctl is-active nginx
```

Expected:

```text
active
```

### Port

```bash
ss -lnt | grep ':80'
```

Expected: port 80 is listening.

### HTTP

```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/
```

Expected:

```text
200
```

## 8.2 Health-check script

File:

```text
scripts/nginx-health-check.sh
```

Install on VM:

```bash
sudo nano /usr/local/bin/nginx-health-check.sh
sudo chmod +x /usr/local/bin/nginx-health-check.sh
```

Script:

```bash
#!/bin/bash

echo "======================================"
echo "Nginx Health Check"
echo "======================================"

HEALTHY=true

echo ""
echo "[1] Checking Nginx service..."

if systemctl is-active --quiet nginx; then
    echo "PASS: Nginx service is active."
else
    echo "FAIL: Nginx service is not active."
    HEALTHY=false
fi

echo ""
echo "[2] Checking port 80..."

if ss -lnt | grep -q ':80 '; then
    echo "PASS: Port 80 is listening."
else
    echo "FAIL: Port 80 is not listening."
    HEALTHY=false
fi

echo ""
echo "[3] Checking HTTP response..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}"     --max-time 10     http://127.0.0.1/)

if [ "$HTTP_CODE" = "200" ]; then
    echo "PASS: HTTP response is 200."
else
    echo "FAIL: HTTP response is $HTTP_CODE."
    HEALTHY=false
fi

echo ""
echo "======================================"

if [ "$HEALTHY" = true ]; then
    echo "RESULT: HEALTHY"
    echo "======================================"
    exit 0
else
    echo "RESULT: UNHEALTHY"
    echo "======================================"
    exit 1
fi
```

Test:

```bash
sudo /usr/local/bin/nginx-health-check.sh
echo $?
```

Expected healthy exit code:

```text
0
```

Unhealthy test:

```bash
sudo systemctl stop nginx
sudo /usr/local/bin/nginx-health-check.sh
echo $?
```

Expected:

```text
RESULT: UNHEALTHY
1
```

Restore:

```bash
sudo systemctl start nginx
```

## 8.3 Recovery Runbook

File:

```text
runbooks/restart-nginx.ps1
```

Use:

```powershell
param(
    [string]$ResourceGroup = "rg-selfhealing-monitoring",
    [string]$VMName = "vm-monitor-target"
)

Write-Output "======================================"
Write-Output "Azure Self-Healing - Nginx Recovery"
Write-Output "======================================"

Write-Output "[1] Authenticating..."
Connect-AzAccount -Identity

Write-Output "[2] Restarting Nginx..."

Invoke-AzVMRunCommand `
    -ResourceGroupName $ResourceGroup `
    -VMName $VMName `
    -CommandId "RunShellScript" `
    -ScriptString "sudo systemctl restart nginx"

Write-Output "[3] Waiting for Nginx..."
Start-Sleep -Seconds 10

Write-Output "[4] Running health check..."

$healthCheckScript = @'
#!/bin/bash

HEALTHY=true

if ! systemctl is-active --quiet nginx; then
    echo "SERVICE_CHECK=FAIL"
    HEALTHY=false
else
    echo "SERVICE_CHECK=PASS"
fi

if ! ss -lnt | grep -q ':80 '; then
    echo "PORT_CHECK=FAIL"
    HEALTHY=false
else
    echo "PORT_CHECK=PASS"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}"     --max-time 10     http://127.0.0.1/)

echo "HTTP_CODE=$HTTP_CODE"

if [ "$HTTP_CODE" != "200" ]; then
    HEALTHY=false
fi

if [ "$HEALTHY" = true ]; then
    echo "HEALTH_STATUS=HEALTHY"
    exit 0
else
    echo "HEALTH_STATUS=UNHEALTHY"
    exit 1
fi
'@

$healthResult = Invoke-AzVMRunCommand `
    -ResourceGroupName $ResourceGroup `
    -VMName $VMName `
    -CommandId "RunShellScript" `
    -ScriptString $healthCheckScript

$healthOutput = $healthResult.Value.Message -join "`n"

Write-Output $healthOutput

if ($healthOutput -match "HEALTH_STATUS=HEALTHY") {
    Write-Output "RECOVERY SUCCESSFUL"
}
else {
    Write-Output "RECOVERY FAILED"
    throw "Nginx health check failed after remediation."
}
```

## 8.4 Recovery logic

The required logic is:

```text
Restart
  ↓
Wait
  ↓
Service check
  ↓
Port check
  ↓
HTTP check
  ↓
Healthy?
 ┌───────┴───────┐
Yes             No
 ↓                ↓
Success       Retry/escalate
```

---

# Phase 9 — Dashboard

Create:

```text
Self-Healing Monitoring Dashboard
```

Recommended tiles:

1. VM CPU
2. Memory
3. Filesystem utilization
4. VM availability
5. Alerts
6. Website availability

## CPU tile

VM:

```text
vm-monitor-target
```

Metric namespace:

```text
Virtual Machine Host
```

Metric:

```text
Percentage CPU
```

Aggregation:

```text
Average
```

Time range:

```text
Last 1 hour
```

Pin to the dashboard.

## Alert tile

Open:

```text
Monitor → Alerts
```

Pin the Alerts view to:

```text
Self-Healing Monitoring Dashboard
```

Do not create duplicate alert rules just to populate the dashboard.

---

# Phase 10 — Advanced Failure Testing

This phase was intentionally skipped in the final workflow because the failure scenarios had already been tested multiple times.

Previously tested scenarios included:

- CPU stress
- Memory stress
- Disk utilization
- VM availability
- Nginx failure
- Heartbeat behavior

For production use, these tests should be performed in a controlled maintenance environment.

---

# Phase 11 — GitHub and Azure Cleanup

## 11.1 GitHub repository

Recommended name:

```text
azure-self-healing-monitoring
```

Description:

```text
Automated Server Monitoring & Self-Healing System built on Microsoft Azure
```

Recommended repository structure:

```text
azure-self-healing-monitoring/
├── README.md
├── docs/
│   ├── 01-infrastructure.md
│   ├── 02-linux-nginx.md
│   ├── 03-failure-simulation.md
│   ├── 04-monitoring.md
│   ├── 05-alerting.md
│   ├── 06-self-healing.md
│   ├── 07-security.md
│   ├── 08-health-verification.md
│   ├── 09-dashboard.md
│   ├── 10-advanced-testing.md
│   ├── 11-github-and-cleanup.md
│   ├── final-architecture.md
│   └── PROJECT_DOCUMENTATION.md
├── scripts/
│   └── nginx-health-check.sh
├── runbooks/
│   └── restart-nginx.ps1
├── architecture/
│   └── architecture.md
├── screenshots/
│   └── README.md
├── .gitignore
└── LICENSE
```

## 11.2 Never commit

Do not commit:

- SSH private keys
- passwords
- Azure secrets
- client credentials
- tokens
- `.env` files
- service-principal secrets
- private screenshots containing sensitive information

## 11.3 Azure resource inventory

Before deleting:

```bash
az resource list   --resource-group rg-selfhealing-monitoring   --output table
```

Check locks:

```bash
az lock list   --resource-group rg-selfhealing-monitoring   --output table
```

Check resource group:

```bash
az group show   --name rg-selfhealing-monitoring   --output table
```

## 11.4 Delete complete resource group

Only execute after confirming nothing needs to be retained:

```bash
az group delete   --name rg-selfhealing-monitoring   --yes
```

Verify:

```bash
az group exists   --name rg-selfhealing-monitoring
```

Expected:

```text
false
```

A dashboard can be a separate Azure resource and may need separate deletion if it remains after the resource-group deletion.

---

# Phase 12 — Final Demonstration

Recommended demonstration order:

1. Show Azure architecture.
2. Show VM.
3. Open website.
4. Show Azure Monitor.
5. Show CPU/memory/disk metrics.
6. Show alert rules.
7. Stop Nginx.
8. Show website failure.
9. Show alert firing.
10. Show Automation Runbook.
11. Show remediation.
12. Show health-check output.
13. Show website recovery.
14. Show alert resolution.
15. Show GitHub repository.
16. Explain Phase 7 limitation honestly.
17. Explain cost considerations.

---

# Phase 13 — Interview Preparation

Be able to explain:

## Azure

- Resource Group
- VM
- NSG
- Managed Identity
- Azure Monitor
- Log Analytics
- Azure Monitor Agent
- DCR
- Azure Monitor Workspace
- Application Insights
- Availability Test
- Metric Alert
- Log Alert
- Action Group
- Automation Account
- Runbook

## Linux

- systemd
- Nginx
- CPU
- memory
- disk
- processes
- ports
- logs
- journalctl
- curl
- ss

## Self-healing

Explain:

```text
Detect
→ Alert
→ Trigger
→ Authenticate
→ Remediate
→ Verify
→ Recover
```

## Example interview answer

> I built an Azure-based automated server monitoring and self-healing system around an Ubuntu VM running Nginx. Azure Monitor Agent and Data Collection Rules collect monitoring data. Azure Monitor detects CPU, memory, filesystem, VM availability, heartbeat and website availability issues. Alerts trigger Action Groups, and the Nginx remediation workflow uses Azure Automation with Managed Identity and VM Run Command to restart Nginx. A health-check script verifies the service, port 80 and HTTP 200 response before declaring recovery successful.

