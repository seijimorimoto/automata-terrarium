# check-conventional-commits.ps1 — validate commit subjects against the Conventional Commits regex.
#
# Reads `<sha> <subject>` lines from stdin (e.g., the output of
# `git log <target>..HEAD --format='%H %s'`) and prints one JSON finding
# per non-conforming commit to stdout. Conforming commits produce no output.
#
# The recognized types default to the set listed in this repo's project instructions
# (feat fix docs refactor chore test style). Override via the env var
# CC_TYPES (space-separated list) for repos that use a different vocabulary.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$types = if ($env:CC_TYPES) { $env:CC_TYPES } else { 'feat fix docs refactor chore test style perf build ci revert' }
$typesPipe = ($types -split '\s+') -join '|'
$regex = "^($typesPipe)(\([^)]+\))?!?: .+$"
$ruleQuote = '<type>(<scope>): <short summary in imperative mood>'

while (-not [Console]::In.EndOfStream) {
    $line = [Console]::In.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $space = $line.IndexOf(' ')
    if ($space -lt 0) { continue }
    $sha     = $line.Substring(0, $space)
    $subject = $line.Substring($space + 1)
    if ($subject -notmatch $regex) {
        $finding = [ordered]@{
            tier        = 'hard_block'
            file        = $null
            line        = $null
            rule_quote  = $ruleQuote
            source_file = 'AGENTS.md'
            confidence  = 'high'
            message     = "Commit $sha has subject `"$subject`" that does not match Conventional Commits regex $regex"
        }
        $finding | ConvertTo-Json -Compress
    }
}
