---
description: ArduPilot and Arduino rules for multirotor projects
paths: ["**/arduino/**", "**/ardupilot/**", "**/*.param", "**/*.waypoints"]
---

# Arduino / ArduPilot Rules

## Project Types
- **Upstream fork:** Contributing to ArduPilot main repo. Follow ArduPilot's own coding standards.
  Branch from `master` (ArduPilot uses master, not main). Use ArduPilot's PR process.
- **Custom vehicle:** Your own multirotor configurations. Uses our standard workflow.

## Parameter Files (.param)
- Comment every non-default parameter explaining why it was changed
- Keep a base.param for common settings and vehicle-specific .param files for overrides
- Never commit SYSID_THISMAV values that could conflict with other vehicles on the same network
- Document firmware version when parameters were last validated

## Mission Files (.waypoints)
- Never commit mission files with real-world GPS coordinates without explicit review
- Use relative altitude (AGL) not absolute altitude
- Include a comment header with: date created, purpose, test location, firmware version

## Build Artifacts
- Never commit: *.elf, *.hex, *.bin, *.apj, build/ directories, logs/
- Flight logs (*.tlog, *.bin, *.log) are gitignored — they can be large

## Safety Rules
- When suggesting parameter changes: always note the safety implications
- Flag any parameter that affects arming, failsafes, or motor output as Critical
- Do not suggest disabling safety checks (ARMING_CHECK, FS_* parameters) without explicit user request
- Document voltage/current calibration parameters carefully

## Code Style (C++ for upstream contributions)
- Follow ArduPilot's coding standards: https://ardupilot.org/dev/docs/style-guide.html
- Use ArduPilot's HAL abstraction layer — avoid direct hardware access
