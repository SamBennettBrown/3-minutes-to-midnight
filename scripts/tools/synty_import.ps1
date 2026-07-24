# One-command Synty asset pipeline.
#
#   .\scripts\tools\synty_import.ps1 -Source <path-to-fbx> -Type anim
#   .\scripts\tools\synty_import.ps1 -Source <path-to-fbx> -Type character -Dialect rivals
#
# Does everything: Blender FBX->GLB conversion (with bone renames),
# pre-writes the Godot .import config (bone map, silhouette fix,
# immutable-tracks off), and runs one headless import. Output lands in
# scripts/tools/retarget/<name>_rt.glb, ready to play against everything else.
# Only ever CREATES new files - never touches existing assets.

param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][ValidateSet("anim", "character")][string]$Type,
    [ValidateSet("polygon", "rivals", "mixamo")][string]$Dialect = "polygon",
    [string]$Name = ""
)

$Blender = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
$Godot = "C:\Users\alecd\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
$Project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

if (-not (Test-Path $Source)) { Write-Error "Source not found: $Source"; exit 1 }
if ($Name -eq "") { $Name = [System.IO.Path]::GetFileNameWithoutExtension($Source) }
$OutName = "$($Name)_rt"
$Glb = Join-Path $Project "scripts\tools\retarget\$OutName.glb"
$ResPath = "res://scripts/tools/retarget/$OutName.glb"

# 1. Blender conversion (foreign rigs get bone renames/cleanup)
$rename = "none"
if ($Type -eq "character" -and $Dialect -eq "rivals") { $rename = "rivals" }
if ($Dialect -eq "mixamo") { $rename = "mixamo" }
$BoneMap = "res://anims/synty_bone_map.tres"
if ($Dialect -eq "mixamo") { $BoneMap = "res://anims/mixamo_bone_map.tres" }
& $Blender --background --python (Join-Path $PSScriptRoot "convert_fbx.py") -- $Source $Glb $rename | Select-String "BLEND"
if (-not (Test-Path $Glb)) { Write-Error "Blender conversion failed"; exit 1 }

# 2. Pre-write the .import so Godot imports it correctly on first pass
$md5 = [System.Security.Cryptography.MD5]::Create()
$hash = ($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($ResPath)) | ForEach-Object { $_.ToString("x2") }) -join ""
$immutable = if ($Type -eq "anim") { "false" } else { "true" }
$silhouette = if ($Type -eq "anim") { ',
"retarget/rest_fixer/fix_silhouette/enable": true' } else { "" }

$import = @"
[remap]

importer="scene"
importer_version=1
type="PackedScene"
path="res://.godot/imported/$OutName.glb-$hash.scn"

[deps]

source_file="$ResPath"
dest_files=["res://.godot/imported/$OutName.glb-$hash.scn"]

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=$immutable
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={
"nodes": {
"PATH:Armature/Skeleton3D": {
"retarget/bone_map": Resource("$BoneMap")$silhouette
},
"PATH:Root/Skeleton3D": {
"retarget/bone_map": Resource("$BoneMap")$silhouette
}
}
}
gltf/naming_version=2
gltf/embedded_image_handling=1
gltf/texture_map_mode=1
"@
[System.IO.File]::WriteAllText("$Glb.import", $import)

# 3. One headless import and we're done
& $Godot --headless --path $Project --import 2>$null | Out-Null
if (Test-Path (Join-Path $Project ".godot\imported\$OutName.glb-$hash.scn")) {
    Write-Host "READY: $ResPath  (type=$Type, dialect=$Dialect)"
} else {
    Write-Error "Import did not produce the expected scene - check the editor output"
}
