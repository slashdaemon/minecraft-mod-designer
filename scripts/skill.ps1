<#
.SYNOPSIS
  Install / link / inspect the minecraft-mod-designer skill in ~/.claude/skills.

.DESCRIPTION
  The repo root is the skill payload (SKILL.md + references/). This script moves it
  between the repo and the Claude Code skills directory.

    install    copy repo -> ~/.claude/skills/minecraft-mod-designer (replaces what's there)
    link       symlink repo -> that path instead (repo edits go live immediately)
    diff       report drift between repo and the installed copy
    pull       copy installed copy -> repo (capture edits made in ~/.claude)
    uninstall  remove the installed copy/link
    status     show what is currently installed
#>
[CmdletBinding()]
param(
    [ValidateSet('install', 'link', 'diff', 'pull', 'uninstall', 'status', 'help')]
    [string]$Command = 'help'
)

$ErrorActionPreference = 'Stop'

$SkillName = 'minecraft-mod-designer'
$RepoRoot  = Split-Path -Parent $PSScriptRoot
$Target    = Join-Path $env:USERPROFILE ".claude\skills\$SkillName"
$Payload   = @('SKILL.md', 'references')

function Test-Link([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Get-PayloadMap([string]$Root) {
    $map = @{}
    foreach ($entry in $Payload) {
        $path = Join-Path $Root $entry
        if (-not (Test-Path $path)) { continue }
        foreach ($file in (Get-ChildItem $path -Recurse -File)) {
            $rel = $file.FullName.Substring($Root.Length).TrimStart('\')
            $map[$rel] = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
        }
    }
    return $map
}

function Remove-Target {
    if (-not (Test-Path $Target)) { return }
    if (Test-Link $Target) {
        # Remove-Item on a directory symlink would recurse into the source; use the dir API.
        [IO.Directory]::Delete($Target, $false)
    } else {
        Remove-Item $Target -Recurse -Force -Confirm:$false
    }
}

function Invoke-Status {
    if (-not (Test-Path $Target)) {
        Write-Output "not installed: $Target"
        return
    }
    if (Test-Link $Target) {
        $dest = (Get-Item $Target -Force).Target
        Write-Output "linked: $Target -> $dest"
    } else {
        Write-Output "copied: $Target"
    }
}

function Invoke-Diff {
    if (-not (Test-Path $Target)) {
        Write-Output "not installed: $Target"
        return
    }
    if (Test-Link $Target) {
        Write-Output "linked to the repo - no drift possible"
        return
    }
    $repo      = Get-PayloadMap $RepoRoot
    $installed = Get-PayloadMap $Target
    $drift     = $false
    $keys = @($repo.Keys) + @($installed.Keys) | Sort-Object -Unique
    foreach ($key in $keys) {
        if (-not $installed.ContainsKey($key))  { Write-Output "repo only:      $key"; $drift = $true; continue }
        if (-not $repo.ContainsKey($key))       { Write-Output "installed only: $key"; $drift = $true; continue }
        if ($repo[$key] -ne $installed[$key])   { Write-Output "differs:        $key"; $drift = $true }
    }
    if (-not $drift) { Write-Output "in sync" }
}

function Invoke-Install {
    Remove-Target
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    foreach ($entry in $Payload) {
        Copy-Item (Join-Path $RepoRoot $entry) -Destination $Target -Recurse -Force
    }
    Write-Output "installed (copy): $Target"
}

function Invoke-Link {
    Remove-Target
    $parent = Split-Path -Parent $Target
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $RepoRoot | Out-Null
    } catch {
        throw "symlink failed - enable Windows Developer Mode or run elevated, or use 'install' instead. ($($_.Exception.Message))"
    }
    Write-Output "linked: $Target -> $RepoRoot"
}

function Invoke-Pull {
    if (-not (Test-Path $Target)) { throw "nothing installed at $Target" }
    if (Test-Link $Target) { Write-Output "linked to the repo - nothing to pull"; return }
    foreach ($entry in $Payload) {
        $src = Join-Path $Target $entry
        if (-not (Test-Path $src)) { continue }
        $dst = Join-Path $RepoRoot $entry
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -Confirm:$false }
        Copy-Item $src -Destination $RepoRoot -Recurse -Force
    }
    Write-Output "pulled into repo: $RepoRoot (review with git diff before committing)"
}

switch ($Command) {
    'install'   { Invoke-Install }
    'link'      { Invoke-Link }
    'diff'      { Invoke-Diff }
    'pull'      { Invoke-Pull }
    'uninstall' { Remove-Target; Write-Output "removed: $Target" }
    'status'    { Invoke-Status }
    default     { Get-Help $PSCommandPath -Detailed }
}
