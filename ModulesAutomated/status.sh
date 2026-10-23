#!/bin/bash
set -u
ROOT="/Users/koripor/Repos/MLBB_MyLifeButBetter/Coding/cross-project-components/ModulesAutomated"
cd "$ROOT" || exit 1
printf '\n=== MODULE AUTOMATION STATUS ===\n'
launchctl print "gui/$(id -u)/com.mlbb.modulesautomated" 2>/dev/null | grep -E 'state =|runs =|last exit code|run interval|program =' || echo 'Scheduler not loaded'
printf '\n=== ACTIVE CYCLE ===\n'
ps -axo pid,etime,command | grep -E '[r]un_module_cycle.py|[c]hatgpt-web agent' || echo 'No cycle currently running (next interval is every 15 minutes).'
printf '\n=== LATEST RESULT SUMMARY ===\n'
cat STATUS.md 2>/dev/null || echo 'No STATUS.md yet.'
printf '\n=== RECENT PROGRESS ===\n'
tail -20 PROGRESS.md 2>/dev/null
printf '\n=== RECENT LOGS ===\n'
ls -lt logs/*.log 2>/dev/null | head -8
