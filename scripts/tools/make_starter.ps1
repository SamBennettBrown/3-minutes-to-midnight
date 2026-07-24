# Creates a fresh Godot project seeded with this project's reusable core:
# shaders, the Synty animation pipeline, and the docs.
#
#   .\scripts\tools\make_starter.ps1 -Dest "C:\Users\alecd\Documents\my-new-game" -Name "My New Game"

param(
    [Parameter(Mandatory = $true)][string]$Dest,
    [string]$Name = "New Project"
)

$Src = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (Test-Path (Join-Path $Dest "project.godot")) {
    Write-Error "Destination already contains a Godot project - refusing to overwrite."
    exit 1
}

foreach ($dir in @("shaders", "anims", "docs", "scripts\tools", "scripts\tools\retarget")) {
    New-Item -ItemType Directory -Force (Join-Path $Dest $dir) | Out-Null
}

# --- shaders (fully self-contained) ---
Copy-Item "$Src\shaders\*.gdshader" (Join-Path $Dest "shaders")

# --- animation pipeline ---
Copy-Item "$Src\anims\*.tres" (Join-Path $Dest "anims")
Copy-Item "$Src\scripts\tools\convert_fbx.py" (Join-Path $Dest "scripts\tools")
Copy-Item "$Src\scripts\tools\synty_import.ps1" (Join-Path $Dest "scripts\tools")
Copy-Item "$Src\scripts\tools\tree_probe.gd" (Join-Path $Dest "scripts\tools")
Copy-Item "$Src\docs\SYNTY_ANIMATION_PIPELINE.md" (Join-Path $Dest "docs")

# --- example converted assets so animation playback works out of the box ---
foreach ($example in @("walk_rt", "idle_rt")) {
    Copy-Item "$Src\scripts\tools\retarget\$example.glb" (Join-Path $Dest "scripts\tools\retarget") -ErrorAction SilentlyContinue
    Copy-Item "$Src\scripts\tools\retarget\$example.glb.import" (Join-Path $Dest "scripts\tools\retarget") -ErrorAction SilentlyContinue
}

# --- minimal project file ---
$project = @"
; Engine configuration file.
config_version=5

[application]

config/name="$Name"
config/features=PackedStringArray("4.7", "Forward Plus")

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
"@
[System.IO.File]::WriteAllText((Join-Path $Dest "project.godot"), $project)

Write-Host "Starter project created at $Dest"
Write-Host "Open it via Godot's Project Manager -> Import -> select that folder."
