# Runbook: Project rename spring-ai-fin → spring-ai-ascend

**Date:** 2026-05-12  
**Rename SHA:** see commit that adds this file  
**Author:** Chao Xing

## Summary

The project was renamed from `spring-ai-fin` to `spring-ai-ascend`. This is a full-identity rename: Maven coordinates, Java packages, module directories, Helm chart, and GitHub repository.

## What changed

| Surface | Before | After |
|---------|--------|-------|
| GitHub repo | `chaosxingxc-orion/spring-ai-fin` | `chaosxingxc-orion/spring-ai-ascend` |
| Working directory | `D:\chao_workspace\spring-ai-fin` | `D:\chao_workspace\spring-ai-ascend` |
| Maven groupId | `fin.springai` | `ascend.springai` |
| Maven parent artifactId | `spring-ai-fin-parent` | `spring-ai-ascend-parent` |
| Starter module artifactIds | `spring-ai-fin-*` | `spring-ai-ascend-*` |
| Java root package | `fin.springai.*` | `ascend.springai.*` |
| Helm chart directory | `ops/helm/spring-ai-fin/` | `ops/helm/spring-ai-ascend/` |
| Historical audit docs | `docs/delivery/`, `docs/systematic-*` | moved to `docs/archive/spring-ai-fin/` |

## One-time actions each collaborator must take after pulling

### 1. Update git remote

```bash
# If you cloned the old repo before rename:
git remote set-url origin https://github.com/chaosxingxc-orion/spring-ai-ascend.git
git fetch origin
```

GitHub installs a permanent redirect from the old URL, so pull/push still works temporarily, but update the remote to avoid relying on the redirect.

### 2. Clear stale Maven local repository cache

The old coordinates (`fin.springai:spring-ai-ascend-*:0.1.0-SNAPSHOT`) are now stale. Remove them to prevent classpath conflicts:

**Unix/macOS/WSL:**
```bash
rm -rf ~/.m2/repository/fin/springai
```

**Windows PowerShell:**
```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.m2\repository\fin\springai"
```

### 3. Rebuild under new coordinates

```bash
mvn -B -ntp clean install -DskipTests
```

This repopulates the local cache under the new `ascend.springai` coordinate tree.

### 4. Rename your local working directory (optional)

```powershell
# Windows
Rename-Item "D:\chao_workspace\spring-ai-fin" "spring-ai-ascend"
```

The working directory name doesn't affect Maven or git — this is cosmetic.

## Gate re-validation required (Rule 8)

All prior `latest_delivery_valid_sha` values in `docs/governance/architecture-status.yaml` were reset to `null` because this rename touches every hot-path file. A fresh operator-shape gate run is required at the rename SHA to restore L2+ capability eligibility. Record the new gate log under `docs/delivery/<date>-<rename-sha>.md`.

## Archive location

All delivery records and systematic remediation plan docs from the `spring-ai-fin` period are preserved byte-for-byte under:

```
docs/archive/spring-ai-fin/
  delivery/                  # all 2026-05-* delivery records
  systematic-architecture-*  # cycles 2-17 remediation plans
  architecture-review-*      # review responses
  architecture-meta-*        # meta-reflection
  deep-architecture-*        # security assessment
  ...
```

These files are read-only historical evidence. Do not edit them.
