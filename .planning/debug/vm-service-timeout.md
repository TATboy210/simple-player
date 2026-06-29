---
status: diagnosed
trigger: "Flutter Windows VM Service connection timeout - flutter run -d windows --profile builds but hangs at 'Connecting to the VM Service is taking longer than expected...'"
created: 2026-06-28T00:00:00Z
updated: 2026-06-28T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED - Windows Firewall "dartvm" rule blocks inbound TCP/UDP to dartvm.exe
test: Get-NetFirewallRule showed two "dartvm" rules: Inbound Block Enabled on Public profile
expecting: Removing firewall rules + killing stale dart process will fix VM Service connection
next_action: Present diagnosis and fix to user

## Symptoms

expected: `flutter run -d windows --profile` should build, launch app, and connect to VM Service for profiling/debugging
actual: Build succeeds (14.4s) but connection to VM Service times out, app may be running but not debuggable
errors: "Connecting to the VM Service is taking longer than expected..."
reproduction: Run `flutter run -d windows --profile` in D:\simple_player_flutter
started: Unknown - need to determine when this started

## Eliminated

- hypothesis: Port conflict with another Flutter process
  evidence: Existing dart process PID 20396 found, but it's from an earlier `flutter run` attempt that also hung. Ports 56031/56037 belong to Steam (PID 19788), no conflict.
  timestamp: 2026-06-28

- hypothesis: Flutter version/configuration issue
  evidence: Flutter 3.44.4 stable on Windows, all desktop tools OK, dart doctor shows Windows toolchain as green checkmark.
  timestamp: 2026-06-28

## Evidence

- timestamp: 2026-06-28
  checked: Get-NetFirewallRule for dartvm
  found: Two firewall rules "dartvm" (TCP + UDP) with Action=Block, Direction=Inbound, Enabled=True, Profile=Public. Target: D:\flutter\bin\cache\dart-sdk\bin\dartvm.exe
  implication: Windows Firewall blocks all inbound connections to dartvm.exe, preventing Flutter tooling from connecting to the VM Service on localhost

- timestamp: 2026-06-28
  checked: netstat for listening ports
  found: Ports 53000 (PID 49500), 54855 (PID 9312), 56031/56037 (PID 19788 = Steam). No port conflict with Flutter.
  implication: No port conflict. The issue is purely firewall blocking.

- timestamp: 2026-06-28
  checked: Existing dart process PID 20396
  found: dart.exe started at 23:10:56 today - likely a stale flutter run session that also hung
  implication: Should kill before retrying to avoid port contention

## Resolution

root_cause: Windows Firewall has two "dartvm" rules (TCP + UDP) blocking inbound connections to dartvm.exe. When `flutter run` launches dartvm.exe for the VM Service, it binds to a localhost port (e.g. 127.0.0.1:5xxxx). Flutter tooling then tries to connect to that port, but the firewall blocks the inbound connection, causing the "Connecting to the VM Service is taking longer than expected..." timeout.
fix: Delete the blocking firewall rules with: `netsh advfirewall firewall delete rule name="dartvm"`. Then kill the stale dart process (PID 20396) and retry `flutter run -d windows --profile`.
verification: After removing rules, flutter run should connect to VM Service within seconds.
files_changed: [] (system config, not code)
```
