# Node Fault Triage — Design Notes

## Chat-based interface (Teams)

- Dedicated channel, one thread per issue
- SAs reply/react to claim
- Unclaimed after N min re-pings, then pages on-call
- Troubleshooting details shared on thread by bot
  - New drop data appends to the existing thread
- Jira tracking ticket opened by bot, linked to thread
- Thread closes only after return-to-service validation passes
- SA runs the undrain, not the bot
- Close-with-no-fault requires a reason (feeds false-positive rate)

## Triggers

- `sinfo` status is primary source of truth on what to work on
- Failed healthcheck or failed test also spawns a ticket
  - Includes nodes that Slurm still reports as idle
- Standardized drain reason strings let the agent correlate events
  - **Needs a format decision**

## AI agent input

- Send `sinfo` plus other node details to guide initial triage
- Payload includes:
  - Hostname, rack, and serial numbers
  - Healthcheck and test results
  - XIDs, ECC, and NVLink data
  - Fabric state
  - BMC SEL
  - Firmware and image versions
  - Thermal data
  - Syslog window
  - Other details from the observability system

## Agent output

- Fixed structure: fault class, severity, evidence, runbook, confidence
- Below a confidence floor it returns `UNKNOWN` rather than guessing

## Dedup

- Key = cluster + node + fault class
  - Matching open thread gets an append, not a new ticket
- Rack-level events (NVSwitch, CDU) aggregate to one parent thread
  - Otherwise, one event makes 18 tickets
- Maintenance windows suppress
- Flapping gets flagged not re-ticketed

## Transport — dead drops by FTP

- Loop kicks off / feeds the agent
- Atomic write prevents the agent from reading a partial file
  - Write to `.tmp`, then rename
  - Include a checksum
- Every collector writes a heartbeat even with nothing to report
- Missing heartbeat opens its own ticket

## Isolation — agent sends no info back to the cluster

- Agent only processes the dead drops
- State lives in the agent's own store
  - Maps node ↔ thread ↔ Jira ↔ RMA
  - Required because the cluster can't be queried
