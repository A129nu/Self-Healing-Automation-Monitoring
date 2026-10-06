param(
    [string]$ResourceGroup = "rg-selfhealing-monitoring",
    [string]$VMName = "vm-monitor-target"
)

Write-Output "======================================"
Write-Output "Azure Self-Healing - Nginx Recovery"
Write-Output "======================================"

Write-Output "[1] Authenticating using Managed Identity..."
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
