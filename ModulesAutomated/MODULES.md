# Automated Swift Subsystem Migration

This automation migrates one cohesive, reusable backend **subsystem** per 15-minute cycle. A subsystem is a system-level unit with meaningful reuse value, not a single source file or helper.

- `run_module_cycle.py`: discovers source metadata, asks a fresh ChatGPT Web CLI chat to dynamically choose a subsystem candidate, supplies that candidate's full source bundle, then continues in the same exact conversation every ~3 minutes within the cycle.
- `automation_prompt.md`: subsystem-level implementation and completeness contract.
- `MODULES.json`: subsystem records and cycle history. Historical single-file ports remain recorded but are treated as reusable fragments, not proof that a whole subsystem is complete.
- `PROGRESS.md`: append-only summaries.
- `.checkpoints/`: selected subsystem, source paths, conversation ID, turn progress and last response excerpt for recovery.
- `logs/`: full per-cycle CLI request/response logs.
- `status.sh`: scheduler, process and latest-result summary.

The LaunchAgent remains on a 900-second interval. Each cycle creates one new chat; follow-up turns target that exact conversation ID. A process lock prevents overlapping cycles. The automation does not run tests/builds or perform git commits/pushes.

## Source of truth for subsystem discovery

Every cycle must inspect the actual project at `/Users/koripor/Repos/人机恋开发/tests/html-app/app1_v2.2_cloud_ver_` and dynamically identify one important cohesive subsystem from its real source structure. The canonical subsystem list is intentionally undefined; do not pre-plan or hardcode one. Existing module folders and previous results are only history/reusable fragments, not a roadmap. The inventory covers project-relative Python, JavaScript/TypeScript, HTML, CSS, and JSON source/configuration files while excluding generated/vendor/build/runtime-data directories.

## Strict backend-only policy

Frontend work is forbidden. Every cycle must select backend/server-side subsystems only, using Python backend services, API handlers, persistence, auth, integrations, background jobs, and backend infrastructure. HTML, CSS, browser-side JS/TS, UI components, visual themes/effects and frontend assets must never be migrated. The runner enforces an eligible backend Python path allowlist for selected source files; frontend files may only provide incidental context.
