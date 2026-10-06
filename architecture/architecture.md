# Architecture

```text
                 INTERNET
                    |
                    v
        +-----------------------+
        | Azure VM              |
        | vm-monitor-target     |
        | Ubuntu + Nginx :80    |
        +-----------+-----------+
                    |
          Azure Monitor Agent
                    |
                    v
        +-----------------------+
        | DCR / OTel Metrics    |
        +-----------+-----------+
                    |
          +---------+---------+
          |                   |
          v                   v
   Log Analytics       Azure Monitor
          |                   |
          +---------+---------+
                    |
                    v
                 ALERTS
                    |
              ACTION GROUP
                    |
                    v
          AZURE AUTOMATION
               RUNBOOK
                    |
             Managed Identity
                    |
                    v
             VM Run Command
                    |
                    v
             Restart Nginx
                    |
                    v
          Health Verification
          /       |        \
     Service    Port 80    HTTP 200
          \       |        /
             HEALTHY
                |
                v
         Recovery confirmed
```
