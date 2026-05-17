---
level: L0
view: scenarios
status: active
authority: "Rule 74 (Linux-First Dev Environment); empirical lessons 2026-05-18"
---

# Developer Environment — Linux-First Mandate

**Canonical position**: every shell-driven operation in this repo (gates, builds,
tests, git operations, GitHub pushes, agent harnesses) MUST run on Linux —
either a native distro, or WSL2 (preferred), or WSL1 (fallback). Git Bash
for Windows is a debugging shim only; it must never be the *only* environment
a change was verified in.

## Why

Three measured findings drive this mandate.

### 1. Empirical speedup is overwhelming

Same gate (`bash gate/check_parallel.sh`), same repo, same physical host:

| Environment | Wall-clock | Per-subprocess fork cost | Speedup vs Git Bash |
|---|---|---|---|
| Git Bash for Windows | ~9–11 min | 60 ms | 1× baseline |
| WSL1 Ubuntu | ~1:30 | 13 ms | **6–7×** |
| WSL2 Ubuntu (when CPU VT-x enabled) | ~30 s estimated | ~3–5 ms | **~20×** |
| WSL2 + repo on Linux-native FS (`/home/...`) | ~10–15 s estimated | ~3–5 ms | **~40×** |

The bottleneck on Git Bash is the **Win32 process fork tax**: every `grep`,
`awk`, `sed`, `find` invocation spawns a full Win32 process at ~50–100 ms
each. Bash scripts that walk files spawn thousands of subprocesses. On Linux
the same operations are 5–20× cheaper.

Benchmark script: `gate/lib/wsl_speed_probe.sh`. Run it on any new dev host
to verify the ratio.

### 2. Git Bash hides real bugs

Running the gate in WSL1 for the first time on 2026-05-18 surfaced **two
production bugs** that had been invisible in Git Bash:

- **Windows-absolute paths in YAML** (`D:/.claude/plans/...`) — referenced
  by `architecture-status.yaml` as `l2_documents`. Rule 24 (paths must
  exist) silently passed on Windows because `D:/...` is a legal path. On
  Linux, the path doesn't resolve. Bug had been latent since PR-E1.
- **CRLF vs LF line endings in generated files** —
  `gate/build_architecture_graph.py` used `Path.write_text()` which on
  Win-native Python translates `\n` → `\r\n`. Rule 42 (graph idempotency)
  passed on Git Bash because both the on-disk graph and the rebuild were
  CRLF. In WSL, the rebuild was LF while the on-disk file (last written
  on Windows) was CRLF — every line "differed". Bug had been latent since
  the rule was introduced.

Both bugs were committed by humans + agents through multiple review cycles
and shipped to main. WSL surfaced them on the first run. CI (which runs on
ubuntu-latest) would have caught them too — but no one was running CI
locally because nobody had a Linux env. **Linux dev = honest dev.**

### 3. CI is already Linux

`.github/workflows/ci.yml` invokes `bash gate/check_parallel.sh` on
`ubuntu-latest`. Every commit is verified on Linux by CI. Local-dev
parity with CI is the lowest-friction way to catch the same class of
issues *before* push.

## Required: how to set up

### WSL2 (preferred)

1. Reboot, enter BIOS/UEFI, enable **Intel VT-x** or **AMD-V**
   (label varies: "Virtualization Technology", "SVM Mode", "AMD-V",
   "Intel VT-x"). Save & reboot.
2. From admin PowerShell: `wsl --set-default-version 2`
3. `wsl --install Ubuntu` (or your preferred distro). First boot prompts
   for username + password.
4. Clone the repo into Linux-native FS (NOT `/mnt/d/`) for best I/O:
   ```
   git clone <repo-url> ~/projects/spring-ai-ascend
   ```
5. Install dev tools inside WSL2:
   ```
   sudo apt update
   sudo apt install -y bash awk grep gawk sed python3 python3-pip jq git curl
   pip3 install pyyaml
   ```
6. Install Maven (if not present): `sudo apt install -y maven openjdk-21-jdk`
7. Run everything from inside WSL2: `cd ~/projects/spring-ai-ascend && bash gate/check_parallel.sh`

### WSL1 (fallback when BIOS VT-x cannot be enabled)

1. From admin PowerShell: `wsl --set-default-version 1`
2. `wsl --install Ubuntu --no-launch` then `wsl -d Ubuntu`
3. Same tooling install (`apt install ...`) as above.
4. Repo can stay on `/mnt/d/` — WSL1 has shared filesystem access.
5. Run with `MSYS_NO_PATHCONV=1` prefix if invoking from Git Bash:
   ```
   MSYS_NO_PATHCONV=1 wsl bash /mnt/d/chao_workspace/spring-ai-ascend/gate/check_parallel.sh
   ```

WSL1 gives ~6× speedup over Git Bash; WSL2 gives ~20×. Both eliminate the
Win-only bug class.

### Native Linux / macOS

Just clone and run. No setup needed beyond `apt install bash awk grep
sed python3 jq git maven openjdk-21-jdk` (or `brew install` equivalents).

### Git Bash for Windows

Acceptable for: one-off debugging, viewing logs, fast file edits, git
status / git log inspection.

**NOT acceptable** for: shipping commits, running the gate as "verification",
benchmarking, building generated artefacts.

If a commit was made via Git Bash, the same commit MUST also be verified
under WSL2/WSL1/Linux before push. Otherwise platform-specific bugs (like
the two surfaced 2026-05-18) silently ship.

## Required: how to verify

Before any push to `main`:

```bash
# In WSL2 (preferred) or WSL1
cd ~/projects/spring-ai-ascend   # or /mnt/d/chao_workspace/spring-ai-ascend
bash gate/check_parallel.sh      # must exit 0, GATE: PASS
bash gate/test_architecture_sync_gate.sh   # must show "Tests passed: N/N"
```

If you only verified on Git Bash, the push is incomplete. CI will run on
ubuntu-latest — discovering a regression in CI after push is wasteful for
the team and for git history.

## GitHub upload policy

`git push origin main` should originate from a Linux shell whenever
possible. Reasons:
1. Line-ending normalization — Git Bash on Windows applies `core.autocrlf`
   which can introduce CRLF into committed files even when `.gitattributes`
   declares text files should be LF. Pushing from Linux makes this a
   non-issue.
2. SSH agent / credentials — Linux SSH agent is the canonical path; the
   Windows credential manager occasionally fights with Git Bash's
   OpenSSH client.
3. Hook execution — pre-push hooks (e.g. running gate) execute under
   whatever shell is invoked; Linux execution is faster and more honest.

Acceptable exception: a `git push` of a commit that was *built and
verified* in WSL2/Linux, then pushed from any shell, is fine — the
verification is what matters, not the push transport.

## Cross-references

- Rule 74 (Linux-First Dev Environment) — this document is the canonical
  body.
- Rule 3 (eol_policy) — gate scripts must be LF. Now joined by Rule 74's
  broader policy: any generated file must be LF-only regardless of host OS.
- Rule 42 (architecture_graph_idempotent) — caught one of the two
  Linux-surfaced bugs (CRLF mismatch).
- Rule 70 (always_loaded_byte_budget) + measurement script —
  `gate/measure_always_loaded_tokens.sh` works on both platforms;
  measurements are honest only on Linux due to subprocess speed.
- `.github/workflows/ci.yml` — already enforces Linux verification on
  every push; Rule 74 codifies the policy that local dev must match.
- `gate/lib/wsl_speed_probe.sh` — benchmark to verify the speed ratio on
  any new dev host.
- ADR follow-up (W2): a formal ADR may be drafted to record this policy
  in the architecture decision record corpus.
