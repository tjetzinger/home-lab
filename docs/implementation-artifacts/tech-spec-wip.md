---
title: 'Belego Directory Sync'
slug: 'belego-dir-sync'
created: '2026-01-17'
status: 'review'
stepsCompleted: [1, 2, 3]
tech_stack:
  - mutagen
  - bash
files_to_modify:
  - /home/tt/Workspace/belego/mutagen.yml (create)
code_patterns:
  - mutagen.yml project file for declarative sync config
  - SSH host alias for transport (belego)
test_patterns:
  - Manual verification via file creation/modification
---

# Tech-Spec: Belego Directory Sync

**Created:** 2026-01-17

## Overview

### Problem Statement

Local edits in `/home/tt/Workspace/belego` and remote edits in the belego dev container (`/home/dev/workspace`) need to stay in sync for a seamless development workflow. Currently, there is no synchronization mechanism, requiring manual file transfers.

### Solution

Use Mutagen for two-way, real-time file synchronization between the local development directory and the belego container workspace. Mutagen is the industry-standard tool for dev container sync, used by Docker Desktop and GitHub Codespaces.

### Scope

**In Scope:**
- Install Mutagen on local machine (Linux)
- Configure sync via `mutagen.yml` project file
- Two-way, real-time synchronization
- Exclude `.git/` directory (manage git separately on each side)
- Simple startup workflow (`mutagen project start`)

**Out of Scope:**
- Syncing pilates or ai-dev containers
- Git workflow changes
- IDE/editor configuration
- systemd service (manual start is sufficient)

## Context for Development

### Codebase Patterns

- Belego dev container accessible via SSH host alias `belego` (defined in `~/.ssh/config`)
- SSH config: `192.168.2.101:2222`, user `dev`
- Container uses PVC-backed storage at `/home/dev` (20Gi)
- Remote workspace: `/home/dev/workspace/`
- Local workspace: `/home/tt/Workspace/belego/`

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `~/.ssh/config` | SSH alias `belego` → `192.168.2.101:2222` |
| `applications/dev-containers/README.md` | Dev container architecture |

### Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Tool** | Mutagen | Industry standard for dev container sync |
| **Config** | `mutagen.yml` project file | Declarative, one-command start |
| **Sync Mode** | `two-way-resolved` | Bidirectional, alpha wins on conflict |
| **Alpha** | Local (`.`) | Local machine is authoritative on conflicts |
| **Beta** | `belego:/home/dev/workspace` | Remote container via SSH |
| **Exclusions** | `.git` | Manage git separately on each side |

### Mutagen Commands Reference

```bash
# Start sync (from project directory)
cd /home/tt/Workspace/belego && mutagen project start

# Check status
mutagen project list

# Monitor in real-time
mutagen sync monitor

# Stop sync
mutagen project terminate
```

## Implementation Plan

### Tasks

- [ ] **Task 1: Install Mutagen via AUR**
  - Action: Install mutagen.io-bin package
  - Command: `yay -S mutagen.io-bin`
  - Verify: `mutagen version` returns version info

- [ ] **Task 2: Start Mutagen daemon**
  - Action: Ensure daemon is running
  - Command: `mutagen daemon start`
  - Notes: Daemon runs in background, auto-starts on first sync command if not running

- [ ] **Task 3: Verify SSH connectivity**
  - Action: Confirm SSH alias works
  - Command: `ssh belego "echo connected"`
  - Expected: Outputs "connected" without password prompt

- [ ] **Task 4: Create mutagen.yml project file**
  - File: `/home/tt/Workspace/belego/mutagen.yml`
  - Action: Create with following content:
  ```yaml
  sync:
    belego-workspace:
      alpha: "."
      beta: "belego:/home/dev/workspace"
      mode: "two-way-resolved"
      ignore:
        paths:
          - ".git"
  ```

- [ ] **Task 5: Start sync session**
  - Action: Start the project sync
  - Command: `cd /home/tt/Workspace/belego && mutagen project start`
  - Verify: `mutagen project list` shows session as "Connected"

- [ ] **Task 6: Verify bidirectional sync**
  - Action: Test local→remote sync
    - Create file locally: `echo "test" > /home/tt/Workspace/belego/test-local.txt`
    - Verify on remote: `ssh belego "cat /home/dev/workspace/test-local.txt"`
  - Action: Test remote→local sync
    - Create file remotely: `ssh belego "echo 'test' > /home/dev/workspace/test-remote.txt"`
    - Verify locally: `cat /home/tt/Workspace/belego/test-remote.txt`
  - Cleanup: Remove test files from both locations

### Acceptance Criteria

- [ ] **AC1:** Given Mutagen is installed, when `mutagen version` is run, then version info is displayed
- [ ] **AC2:** Given mutagen.yml exists in project root, when `mutagen project start` is run, then session starts without errors
- [ ] **AC3:** Given sync session is running, when a file is created locally, then it appears on remote within 5 seconds
- [ ] **AC4:** Given sync session is running, when a file is created remotely, then it appears locally within 5 seconds
- [ ] **AC5:** Given sync session is running, when a file is modified locally, then changes appear on remote within 5 seconds
- [ ] **AC6:** Given `.git` directory exists locally, when sync runs, then `.git` is NOT synced to remote
- [ ] **AC7:** Given sync session is running, when `mutagen project list` is run, then session shows "Connected" status

## Additional Context

### Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| Mutagen CLI | To install | `yay -S mutagen.io-bin` (AUR) |
| SSH access to belego | ✓ Working | Via `belego` host alias |
| Local directory | ✓ Exists | `/home/tt/Workspace/belego/` (empty) |

### Testing Strategy

**Manual Testing:**
1. Create test file locally → verify appears on remote
2. Create test file remotely → verify appears locally
3. Modify file on one side → verify change propagates
4. Create `.git` directory locally → verify NOT synced
5. Stop and restart session → verify reconnects automatically

**Monitoring:**
- Use `mutagen sync monitor` for real-time sync status
- Check `mutagen project list` for session health

### Notes

- Mutagen daemon runs in background, persists sessions across terminal closes
- Sessions survive daemon restarts
- To sync other containers later, create separate `mutagen.yml` in each project directory
- If session gets stuck, use `mutagen project terminate` then `mutagen project start`
- Conflict resolution: Local (alpha) wins - remote changes are overwritten if both sides edit same file simultaneously
