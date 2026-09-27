#Requires -Version 5.1
<#
  install.ps1 — link agent-config into Claude Code, OpenCode, Command Code, and/or pi
  on native Windows (no WSL required). Creates NTFS symlinks; the canonical
  files stay in this folder (or wherever this script lives).

  Memory file locations (official docs):
    Claude Code   %USERPROFILE%\.claude\CLAUDE.md
    OpenCode      %USERPROFILE%\.config\opencode\AGENTS.md
    Command Code  %USERPROFILE%\.commandcode\AGENTS.md
    pi            %USERPROFILE%\.pi\agent\AGENTS.md

  Skills locations (official docs):
    Claude Code   %USERPROFILE%\.claude\skills\
    OpenCode      %USERPROFILE%\.config\opencode\skills\
    Command Code  %USERPROFILE%\.commandcode\skills\
    pi            %USERPROFILE%\.pi\agent\skills\

  Config file locations (official docs):
    Claude Code   %USERPROFILE%\.claude\settings.json
    OpenCode      %USERPROFILE%\.config\opencode\opencode.json
    Command Code  %USERPROFILE%\.commandcode\settings.json
    pi            %USERPROFILE%\.pi\agent\settings.json
    pi npm manifest: %USERPROFILE%\.pi\agent\npm\package.json (from pi\package.json)

  Symlinks need Developer Mode or an elevated shell on Windows. When that
  privilege is missing, skill directories fall back to junctions (still no
  copies, and no admin needed); the memory file link still requires it.
  Enable it under: Settings > Privacy & security > For developers.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\install.ps1          interactive
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Check   dry run (no changes)
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -All -Force
    .\install.ps1 -Agent claude-code,opencode
#>

param(
    [switch]$Force,    # replace existing files/symlinks without asking
    [switch]$Check,    # dry run: show what would be installed, change nothing
    [switch]$All,      # skip the interactive selection, configure all agents
    [string[]]$Agent   # restrict to specific agents by id or label
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$MemorySrc  = Join-Path $ScriptRoot 'AGENTS.md'

$Agents = @(
    [PSCustomObject]@{ Id = 'claude-code';  Label = 'Claude Code';  MemoryDir = "$env:USERPROFILE\.claude";          MemoryName = 'CLAUDE.md'; SkillsDir = "$env:USERPROFILE\.claude\skills"; ConfigSrc = 'claude-code\settings.json'; ConfigDest = "$env:USERPROFILE\.claude\settings.json" },
    [PSCustomObject]@{ Id = 'opencode';     Label = 'OpenCode';     MemoryDir = "$env:USERPROFILE\.config\opencode"; MemoryName = 'AGENTS.md'; SkillsDir = "$env:USERPROFILE\.config\opencode\skills"; ConfigSrc = 'opencode\opencode.json'; ConfigDest = "$env:USERPROFILE\.config\opencode\opencode.json" },
    [PSCustomObject]@{ Id = 'command-code'; Label = 'Command Code'; MemoryDir = "$env:USERPROFILE\.commandcode";     MemoryName = 'AGENTS.md'; SkillsDir = "$env:USERPROFILE\.commandcode\skills"; ConfigSrc = 'command-code\settings.json'; ConfigDest = "$env:USERPROFILE\.commandcode\settings.json" },
    [PSCustomObject]@{ Id = 'pi';           Label = 'pi';           MemoryDir = "$env:USERPROFILE\.pi\agent";        MemoryName = 'AGENTS.md'; SkillsDir = "$env:USERPROFILE\.pi\agent\skills"; ConfigSrc = 'pi\settings.json'; ConfigDest = "$env:USERPROFILE\.pi\agent\settings.json" }
)

# Whether the current user may create real symlinks: admin, or Developer Mode on.
function Test-SymlinkPrivilege {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) { return $true }
    try {
        $unlock = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction Stop
        return ($unlock.AllowDevelopmentWithoutDevLicense -eq 1)
    } catch {
        return $false
    }
}

function Confirm-Yn {
    param([string]$Prompt)
    $ans = Read-Host "$Prompt [y/N]"
    return ($ans -match '^y')
}

function Select-Agents {
    while ($true) {
        Write-Host 'Install for which agents?'
        for ($i = 0; $i -lt $Agents.Count; $i++) {
            Write-Host ('  {0}) {1}' -f ($i + 1), $Agents[$i].Label)
        }
        Write-Host '  a) All agents'
        Write-Host '  (empty = install nothing)'
        $input = Read-Host '> '
        if ($input -match '^a') { return @($Agents) }
        if ([string]::IsNullOrWhiteSpace($input)) { return @() }

        $idxs = @()
        $ok = $true
        foreach ($token in ($input -split '[\s,]+')) {
            if ([string]::IsNullOrWhiteSpace($token)) { continue }
            if ($token -match '^\d+$') {
                $n = [int]$token
                if ($n -ge 1 -and $n -le $Agents.Count) {
                    $idxs += $Agents[$n - 1]
                } else {
                    Write-Host "  Invalid selection: $token"
                    $ok = $false
                    break
                }
            } else {
                Write-Host "  Invalid selection: $token"
                $ok = $false
                break
            }
        }
        if ($ok) { return @($idxs | Select-Object -Unique) }
    }
}

function Set-Link {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Dest,
        [switch] $IsDirectory,
        [bool] $CanSymlink
    )

    if ($Check) {
        if (Test-Path -LiteralPath $Dest) {
            $existing = Get-Item -LiteralPath $Dest -Force
            if ($existing.LinkType -and ($existing.Target | Select-Object -First 1) -eq $Source) {
                Write-Host "  already linked: $Dest"
                return
            }
        }
        Write-Host "  would link $Dest -> $Source"
        return
    }

    if (Test-Path -LiteralPath $Dest) {
        $existing = Get-Item -LiteralPath $Dest -Force
        if ($existing.LinkType) {
            $target = $existing.Target | Select-Object -First 1
            if ($target -eq $Source) {
                Write-Host "  already linked: $Dest"
                return
            }
            if ($Force -or (Confirm-Yn "  Replace existing link $Dest (currently -> $target)?")) {
                Remove-Item -LiteralPath $Dest -Force
            } else {
                Write-Host "  skipped $Dest"
                return
            }
        } else {
            if ($Force -or (Confirm-Yn "  $Dest already exists. Back it up and link?")) {
                $backup = "$Dest.backup-$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
                Move-Item -LiteralPath $Dest -Destination $backup
                Write-Host "  backed up to $backup"
            } else {
                Write-Host "  skipped $Dest"
                return
            }
        }
    }

    $parent = Split-Path -Parent $Dest
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ($IsDirectory -and -not $CanSymlink) {
        New-Item -ItemType Junction -Path $Dest -Target $Source | Out-Null
        Write-Host "  linked $Dest -> $Source (junction: no admin required)"
        return
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Dest -Target $Source | Out-Null
        Write-Host "  linked $Dest -> $Source"
    } catch {
        if ($IsDirectory) {
            New-Item -ItemType Junction -Path $Dest -Target $Source -ErrorAction Stop | Out-Null
            Write-Host "  linked $Dest -> $Source (junction fallback)"
        } else {
            Write-Host "  could not create symlink: $Dest -> $Source"
            Write-Host '  Enable Developer Mode (Settings > Privacy & security > For developers) or re-run in an elevated PowerShell.'
        }
    }
}

# --- gather skills ------------------------------------------------------------

$Skills = @(
    Get-ChildItem -Path (Join-Path $ScriptRoot 'skills') -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
        ForEach-Object { $_.FullName }
)

# --- main ---------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $MemorySrc -PathType Leaf)) {
    Write-Host "Error: memory file not found: $MemorySrc"
    exit 1
}

Write-Host "agent-config: $ScriptRoot"
Write-Host "memory file:  $MemorySrc"
if ($Skills.Count -gt 0) {
    Write-Host ('skills:       {0}' -f (($Skills | ForEach-Object { Split-Path $_ -Leaf }) -join ' '))
} else {
    Write-Host 'skills:       (none)'
}
$piSrcDir = Join-Path $ScriptRoot 'pi'
if (Test-Path -LiteralPath $piSrcDir -PathType Container) {
    $names = @(Get-ChildItem -LiteralPath $piSrcDir -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('package.json', 'settings.json') } |
        ForEach-Object { $_.Name })
    if ($names.Count -gt 0) {
        Write-Host ('pi extra:     {0} (mirrored)' -f ($names -join ' '))
    } else {
        Write-Host 'pi extra:     (none)'
    }
} else {
    Write-Host 'pi extra:     (none)'
}

$CanSymlink = Test-SymlinkPrivilege
if (-not $CanSymlink -and -not $Check) {
    Write-Host ''
    Write-Warning 'Symlink creation needs Developer Mode or an elevated shell.'
    Write-Host '  Skill directories will use junctions (no admin needed); the memory file link still needs privileges.'
    Write-Host '  Enable Developer Mode: Settings > Privacy & security > For developers - or re-run elevated.'
}

$selected = @()
if ($Check) {
    Write-Host ''
    Write-Host 'Dry run: nothing will be changed.'
    $selected = @($Agents)
} elseif ($All) {
    $selected = @($Agents)
} elseif ($Agent.Count -gt 0) {
    $selected = @($Agents | Where-Object { $_.Id -in $Agent -or $_.Label -in $Agent })
    if ($selected.Count -eq 0) {
        Write-Warning "No known agent matched: $($Agent -join ', ')"
    }
} else {
    $selected = @(Select-Agents)
}

if ($selected.Count -gt 0) {
    foreach ($a in $selected) {
        Write-Host ''
        Write-Host "== $($a.Label) =="
        Set-Link -Source $MemorySrc -Dest (Join-Path $a.MemoryDir $a.MemoryName) -CanSymlink $CanSymlink
        if ($a.ConfigSrc -and (Test-Path -LiteralPath (Join-Path $ScriptRoot $a.ConfigSrc) -PathType Leaf)) {
            Set-Link -Source (Join-Path $ScriptRoot $a.ConfigSrc) -Dest $a.ConfigDest -CanSymlink $CanSymlink
        } else {
            Write-Host "  (config not found: $($a.ConfigSrc))"
        }
        if ($a.Id -eq 'pi') {
            # Mirror everything under pi\ into the live dir, so new configs
            # (agents, themes, ...) deploy without touching this script.
            # Exceptions: package.json lives at npm\package.json, and
            # settings.json is already linked by the generic config step above.
            $piSrcDir = Join-Path $ScriptRoot 'pi'
            if (Test-Path -LiteralPath $piSrcDir -PathType Container) {
                $piPkgSrc = Join-Path $piSrcDir 'package.json'
                if (Test-Path -LiteralPath $piPkgSrc -PathType Leaf) {
                    Set-Link -Source $piPkgSrc -Dest (Join-Path $a.MemoryDir 'npm\package.json') -CanSymlink $CanSymlink
                }
                # One-time migration: a previous version of this script linked
                # agents per-file instead of linking the directory.
                $agentsDest = Join-Path $a.MemoryDir 'agents'
                $piAgentsSrc = Join-Path $piSrcDir 'agents'
                if ((Test-Path -LiteralPath $agentsDest) -and -not (Get-Item -LiteralPath $agentsDest -Force).LinkType) {
                    Get-ChildItem -LiteralPath $agentsDest -Filter '*.md' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.LinkType -and (($_.Target | Select-Object -First 1) -like "$piAgentsSrc*") } |
                        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force; Write-Host "  removed legacy link $($_.FullName)" }
                    if (-not (Get-ChildItem -LiteralPath $agentsDest -Force -ErrorAction SilentlyContinue)) {
                        Remove-Item -LiteralPath $agentsDest -Force
                    }
                }
                Get-ChildItem -LiteralPath $piSrcDir -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notin @('package.json', 'settings.json') } |
                    ForEach-Object {
                        $dest = Join-Path $a.MemoryDir $_.Name
                        if ($_.PSIsContainer) {
                            Set-Link -Source $_.FullName -Dest $dest -IsDirectory -CanSymlink $CanSymlink
                        } else {
                            Set-Link -Source $_.FullName -Dest $dest -CanSymlink $CanSymlink
                        }
                    }
            } else {
                Write-Host '  (no pi dir)'
            }
        }
        if ($Skills.Count -gt 0) {
            foreach ($s in $Skills) {
                Set-Link -Source $s -Dest (Join-Path $a.SkillsDir (Split-Path $s -Leaf)) -IsDirectory -CanSymlink $CanSymlink
            }
        } else {
            Write-Host '  (no skills found)'
        }
    }
    Write-Host ''
    if ($Check) {
        Write-Host 'Done (dry run - no changes made).'
    } else {
        Write-Host 'Done. If an agent is running, restart it for the changes to take effect.'
    }
} else {
    Write-Host ''
    Write-Host 'Nothing selected - no changes made.'
}