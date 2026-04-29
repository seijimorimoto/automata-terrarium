# verify-runner-bash-guard.ps1 — PreToolUse hook that restricts Bash commands
# inside the `verify-runner` subagent to a read-only allowlist. Best-effort:
# falls back to a no-op (allow) when verify-runner context can't be detected
# from the hook's stdin payload, so the parent /implement and other agents
# are never accidentally blocked.
#
# Reads PreToolUse hook input as JSON on stdin. Writes a JSON decision to
# stdout. On allow, output `{}` (empty decision = allow). On deny, output
# the documented Claude Code PreToolUse "block" shape.
#
# A probe of available top-level input keys is appended to
# ~/.claude/hooks/verify-runner-bash-guard/probe.log on first run so we
# can confirm whether the harness actually exposes agent-type metadata
# in this Claude Code version. The probe records keys only — never values
# — to avoid logging commands.
$ErrorActionPreference = 'Continue'   # never crash the harness; always emit a decision

$logDir   = Join-Path $HOME '.claude\hooks\verify-runner-bash-guard'
$probeLog = Join-Path $logDir 'probe.log'
$opLog    = Join-Path $logDir 'log'

if (-not (Test-Path -LiteralPath $logDir)) {
    try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch { }
}

function Write-OpLog([string]$msg) {
    try {
        $stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        Add-Content -LiteralPath $opLog -Value "$stamp $msg"
    } catch { }
}

function Write-Allow {
    # Empty decision = allow under every PreToolUse output schema variant.
    Write-Output '{}'
    exit 0
}

function Write-Deny([string]$reason) {
    # Use both the legacy and the hookSpecificOutput shapes so this works
    # across Claude Code versions. The harness ignores fields it doesn't
    # recognize.
    $payload = [ordered]@{
        decision = 'block'
        reason   = $reason
        hookSpecificOutput = [ordered]@{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $reason
        }
    }
    Write-Output ($payload | ConvertTo-Json -Depth 10 -Compress)
    exit 0
}

# Read stdin
try {
    $raw = [Console]::In.ReadToEnd()
} catch {
    Write-OpLog "stdin read failed: $($_.Exception.Message); allowing"
    Write-Allow
}

if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Allow
}

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    Write-OpLog "stdin not valid JSON; allowing"
    Write-Allow
}

# One-time probe: log the top-level keys so we know what's available
if (-not (Test-Path -LiteralPath $probeLog)) {
    try {
        $keys = @($payload.PSObject.Properties.Name) -join ', '
        Add-Content -LiteralPath $probeLog -Value "first-run keys: $keys"
    } catch { }
}

# Find tool name and command across known schema shapes
$toolName = $null
foreach ($candidate in 'tool_name','toolName','tool') {
    $v = $payload.$candidate
    if ($v) { $toolName = $v; break }
}
if ($toolName -ne 'Bash') {
    Write-Allow
}

$command = $null
$ti = $payload.tool_input
if ($null -eq $ti) { $ti = $payload.toolInput }
if ($null -ne $ti) {
    if ($ti.command) { $command = $ti.command }
    elseif ($ti.cmd) { $command = $ti.cmd }
}
if ([string]::IsNullOrWhiteSpace($command)) {
    Write-OpLog "no Bash command in payload; allowing"
    Write-Allow
}

# Detect verify-runner context. Try every plausible field.
function Test-VerifyRunner {
    param($payload)
    foreach ($candidate in 'subagent_type','subagentType','agent_name','agentName','agent','agent_type','agentType') {
        $v = $payload.$candidate
        if ($v -is [string] -and $v -ieq 'verify-runner') { return $true }
    }
    if ($payload.parent_agent -and $payload.parent_agent.name -ieq 'verify-runner') { return $true }
    if ($env:CLAUDE_SUBAGENT_TYPE -ieq 'verify-runner') { return $true }
    if ($env:CLAUDE_AGENT_NAME    -ieq 'verify-runner') { return $true }
    return $false
}

if (-not (Test-VerifyRunner $payload)) {
    # Cannot positively identify verify-runner context. Fall back to allow.
    # We log this exactly once per install so the operator knows the hook
    # is in degraded mode without flooding the log on every tool call.
    $sentinel = Join-Path $logDir '.fallback-warned'
    if (-not (Test-Path -LiteralPath $sentinel)) {
        try { Set-Content -LiteralPath $sentinel -Value 'warned' } catch { }
        Write-OpLog "FALLBACK: verify-runner context not detected in PreToolUse payload; hook is now no-op (allow). Inspect probe.log to see which keys the harness exposes."
    }
    Write-Allow
}

# We are inside verify-runner. Validate the command against the allowlist.
$allowPatterns = @(
    # Read-only git
    '^\s*git\s+diff(\s|$)',
    '^\s*git\s+log(\s|$)',
    '^\s*git\s+show(\s|$)',
    '^\s*git\s+status(\s|$)',
    '^\s*git\s+rev-parse(\s|$)',
    '^\s*git\s+ls-files(\s|$)',
    '^\s*git\s+symbolic-ref(\s|$)',
    # git branch — only without -d/-D/-m flags
    '^\s*git\s+branch(?!.*\s-(d|D|m)(\s|$))(\s.*)?$',
    # Project coverage tool reads
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

# Reject commands containing pipes-to-write, redirection that writes,
# rm/mv/cp/curl/wget — even if the leading command happens to be allowlisted.
$forbiddenSubs = @(
    '\brm\b', '\bmv\b', '\bcp\b', '\bcurl\b', '\bwget\b',
    '>\s*[^&]', '>>\s*', '\|\s*tee\b', '\bdd\b'
)
foreach ($f in $forbiddenSubs) {
    if ($command -match $f) {
        Write-Deny "verify-runner-bash-guard: command contains forbidden substring matching /$f/ -- mutating commands are blocked in verify-runner subagents."
    }
}

$matched = $false
foreach ($p in $allowPatterns) {
    if ($command -match $p) { $matched = $true; break }
}

if (-not $matched) {
    Write-Deny "verify-runner-bash-guard: command not in read-only allowlist. Allowed prefixes: read-only git (diff/log/show/status/rev-parse/ls-files/symbolic-ref/branch), coverage-tool reads (pytest --cov, vitest --coverage, jest --coverage, c8, go test -cover, dotnet test --collect, cargo tarpaulin/llvm-cov), and jq."
}

Write-Allow
