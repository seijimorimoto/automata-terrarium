Import-Module BurntToast

$json = [Console]::In.ReadToEnd() | ConvertFrom-Json
$type = $json.notification_type
$logo = Join-Path $PSScriptRoot 'claude-logo.png'
$sourceTitle = if ($json.title) { $json.title } else { 'AI Agent' }
$header = New-BTHeader -Id 'ai-agent' -Title $sourceTitle

switch ($type) {
    'permission_prompt' {
        New-BurntToastNotification `
            -Text 'Permission Required', 'An agent is waiting for your approval.' `
            -Header $header `
            -Sound Reminder `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -Urgent
    }
    'elicitation_dialog' {
        New-BurntToastNotification `
            -Text 'Question for You', 'An agent needs your input.' `
            -Header $header `
            -Sound Reminder `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -Urgent
    }
    'idle_prompt' {
        New-BurntToastNotification `
            -Text 'Task Complete', 'An agent is ready for your next prompt.' `
            -Header $header `
            -Sound IM `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -ExpirationTime (Get-Date).AddMinutes(15)
    }
    'agent_completed' {
        New-BurntToastNotification `
            -Text 'Agent Complete', 'A background agent finished.' `
            -Header $header `
            -Sound IM `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -ExpirationTime (Get-Date).AddMinutes(15)
    }
    'agent_idle' {
        New-BurntToastNotification `
            -Text 'Agent Waiting', 'A background agent is waiting for input.' `
            -Header $header `
            -Sound Reminder `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -Urgent
    }
    'shell_completed' {
        New-BurntToastNotification `
            -Text 'Shell Complete', 'A background shell command finished.' `
            -Header $header `
            -Sound IM `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -ExpirationTime (Get-Date).AddMinutes(15)
    }
    'shell_detached_completed' {
        New-BurntToastNotification `
            -Text 'Shell Complete', 'A detached shell command finished.' `
            -Header $header `
            -Sound IM `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -ExpirationTime (Get-Date).AddMinutes(15)
    }
    'auth_success' {
        New-BurntToastNotification `
            -Text 'Authentication', 'Successfully authenticated.' `
            -Header $header `
            -Silent `
            -AppLogo $logo `
            -ExpirationTime (Get-Date).AddMinutes(5)
    }
    default {
        New-BurntToastNotification `
            -Text $sourceTitle, 'An agent needs your attention.' `
            -Header $header `
            -Sound Default `
            -SnoozeAndDismiss `
            -AppLogo $logo `
            -ExpirationTime (Get-Date).AddMinutes(15)
    }
}
