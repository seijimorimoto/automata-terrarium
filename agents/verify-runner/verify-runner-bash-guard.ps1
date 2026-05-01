# verify-runner-bash-guard.ps1 — PreToolUse hook for the verify-runner agent.
#
# Registered in agents/verify-runner/verify-runner.md's frontmatter. Because
# the harness scopes frontmatter hooks to the owning agent, this script ONLY
# runs while verify-runner is active. No detection / fallback logic needed.
#
# Reads the PreToolUse JSON payload on stdin, extracts the Bash command, and
# either returns 0 (allow) or exits 2 (block) with a reason on stderr per the
# documented Claude Code hook behavior.
$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

try {
    $payload = $raw | ConvertFrom-Json
}
catch {
    # Malformed input — don't block (allow), but emit a stderr note so the
    # operator knows. We never want a parse error to wedge the parent.
    [Console]::Error.WriteLine("verify-runner-bash-guard: stdin not valid JSON; allowing.")
    exit 0
}

$command = $null
$ti = $payload.tool_input
if ($null -ne $ti -and $ti.command) { $command = $ti.command }
if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

# Reject obvious mutating substrings even when the leading command would
# otherwise match the allowlist (e.g., `git diff && rm -rf .`).
$forbiddenSubs = @(
    '\brm\b', '\bmv\b', '\bcp\b', '\bcurl\b', '\bwget\b',
    '>\s*[^&]', '>>\s*', '\|\s*tee\b', '\bdd\b'
)
foreach ($f in $forbiddenSubs) {
    if ($command -match $f) {
        [Console]::Error.WriteLine("verify-runner-bash-guard: command contains forbidden substring matching /$f/ -- mutating commands are blocked.")
        exit 2
    }
}

# git branch with -d/-D/-m is mutating
if ($command -match '^\s*git\s+branch.*\s-(d|D|m)(\s|$)') {
    [Console]::Error.WriteLine("verify-runner-bash-guard: 'git branch -d/-D/-m' is mutating and not allowed.")
    exit 2
}

$allowPatterns = @(
    # Read-only git
    '^\s*git\s+diff(\s|$)',
    '^\s*git\s+log(\s|$)',
    '^\s*git\s+show(\s|$)',
    '^\s*git\s+status(\s|$)',
    '^\s*git\s+rev-parse(\s|$)',
    '^\s*git\s+ls-files(\s|$)',
    '^\s*git\s+symbolic-ref(\s|$)',
    '^\s*git\s+branch(\s|$)',
    # Coverage tool reads
    '^\s*pytest(\s+.*)?\s--cov(\s|$|=)',
    '^\s*vitest(\s+.*)?\s--coverage(\s|$)',
    '^\s*jest(\s+.*)?\s--coverage(\s|$)',
    '^\s*c8(\s|$)',
    '^\s*go\s+test(\s+.*)?\s-cover(profile)?(\s|=|$)',
    '^\s*dotnet\s+test(\s+.*)?\s--collect(\s|$|:)',
    '^\s*cargo\s+tarpaulin(\s|$)',
    '^\s*cargo\s+llvm-cov(\s|$)',
    # JSON tool
    '^\s*jq(\s|$)'
)

foreach ($p in $allowPatterns) {
    if ($command -match $p) { exit 0 }
}

[Console]::Error.WriteLine("verify-runner-bash-guard: command not in read-only allowlist. Allowed prefixes: read-only git (diff/log/show/status/rev-parse/ls-files/symbolic-ref/branch), coverage-tool reads (pytest --cov, vitest --coverage, jest --coverage, c8, go test -cover, dotnet test --collect, cargo tarpaulin/llvm-cov), and jq.")
exit 2
