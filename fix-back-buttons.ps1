# ============================================================
#  fix-back-buttons.ps1
#  Audit et correction automatique des boutons "Retour"
#  Parashot Mormin - Ariel Mormin
#
#  Usage :
#    .\fix-back-buttons.ps1        => audit uniquement
#    .\fix-back-buttons.ps1 -Fix   => audit + correction
# ============================================================

param([switch]$Fix)

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$Ignore  = @('images', 'derekh-ariel', 'derekh-mormin')
$Marker  = 'back-button'

# ============================================================
# Fonction : extraire la premiere couleur hex du body
# ============================================================
function Get-PrimaryColor {
    param([string]$Content)
    if ($Content -match 'body\s*\{[^}]*?linear-gradient\([^)]*?(#[0-9a-fA-F]{6})') {
        return $Matches[1]
    }
    if ($Content -match '#([0-9a-fA-F]{6})') {
        return '#' + $Matches[1]
    }
    return '#1a1a2e'
}

# ============================================================
# Fonction : assombrir une couleur hex
# ============================================================
function Darken-Color {
    param([string]$Hex, [int]$Percent = 25)
    $h = $Hex.TrimStart('#')
    $r = [int]([Math]::Max(0, [Convert]::ToInt32($h.Substring(0,2),16) * (100-$Percent) / 100))
    $g = [int]([Math]::Max(0, [Convert]::ToInt32($h.Substring(2,2),16) * (100-$Percent) / 100))
    $b = [int]([Math]::Max(0, [Convert]::ToInt32($h.Substring(4,2),16) * (100-$Percent) / 100))
    return "#{0:X2}{1:X2}{2:X2}" -f $r, $g, $b
}

# ============================================================
# Fonction : hex vers "r, g, b"
# ============================================================
function Hex-ToRgb {
    param([string]$Hex)
    $h = $Hex.TrimStart('#')
    $r = [Convert]::ToInt32($h.Substring(0,2),16)
    $g = [Convert]::ToInt32($h.Substring(2,2),16)
    $b = [Convert]::ToInt32($h.Substring(4,2),16)
    return "$r, $g, $b"
}

# ============================================================
# AUDIT
# ============================================================
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  AUDIT - Boutons Retour  |  Parashot Mormin"       -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Repertoire : $Root"                               -ForegroundColor Gray
Write-Host ""

$Missing   = [System.Collections.ArrayList]@()
$HasButton = [System.Collections.ArrayList]@()
$Skipped   = [System.Collections.ArrayList]@()

$SubFolders = Get-ChildItem -Path $Root -Directory | Where-Object { $_.Name -notin $Ignore }

foreach ($Folder in $SubFolders) {
    $HtmlFile = Join-Path $Folder.FullName 'index.html'
    if (-not (Test-Path $HtmlFile)) {
        [void]$Skipped.Add($Folder.Name)
        continue
    }
    $Content = Get-Content $HtmlFile -Raw -Encoding UTF8
    if ($Content -match $Marker) {
        [void]$HasButton.Add($Folder.Name)
        Write-Host "  OK  $($Folder.Name)" -ForegroundColor Green
    } else {
        $obj = [PSCustomObject]@{ Name = $Folder.Name; Path = $HtmlFile; Content = $Content }
        [void]$Missing.Add($obj)
        Write-Host "  !!  $($Folder.Name)  <-- bouton manquant" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "---------------------------------------------------" -ForegroundColor Gray
Write-Host ("  Avec bouton  : {0,3}" -f $HasButton.Count) -ForegroundColor Green
Write-Host ("  Sans bouton  : {0,3}" -f $Missing.Count)   -ForegroundColor Red
if ($Skipped.Count -gt 0) {
    Write-Host ("  Sans HTML    : {0,3}  ({1})" -f $Skipped.Count, ($Skipped -join ', ')) -ForegroundColor Yellow
}
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $Fix) {
    Write-Host "  Mode audit seul. Relancez avec -Fix pour corriger." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

if ($Missing.Count -eq 0) {
    Write-Host "  Toutes les pages ont deja le bouton retour !" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# ============================================================
# CORRECTION
# ============================================================
Write-Host "  Correction en cours..." -ForegroundColor Cyan
Write-Host ""

$Fixed  = 0
$Errors = 0

foreach ($Item in $Missing) {
    $Name    = $Item.Name
    $Path    = $Item.Path
    $Content = $Item.Content

    $Color1 = Get-PrimaryColor -Content $Content
    $Color2 = Darken-Color -Hex $Color1 -Percent 20
    $Shadow = Hex-ToRgb -Hex $Color1

    # Bloc CSS (concatenation simple, pas de here-string)
    $nl  = "`n"
    $Css = $nl
    $Css += "        /* Bouton retour - fix-back-buttons.ps1 */$nl"
    $Css += "        .back-button {$nl"
    $Css += "            display: inline-flex;$nl"
    $Css += "            align-items: center;$nl"
    $Css += "            gap: 8px;$nl"
    $Css += "            padding: 12px 24px;$nl"
    $Css += "            background: linear-gradient(135deg, $Color1 0%, $Color2 100%);$nl"
    $Css += "            color: white;$nl"
    $Css += "            text-decoration: none;$nl"
    $Css += "            border-radius: 10px;$nl"
    $Css += "            font-weight: bold;$nl"
    $Css += "            font-size: 1em;$nl"
    $Css += "            transition: all 0.3s ease;$nl"
    $Css += "            box-shadow: 0 4px 15px rgba($Shadow, 0.40);$nl"
    $Css += "            margin-bottom: 20px;$nl"
    $Css += "        }$nl"
    $Css += "        .back-button:hover {$nl"
    $Css += "            transform: translateY(-2px);$nl"
    $Css += "            box-shadow: 0 6px 20px rgba($Shadow, 0.60);$nl"
    $Css += "        }$nl"
    $Css += "    "

    # Bouton HTML
    $BtnHtml = "        <a href=""https://parashot-mormin.netlify.app/"" class=""back-button"">&larr; Retour aux Parachiot</a>$nl"

    # Injecter CSS avant </style>
    if ($Content -notmatch '</style>') {
        Write-Host "  SKIP  $Name  : </style> introuvable" -ForegroundColor Yellow
        $Errors++
        continue
    }
    $Content = $Content.Replace('</style>', $Css + '</style>')

    # Injecter bouton HTML
    if ($Content -match '<div class="container">') {
        $Content = $Content.Replace('<div class="container">', '<div class="container">' + $nl + $BtnHtml)
    } elseif ($Content -match '<body>') {
        $Content = $Content.Replace('<body>', '<body>' + $nl + $BtnHtml)
    } else {
        Write-Host "  SKIP  $Name  : point d'insertion introuvable" -ForegroundColor Yellow
        $Errors++
        continue
    }

    # Sauvegarde + ecriture UTF-8 sans BOM
    try {
        Copy-Item $Path "$Path.bak" -Force
        $enc = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($Path, $Content, $enc)
        Write-Host "  FIX   $Name  (couleur : $Color1)" -ForegroundColor Green
        $Fixed++
    } catch {
        Write-Host "  ERR   $Name  : $_" -ForegroundColor Red
        $Errors++
    }
}

# ============================================================
# RESUME FINAL
# ============================================================
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  RESUME"                                           -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ("  Corriges  : {0,3}" -f $Fixed)  -ForegroundColor Green
if ($Errors -gt 0) {
    Write-Host ("  Erreurs   : {0,3}" -f $Errors) -ForegroundColor Red
}
Write-Host ""
Write-Host "  Fichiers .bak crees comme sauvegarde."           -ForegroundColor Gray
Write-Host "  Pour les supprimer apres verification :"         -ForegroundColor Gray
Write-Host "  Get-ChildItem -Recurse -Filter *.bak | Remove-Item" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Deploiement :"                                    -ForegroundColor Cyan
Write-Host "  git add ."                                        -ForegroundColor White
Write-Host "  git commit -m ""fix: bouton retour pages anciennes""" -ForegroundColor White
Write-Host "  git push"                                         -ForegroundColor White
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
