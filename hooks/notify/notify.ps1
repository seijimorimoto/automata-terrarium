Import-Module BurntToast

$json = [Console]::In.ReadToEnd() | ConvertFrom-Json
$type = $json.notification_type
$logo = Join-Path $PSScriptRoot 'claude-logo.png'
$header = New-BTHeader -Id 'claude' -Title 'Claude Code'

switch ($type) {
    'permission_prompt' {
        New-BurntToastNotification `
            -Text 'Permission Required', 'Claude Code is waiting for your approval.' `
            -Header $header `
            -Sound Reminder `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -Urgent
    }
    'elicitation_dialog' {
        New-BurntToastNotification `
            -Text 'Question for You', 'Claude Code needs your input.' `
            -Header $header `
            -Sound Reminder `
            -AppLogo $logo `
            -SnoozeAndDismiss `
            -Urgent
    }
    'idle_prompt' {
        New-BurntToastNotification `
            -Text 'Task Complete', 'Claude Code is ready for your next prompt.' `
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
            -Text 'Claude Code', 'Claude Code needs your attention.' `
            -Header $header `
            -Sound Default `
            -SnoozeAndDismiss `
            -AppLogo $logo `
            -ExpirationTime (Get-Date).AddMinutes(15)
    }
}
