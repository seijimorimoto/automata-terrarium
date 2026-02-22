# Hook to capture Azure DevOps PR creation and link to session
# This hook runs after tool execution and captures PR information

# ============================================================================
# LOGGING SETUP - Must happen first before anything else
# ============================================================================
$LogDir = Join-Path $env:USERPROFILE ".claude\logs\ado-pr"
$LogFile = Join-Path $LogDir "capture-pr-hook.log"

# Create log directory
try {
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
} catch {
    # Can't create log directory - exit silently
    Write-Host "Failed to create log directory at $LogDir. Exiting silently."
    exit 0
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    try {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$Timestamp [$Level] $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
    } catch { }
}

# ============================================================================
# SCRIPT START
# ============================================================================
Write-Log "=========================================", "INFO"
Write-Log "capture-pr-hook started", "INFO"
Write-Log "PS Version: $($PSVersionTable.PSVersion)", "INFO"
Write-Log "Script Path: $PSScriptRoot", "INFO"

# ============================================================================
# READ STDIN - Use $input automatic variable (works when piped)
# ============================================================================
$InputString = ""

try {
    Write-Log "Reading stdin via `$input...", "INFO"
    
    # $input is an automatic variable that contains piped input
    # It only works when data is actually piped to the script
    $InputString = @($input) -join "`n"
    
    Write-Log "Read $($InputString.Length) characters from stdin", "INFO"
} catch {
    Write-Log "Error reading stdin: $($_.Exception.Message)", "ERROR"
}

# Check if we got any input
if ([string]::IsNullOrWhiteSpace($InputString)) {
    Write-Log "No input received - exiting", "INFO"
    Write-Log "=========================================", "INFO"
    exit 0
}

# ============================================================================
# PARSE JSON
# ============================================================================
try {
    $InputData = $InputString | ConvertFrom-Json
    Write-Log "JSON parsed successfully from input", "INFO"
} catch {
    Write-Log "Failed to parse JSON from input: $($_.Exception.Message)", "ERROR"
    Write-Log "=========================================", "INFO"
    exit 0
}

# Extract fields
$SessionId = $InputData.session_id
$ToolName = $InputData.tool_name
$Command = $InputData.tool_input.command
$ToolOutput = $InputData.tool_response

Write-Log "Session: $SessionId", "INFO"
Write-Log "Tool: $ToolName", "INFO"
Write-Log "Command: $Command", "INFO"

# ============================================================================
# FILTER: Only process Bash commands with 'az repos pr create'
# ============================================================================
if ($ToolName -ne "Bash") {
    Write-Log "Tool '$ToolName' is not Bash - skipping", "INFO"
    Write-Log "=========================================", "INFO"
    exit 0
}

if (-not $Command -or $Command -notmatch "az repos pr create") {
    Write-Log "Command is not 'az repos pr create' - skipping", "INFO"
    Write-Log "=========================================", "INFO"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($ToolOutput)) {
    Write-Log "No tool output - skipping", "INFO"
    Write-Log "=========================================", "INFO"
    exit 0
}

Write-Log "PR creation detected! Processing...", "INFO"

# ============================================================================
# PARSE PR INFO FROM AZURE CLI OUTPUT
# ============================================================================
try {
    # Log the type and content of tool_response for debugging
    $ToolOutputType = $ToolOutput.GetType().Name
    Write-Log "ToolOutput type: $ToolOutputType", "INFO"
    
    # The tool_response is a PSCustomObject with stdout, stderr, interrupted, isImage
    # The actual PR JSON is in the stdout property
    if ($ToolOutput -is [PSCustomObject] -and $ToolOutput.stdout) {
        Write-Log "Extracting stdout from tool_response", "INFO"
        $StdoutContent = $ToolOutput.stdout
        
        # Azure CLI sometimes appends warnings to stdout - strip them
        # Look for the JSON object (starts with {) and extract just that part
        if ($StdoutContent -match '(?s)^(\{.*\})') {
            $StdoutContent = $Matches[1]
            Write-Log "Extracted JSON from stdout (stripped warnings)", "INFO"
        }
        
        # Parse the stdout JSON string to get PR info
        $PrInfo = $StdoutContent | ConvertFrom-Json
        Write-Log "Parsed PR info from stdout", "INFO"
    } else {
        Write-Log "Unexpected ToolOutput format: $ToolOutputType", "ERROR"
        Write-Log "=========================================", "INFO"
        exit 0
    }
    
    # Extract PR ID and URL
    $PrId = $PrInfo.pullRequestId
    $PrUrl = $PrInfo.url
    
    Write-Log "PR ID: $PrId", "INFO"
    Write-Log "PR URL: $PrUrl", "INFO"
    
    if (-not $PrId -or $PrId -eq "null") {
        Write-Log "Could not extract PR ID from output", "ERROR"
        Write-Log "=========================================", "INFO"
        exit 0
    }
    
    # Get repository info
    $RepoUrl = git config --get remote.origin.url 2>$null
    if (-not $RepoUrl) { $RepoUrl = "unknown" }
    
    $RepoName = [System.IO.Path]::GetFileNameWithoutExtension($RepoUrl)
    if (-not $RepoName) { $RepoName = "unknown" }
    
    $Branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $Branch) { $Branch = "unknown" }
    
    Write-Log "Repo: $RepoName, Branch: $Branch", "INFO"
    
    # ============================================================================
    # SAVE TO SESSION DATABASE
    # ============================================================================
    $DbPath = Join-Path $env:USERPROFILE ".claude\ado-pr-sessions.json"
    
    # Initialize database if needed
    if (-not (Test-Path $DbPath)) {
        '{}' | Set-Content -Path $DbPath -Encoding utf8
    }
    
    # Read existing database
    try {
        $DbContent = Get-Content -Path $DbPath -Raw -ErrorAction Stop
        $Db = $DbContent | ConvertFrom-Json
    } catch {
        Write-Log "Failed to read DB, creating new", "WARN"
        $Db = @{}
    }
    
    # Convert to hashtable
    $DbHash = @{}
    if ($Db) {
        $Db.PSObject.Properties | ForEach-Object {
            $DbHash[$_.Name] = $_.Value
        }
    }
    
    # Ensure repository entry exists
    if (-not $DbHash.ContainsKey($RepoName)) {
        $DbHash[$RepoName] = @{}
    }
    
    # Convert repo entry to hashtable if needed
    if ($DbHash[$RepoName] -is [PSCustomObject]) {
        $RepoHash = @{}
        $DbHash[$RepoName].PSObject.Properties | ForEach-Object {
            $RepoHash[$_.Name] = $_.Value
        }
        $DbHash[$RepoName] = $RepoHash
    }
    
    # Add PR entry
    $DbHash[$RepoName][$PrId.ToString()] = @{
        session_id = $SessionId
        pr_url = $PrUrl
        branch = $Branch
        repository_url = $RepoUrl
        created_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    # Save database
    $DbHash | ConvertTo-Json -Depth 10 | Set-Content -Path $DbPath -Encoding utf8
    
    Write-Log "SUCCESS: Linked PR #$PrId to session $SessionId", "INFO"
    Write-Host "[OK] Linked PR #$PrId to session $SessionId" -ForegroundColor Green
    
} catch {
    Write-Log "Error processing PR info: $($_.Exception.Message)", "ERROR"
}

Write-Log "=========================================", "INFO"
exit 0
