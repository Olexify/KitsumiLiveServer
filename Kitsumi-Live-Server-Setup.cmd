@echo off
rem Kitsumi Live Server - Copyright (c) 2026 Olexify. All rights reserved. Free to use, not open source.
rem Licence: https://github.com/Olexify/KitsumiLiveServer/blob/main/LICENSE
rem Kitsumi live server - setup for Windows. SOURCE of Kitsumi-Live-Server-Setup.cmd: node tools/build-privacy.js
rem puts whisper_server.py under it, so the one downloaded file holds everything it installs of Kitsumi's.
rem It is plain text: open it in Notepad to read what it does before running it.
setlocal
set "KSELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=[IO.File]::ReadAllText($env:KSELF) -split '(?m)^::KITSUMI-PS::\r?\n|^::KITSUMI-ICO::\r?\n|^::KITSUMI-PY::\r?\n'; $KICO=$p[2]; $KPY=$p[3]; iex $p[1]"
set "KERR=%errorlevel%"
if not "%KERR%"=="0" pause
exit /b %KERR%
::KITSUMI-PS::
# What this does, all inside the ONE folder you choose (delete the folder = uninstalled):
#   1. writes whisper_server.py (the text at the end of this file)
#   2. downloads uv (a Python installer, github.com/astral-sh/uv) at a fixed version and checks its SHA-256
#   3. uv downloads Python and the speech library (fixed versions, from GitHub and PyPI) into the folder
#   4. writes "Start Kitsumi live server.cmd" (+ a desktop shortcut if you leave the box ticked)
# Nothing is added to PATH, the registry or Windows start-up. No administrator rights.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, System.IO.Compression.FileSystem
[Windows.Forms.Application]::EnableVisualStyles()

$UV_VER = '0.12.17'
$UV_SHA = 'a252121d5b59398fcb137c6ea448176459a44010f33f67e0072305a637119ca7'
$PY_VER = '3.14'
# the set this server was tested with
$PINS = 'faster-whisper==1.2.1', 'ctranslate2==4.8.3', 'av==19.0.2', 'onnxruntime==1.31.0', 'numpy==2.5.4', 'tokenizers==0.23.3', 'huggingface_hub==2.2.0'
$GPU_PINS = 'nvidia-cublas-cu12==12.9.2.10', 'nvidia-cudnn-cu12==9.27.0.42'

$nvidia = [bool](Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' })
if ($env:KITSUMI_NO_GPU) { $nvidia = $false }
$JA_MODEL = 'kotoba-tech/kotoba-whisper-v2.0-faster'
$need = if ($nvidia) { '3 GB plus the models' } else { 'about 1.5 GB' }

# Removes an installation: only the things this setup put there, and the folder itself when nothing else is left in it.
function Remove-Install($dir, [bool]$ask) {
  if (-not (Test-Path (Join-Path $dir 'whisper_server.py'))) { throw "There is no Kitsumi live server in '$dir'." }
  if ($ask -and [Windows.Forms.MessageBox]::Show("Remove the Kitsumi live server from`r`n$dir`r`n`r`nPython, the speech library and the downloaded models in that folder are deleted. Close its window first if it is running.", 'Kitsumi live server', 'OKCancel', 'Warning') -ne 'OK') { return $false }
  foreach ($n in 'venv', 'python', 'uv', 'cache', 'models', 'uv.zip', 'whisper_server.py', 'kitsumi.ico', 'Start Kitsumi live server.cmd', '__pycache__') {
    $p = Join-Path $dir $n
    if (Test-Path $p) { Remove-Item $p -Recurse -Force }
  }
  if (-not (Get-ChildItem $dir -Force)) { Remove-Item $dir -Force }
  $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Kitsumi live server.lnk'
  if (Test-Path $lnk) { try { if ((New-Object -ComObject WScript.Shell).CreateShortcut($lnk).TargetPath -like "$dir*") { Remove-Item $lnk -Force } } catch {} }
  $true
}

function New-SetupForm {
  $f = New-Object Windows.Forms.Form -Property @{ Text = 'Kitsumi live server - setup'; ClientSize = '540,418'; FormBorderStyle = 'FixedDialog'; MaximizeBox = $false; MinimizeBox = $false; StartPosition = 'CenterScreen'; Font = (New-Object Drawing.Font('Segoe UI', 9)) }
  try { $f.Icon = New-Object Drawing.Icon (New-Object IO.MemoryStream (, [Convert]::FromBase64String($KICO.Trim()))) } catch {}   # Kitsumi's icon in the title bar
  $add = { param($type, $props) $c = New-Object "Windows.Forms.$type" -Property $props; $f.Controls.Add($c); $c }
  $card = if ($nvidia) { 'NVIDIA graphics card found: the big model, lines in under a second.' } else { 'No NVIDIA graphics card found: the small model on the processor, lines in about two seconds.' }
  $null = & $add Label @{ Location = '16,14'; Size = '508,92'; Text = "This installs the program that writes Kitsumi's live subtitles on your own computer: free, no account, the sound never leaves it.`r`n`r`nEverything goes into the one folder below. Nothing else on the computer is changed, and deleting the folder removes it." }
  $null = & $add Label @{ Location = '16,112'; Size = '508,18'; Text = 'Install into:' }
  $path = & $add TextBox @{ Location = '16,132'; Size = '412,23'; Text = (Join-Path $env:LOCALAPPDATA 'KitsumiLiveServer'); Name = 'path' }
  $browse = & $add Button @{ Location = '436,131'; Size = '88,25'; Text = 'Browse...' }
  $null = & $add Label @{ Location = '16,164'; Size = '508,54'; Text = "$card`r`nNeeds $need of free space there and an internet connection (Python and the speech library are downloaded)." }
  # which languages: each one is a model of its own, downloaded now (only what is ticked takes room)
  $null = & $add Label @{ Location = '16,222'; Size = '508,18'; Text = 'Languages you will use it for:' }
  $ja = & $add CheckBox @{ Location = '18,242'; Size = '500,22'; Text = 'Japanese - the Japanese-only model, the most accurate for Japanese (1.5 GB)'; Checked = $nvidia; Enabled = $nvidia; Name = 'ja' }
  $other = & $add CheckBox @{ Location = '18,266'; Size = '500,22'; Text = $(if ($nvidia) { 'Other languages - the general model (1.6 GB)' } else { 'Every language - the small model (0.5 GB); the others need an NVIDIA graphics card' }); Checked = $true; Enabled = $nvidia; Name = 'other' }
  $null = & $add CheckBox @{ Location = '18,298'; Size = '400,22'; Text = 'Put a shortcut on the desktop'; Checked = $true; Name = 'shortcut' }
  # the licences, seen before anything is installed (the links open the two documents)
  $lic = & $add LinkLabel @{ Location = '16,326'; Size = '508,36'; Text = "By installing you accept the Kitsumi Live Server licence and the licences of the software it downloads (for an NVIDIA graphics card: NVIDIA's own terms for its libraries)." }
  $u1 = 'https://github.com/Olexify/KitsumiLiveServer/blob/main/LICENSE'; $u2 = 'https://github.com/Olexify/KitsumiLiveServer/blob/main/THIRD-PARTY-NOTICES.md'
  $t = $lic.Text; $a1 = 'Kitsumi Live Server licence'; $a2 = 'licences of the software it downloads'
  $null = $lic.Links.Add($t.IndexOf($a1), $a1.Length, $u1); $null = $lic.Links.Add($t.IndexOf($a2), $a2.Length, $u2)
  $lic.Add_LinkClicked({ param($o, $e) try { Start-Process ([string]$e.Link.LinkData) } catch {} })
  $remove = & $add Button @{ Location = '16,376'; Size = '150,28'; Text = 'Remove it from here'; DialogResult = 'Abort'; Name = 'remove' }
  $ok = & $add Button @{ Location = '340,376'; Size = '88,28'; Text = 'Install'; DialogResult = 'OK' }
  $cancel = & $add Button @{ Location = '436,376'; Size = '88,28'; Text = 'Cancel'; DialogResult = 'Cancel' }
  $f.AcceptButton = $ok; $f.CancelButton = $cancel
  # Remove shows only where an installation is; with one there, Install reads "Update"
  $sync = { $has = Test-Path (Join-Path $path.Text.Trim().Trim('"') 'whisper_server.py'); $remove.Visible = $has; $ok.Text = $(if ($has) { 'Update' } else { 'Install' }) }
  $path.Add_TextChanged($sync); & $sync
  $browse.Add_Click({
    $d = New-Object Windows.Forms.FolderBrowserDialog -Property @{ Description = 'A folder named KitsumiLiveServer is made inside the one you pick.'; ShowNewFolderButton = $true }
    if ($d.ShowDialog() -eq 'OK') { $path.Text = Join-Path $d.SelectedPath 'KitsumiLiveServer' }
  })
  $f
}

function Run-Step($what, [scriptblock]$do) {
  Write-Host "`n== $what" -ForegroundColor Cyan
  & $do
  if ($LASTEXITCODE) { throw "$what failed (code $LASTEXITCODE)." }
}

# --- main ---
try {
  $shortcut = $true; $wantJa = $nvidia; $wantOther = $true; $act = 'OK'
  if ($env:KITSUMI_DIR) {   # no questions: for tests (KITSUMI_LANGS = ja / other / both, KITSUMI_REMOVE = remove instead)
    $dir = $env:KITSUMI_DIR; $shortcut = $false
    if ($env:KITSUMI_LANGS -eq 'ja') { $wantOther = $false } elseif ($env:KITSUMI_LANGS -eq 'other') { $wantJa = $false }
    if ($env:KITSUMI_REMOVE) { $act = 'Abort' }
  } else {
    $form = New-SetupForm
    $act = [string]$form.ShowDialog()
    if ($act -ne 'OK' -and $act -ne 'Abort') { exit 0 }
    $dir = $form.Controls['path'].Text.Trim().Trim('"'); $shortcut = $form.Controls['shortcut'].Checked
    $wantJa = $form.Controls['ja'].Checked; $wantOther = $form.Controls['other'].Checked
  }
  if (-not $dir -or -not [IO.Path]::IsPathRooted($dir)) { throw "That is not a full folder path: '$dir'" }
  $dir = [IO.Path]::GetFullPath($dir)
  if ($act -eq 'Abort') {
    if (Remove-Install $dir (-not $env:KITSUMI_DIR)) {
      Write-Host "Removed from $dir" -ForegroundColor Green
      if (-not $env:KITSUMI_DIR) { $null = [Windows.Forms.MessageBox]::Show("The Kitsumi live server was removed from`r`n$dir", 'Kitsumi live server', 'OK', 'Information') }
    }
    exit 0
  }
  if (-not $nvidia) { $wantJa = $false; $wantOther = $true }
  if (-not $wantJa -and -not $wantOther) { $wantJa = $true; $wantOther = $true }   # nothing ticked = both
  # the model the Start file names: one language group = that model, both = by the language Kitsumi sends
  $model = if (-not $nvidia) { 'small' } elseif ($wantJa -and $wantOther) { 'auto' } elseif ($wantJa) { $JA_MODEL } else { 'large-v3-turbo' }
  $models = @(); if (-not $nvidia) { $models += 'small' } else { if ($wantOther) { $models += 'large-v3-turbo' }; if ($wantJa) { $models += $JA_MODEL } }
  $null = New-Item -ItemType Directory -Force $dir
  # room on that drive, asked before anything is downloaded
  $needGB = if ($nvidia) { 3 + 2 * $models.Count } else { 2 }
  $freeGB = try { [math]::Floor((New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($dir))).AvailableFreeSpace / 1GB) } catch { 999 }
  if ($freeGB -lt $needGB) { throw "Not enough room on that drive: $freeGB GB free, about $needGB GB needed. Choose a folder on another drive." }
  Write-Host "Installing into $dir"

  [IO.File]::WriteAllText((Join-Path $dir 'whisper_server.py'), $KPY)
  $ico = Join-Path $dir 'kitsumi.ico'   # Kitsumi's icon, for the shortcut
  try { [IO.File]::WriteAllBytes($ico, [Convert]::FromBase64String($KICO.Trim())) } catch { $ico = '' }

  $LASTEXITCODE = 0
  Run-Step 'Downloading uv (the Python installer)' {
    $zip = Join-Path $dir 'uv.zip'
    (New-Object Net.WebClient).DownloadFile("https://github.com/astral-sh/uv/releases/download/$UV_VER/uv-x86_64-pc-windows-msvc.zip", $zip)
    $sha = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($zip))) -replace '-'
    if ($sha -ne $UV_SHA) { Remove-Item $zip; throw 'The downloaded uv is not the expected file (checksum differs). Nothing was installed from it.' }
    $to = Join-Path $dir 'uv'
    if (Test-Path $to) { Remove-Item $to -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $to)
    Remove-Item $zip
  }
  $uv = if ($env:KITSUMI_UV) { $env:KITSUMI_UV } else { Join-Path $dir 'uv\uv.exe' }   # another uv: for tests
  $env:UV_CACHE_DIR = Join-Path $dir 'cache'             # downloads stay in the chosen folder, not on C:
  $env:UV_PYTHON_INSTALL_DIR = Join-Path $dir 'python'
  $py = Join-Path $dir 'venv\Scripts\python.exe'
  Run-Step "Installing Python $PY_VER into the folder" { & $uv venv (Join-Path $dir 'venv') --python $PY_VER --managed-python --allow-existing }
  $pkgs = if ($nvidia) { $PINS + $GPU_PINS } else { $PINS }
  Run-Step 'Installing the speech library (the long step)' { & $uv pip install --python $py @pkgs }
  Remove-Item $env:UV_CACHE_DIR -Recurse -Force -ErrorAction SilentlyContinue
  # the chosen models now, so the first start is quick; one that fails here is downloaded on its first use instead
  $env:PYTHONUTF8 = '1'; $env:KITSUMI_MODELS = Join-Path $dir 'models'
  foreach ($m in $models) {
    Write-Host "`n== Downloading the speech model $m" -ForegroundColor Cyan
    $env:KITSUMI_M = $m
    if (-not $env:KITSUMI_UV) { & $py -c "import os; from faster_whisper.utils import download_model; download_model(os.environ['KITSUMI_M'], cache_dir=os.environ['KITSUMI_MODELS'])" }
    if ($LASTEXITCODE) { Write-Host "   not downloaded now - it will be on its first use." -ForegroundColor Yellow; $LASTEXITCODE = 0 }
  }

  $start = Join-Path $dir 'Start Kitsumi live server.cmd'
  [IO.File]::WriteAllText($start, "@echo off`r`ntitle Kitsumi live server`r`nrem In Kitsumi: Local - Live generate on this page - Your own server, address http://localhost:8000/v1, no key.`r`nset PYTHONUTF8=1`r`nset `"WHISPER_MODELS=%~dp0models`"`r`n`"%~dp0venv\Scripts\python.exe`" `"%~dp0whisper_server.py`" $model`r`npause`r`n", [Text.Encoding]::ASCII)
  if ($shortcut) {
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Kitsumi live server.lnk'))
    $lnk.TargetPath = $start; $lnk.WorkingDirectory = $dir
    if ($ico) { $lnk.IconLocation = "$ico,0" }
    $lnk.Save()
  }
  Write-Host "`nDone. Start it with: $start" -ForegroundColor Green
  if (-not $env:KITSUMI_DIR) {
    $go = [Windows.Forms.MessageBox]::Show("Installed.`r`n`r`nStart it now?`r`n`r`nThen in Kitsumi: Local - Live generate on this page - Your own server, address http://localhost:8000/v1, key empty.", 'Kitsumi live server', 'YesNo', 'Information')
    if ($go -eq 'Yes') { Start-Process $start -WorkingDirectory $dir }
  }
  exit 0
} catch {
  Write-Host "`nSetup stopped: $($_.Exception.Message)" -ForegroundColor Red
  if (-not $env:KITSUMI_DIR) { $null = [Windows.Forms.MessageBox]::Show("Setup stopped:`r`n$($_.Exception.Message)`r`n`r`nNothing outside the chosen folder was changed. You can run the setup again - it continues in the same folder.`r`nHelp: discord.gg/UpmNHxT7PF", 'Kitsumi live server', 'OK', 'Error') }
  exit 1
}
::KITSUMI-ICO::
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3v51U8j/dVnM/3Va0v97der/gIju/4OZ+v+Kpf//hpny/3eR4/+KsP7/dJ/y/0mF6v9/wPv/kM/9/5vX/P+T0Pz/ltT+/57Z/f+d0P3/i8D1/zVXwv9llOH/YHW5/3SLv/+97Pn/mb7d/7Ti8v9pebL/WWGp/2yL0/9Wb7j8f5Xe/3NRyP92Ydb/fX7t/4CT9/+Fpf//g6Xy/4Wk3/+HquL/iJTP/3CBsP9htfH/Qov1/2+4+P+d3P//ntz8/53c/P+Lzvz/o+L9/6Dc/f+Y0fv/Q3PW/12Q4v9mgsP/UFym/57G4/97mMn/mcDf/0dJmP9cbLP/bIzV/1N1yP9/k9z/dVXM/3p06f99gPX/f4bt/3BZpv9pPYn/aDmN/2Ywhv9lN4P/YEGF/2OFtv9htvP/SaH4/5DQ8P+l5f//qOb8/3zD+P+Mzvn/rOv+/6jk/v9loOn/P3Xe/4Gz6f9ZbrX/W3K4/1Rosf9acLb/Ul6p/4Gp3v9RZsL/WXvM/36R2/93YNz/fXvz/4CL7/9sR4b/aTSE/21Co/9tRKX/d3fH/4i09P+Vzv//j8P2/3ex3/9Yruv/R43K/5jU6v+y8P//k9b7/1Se9P+Rz/b/ufX//6Lf+/9Cg+b/QoHm/26s8v9poen/ap/o/2ue5/9wpu3/UX7Z/z1Ms/9egdD/fpLf/3dm5f+ClP//c2Ct/2cxf/9uR63/a0Gn/3l90f+LxP//k9D//5PP/f+U0f//lc7//4W/7/9Tm9b/OnKr/5PU7v+38v7/c8H8/0aS8f94uPL/se78/6Hh+/9Pm/H/OIjv/z6P8P86geX/NmvZ/zZk1P89bNr/QWDJ/1qAzv99kuT/enXw/4GX/v9sR5P/aTyV/2pApP9wXbv/hbT9/5HJ/P+Uz/z/ks39/4/L/f+Pyfz/l9P//5HG9/9soNj/ba3k/4rS9P+q6/v/c8f9/0WY8v9HlPD/db72/4bN+P9bsPj/Saf8/06z/v9Npvf/P37k/z9w2v8+a9n/Worb/32S5f99g/f/gJP9/2lFlf9pPJj/aD+i/3aA1v+Jv///ltD8/5PP/f+Tz/3/ndX8/63n//+Xut7/f6Pc/4ix1/96kbz/eavf/4DI8/+P1/f/dc7+/1qy9/88lvb/PJf3/0qk+f9Hpvv/S6z8/1u//v9Urfr/Pn3m/zxs2f9alef/fpTm/3+L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J/8vUqj/O3fa/0uM7/9JYcr/TGPL/05Vvf9fb87/Z5z2/3iv/P+Dv/3/f7f6/4O2+/+MwPv/k8z8/53V/f+azPz/j777/425+f+bzPr/mcv5/5vK+f9McMz/jL3v/0pSo/9LRI7/RDiB/21/tP/I+v//iajO/0M3f/9MPoT/OSx8/36e0v96k8j9U2as/5Xm/2iR4fzEfHzW/nRJuP14YdD/eWXS/3FKpf9xTa//d1vO/3ld2f93Xdj/bE+r/1UoRv8yJDz/KU+X/0Sb8/9GgOP/RFrF/2BfvP9sjOX/Y5z3/364/P+HxP3/isb8/4q/+/+Syfz/lM/8/5zV/v+d0v3/k8T7/5XE+v+f0/3/Y4XQ/4237f93p+r/hrbr/01Uov9GO4X/UU6Q/1hhnv9icar/xvz//2Nvqf9FN3//RzmD/2Bws/+HrOD8RkWT/n225L2Ny/PxdV3G/3ZUxP95YdL/c1O//3VZz/93X9v/dl/d/3dk4f94a+f/enLy/3tv7f9sVrH/SD6I/0Fjtf9Rguj/a3LU/4qi7f9Shun/YqD1/4K//P+KyP3/kdD8/5XO+/+Uzf3/ktD8/5zW/v+e2P7/l8n7/5fH+/+g1v7/UHbO/0JdwP9lkuD/j8Hv/0xToP8/N4T/a4G6/7Xk9v87PYz/ptLq/36Zxv89N4T/RTqF/2ButP+Gs+v+Pz6U/3GYy+mHve7/c1TF/3hczv91Ws7/dFfP/3Ze1/95cuX/gInz/4Sb9/+Go/f/iKf3/4mp+f+Mrf//jan//42l+v+XtP//l8H//1qS7P9Deub/X6T2/4vL/P+Ozf3/lNP9/6Db/P+Y1Pz/jc78/5rX/f+g3P7/ntf9/5fI/P+h2P3/XI3g/zpbxf9Aac7/jL/w/0NLnv99m8z/ve34/8Hy+P+w4PP/ve73/73w+f+eyOj/RD+Q/19ttP+Gs+z/Pkiq/2mTzf6Ftur/dFbI/3Vazv9zVs3/d2Xc/4CI9P+DnPn/hKH2/4Wp+v+ItP//jMD//5DG//+RyPv/ksj5/5O66/96mMn/ecvw/1Gk+v9Eg+z/S5f1/4jO+v+X1v3/l9X9/6Pg/f+j4fz/icz9/5XW/f+h3/3/ouH9/5rT+/+h2f7/baXq/zlkzv9Fc9T/jcLy/0dTpv9SXqf/iq/Y/8H1/f9lfbv/suL0/5nB4f9dbbD/Q0CR/15wt/+Hs+r/O0ev/2ma3P+Ften/dFbI/3VYzP94Z9v/foHz/3x/8P96euv/f4n5/32G7v90bsP/b1um/25Um/9rUJX/akmS/2Y4fv9THl7/SFmQ/3vO8P9Xqv3/Po71/2W19/+k4/7/mNj8/5/d/f+s6fz/kNT8/3zB+P+g4P3/oeH9/6Ti/P+h3P7/isTz/z902/86atX/jMT1/2GAxf8tK4j/VGKp/4er1v8yMYj/fJrN/2J2s/80LIP/NjaQ/3qe1v95oOD/O0Sv/2qa3f+Es+j/dFXI/3hh1P95dOz/enPs/3x97/+Gl///eXK7/2c9d/9nM3b/aDWH/2o7k/9qOZP/aDSJ/2lGkP9wXaD/Z1aY/1Nzrv9ywef/WrX//z6Y9f99vOD/q+v//5rb/P+o5vz/qOf8/2qz+P99vvT/puj//6fm/P+m4/3/o+H8/1qU5v83bd3/VY/m/5nQ9f9pi8z/Umm2/01jsv9UarX/TWS0/1Fls/9UaLT/dpfS/5XD8P9IYcH/RE60/2ma3P+Esef/dFjK/3pt5P97ce7/fX7w/4aZ//9xWJv/Yypl/2s7kf9tQ6P/bkip/21DpP9uUKb/fIzT/4i09v+Px///l9L//5DE+P9ooNb/ZK3Y/1u9//86gMj/hb3V/7L0//+e3fz/rur8/4fQ/P9KlPP/g8Hy/6nr//+x6/z/rOn9/4/O9/9BgOX/OXPe/0+M5/+DwPf/icT1/4fC9f+HwfX/icH1/4i/8/+KwPT/erHx/0VqzP9BU7X/RVG2/2ma3f+Dr+T/dF3T/3tw7P98ee7/hJn//3Zru/9kKmP/bkKg/21Do/9sRqj/bESm/3Fcs/+DqvL/isL//5HL/v+Uz/z/ksz8/5TQ//+Y0v//d7Dk/1+k1f9Squv/LmCa/4TD4P+18///qOX8/6Xk+/9gsvz/RI3v/3Wz7/+o6P3/uvP+/7Ht/v95vPT/PIXq/zyA6P84e+T/Onvj/zh03v81a9f/OGvX/zls1/85adX/N2PU/z9r1v9EYcT/Q0+z/2ia3v+BrOL/dmTe/3px7f9/jPf/gpL5/2k9ev9pOYr/bEKh/2xDpf9rQqr/blKx/4On8/+Hu///kcn6/5PP/f+Szf7/lM79/5PN/v+Ry/7/mdP//4vD9P9oq+H/Ony8/yxcmf98w+b/svH//7Lt/f+O1vv/V6/8/0OM8P9Xmev/i872/7Lw/P+89/7/g8j3/0SW9P9Blvf/R534/0eg+P9FmPD/PoDj/z1w2v8/b9n/QHDa/0Fu2v9Db9n/QVa7/2ea3P+Bq+P/d2jm/3x88f+Cmv//e3zi/2Y0c/9rPpn/akCg/2xFqf9pQ6f/fIzf/4W3//+Nwvr/ldH+/5LO/f+Szv3/ks7+/5HN/f+Qy/3/j8j8/5HM//+Z1v//g8b1/1uTyv9fmtX/abHf/6bo+v+48v//gtH6/1+5/P9GlvL/OoTt/1ai8P9/x/b/pOX6/5XZ+P9dsPb/SKH5/0mm+/9Kr/3/TbD9/0WU8f88d+H/PXDb/z9v2v9Ccd3/QWTP/2eb3v+BquP/eGvq/3+J9/+Bmv//d3LW/2Mydv9rP5z/akKi/2lBpf9tWLX/gqz6/4a3/P+V0P3/lM/9/5PP/f+Tz/3/j8z9/5HL/f+Xzvz/mtP+/5vT/P+GqeP/haTg/4ex4f+QwvH/hcX7/2Kt4/+P1vT/se/+/37R+/9pxfv/VKn3/zmO8/83jfP/QJXz/1mq9v9htPf/Tqf5/0ml+/9Kqvv/UbT8/1i7/f9Jnvb/O3zl/z5w2f9Actz/P2zZ/2ej5/+BqOL/eW/t/4GU+/+Alv//eXTc/2I0eP9pPpz/akKj/2c/of9zcsn/grL//4q9+/+X0/3/k879/5PP/f+Szv7/mdP9/6be/P+u5/3/ten4/42bw/92mtf/ibrj/3uix/9iaJb/fZG7/4y+7v9wtuv/ecPu/5Xc+v92zP7/csv7/2S9+f9Kpfn/QJv4/z+b+f9Anfv/RaP7/0eo/P9Nrfz/T7H9/16+/f9gvfv/Rpn4/z575P8+cNr/Pm/c/2ep7v+ApuL/enfx/4KZ/f9+kP3/envs/2Q6f/9nO5X/aUOi/2Q9nf91gdX/gbL//4vB+/+X0/7/ltL//5PO/v+f1fv/sej9/7Dm/f+38f3/gnmf/2JvzP97zP//jeD//5Dk//91vfb/XFWN/3JvlP+RwO7/h8X2/3K67v9wwvb/asX//3HI+/93zPr/Y736/0ut/P9Iqvz/Sqv7/0ir/P9Mrvz/ULL9/1q6/P9tyvz/W7L5/0KR9/9AeuH/Pm7b/2eq7/9/peL/e371/4Ga/f99j/n/fYP9/2lJlv9jNon/ZkKi/2Q9mf92hNb/g7L//4rB+/+X1P//ksfu/4+/8v+gx/L/t+v9/7Tw//+dtMP/a1SS/3SO8/9to/j/can6/3a0+/9xqvv/bILv/3dokf+BjLT/ha3h/5rW/P93uO7/V6jp/23I//9owPv/f9H7/4rZ+/9wyfv/Wbr9/1a4/f9Wt/z/VLX9/1m4/P9uyPz/c8z8/0uf+f9Dj/T/PG/b/2Sp7v+ApuL/e4P3/4CY/v9/lPv/fIX//3Rnyv9fMXr/ZECf/2A6k/90f9L/grL//4i8+v+Y1///j8Pt/3uRv/+Op+n/r9v0/8H8//96aoP/e2ul/4OI3f9of+n/a4nj/2uN6f9whu7/c2/j/2I5jf+Umqn/eIG2/4y76/+g3v7/bZzM/2Cezf+D3f//b8T6/3XK/P+a5Pz/nOb8/3jP/P9jw/z/ZcT9/2TC/f9ow/z/gdj9/2S5+f9Dl/v/P3/o/2Wl7P9/p+L/e4f4/4Ga/v9/l/z/e4X6/32C+f9lQo7/XzaL/143kP9tbMD/gK///4S2+/+W1P7/ldD6/255nf95frj/kavq/7Xj9v9vUWH/WCJw/2lMtv9nULH/UydT/1UqWP9qUrH/aUGq/14kdP93XXX/nbXR/2FcmP+W0/3/nNb3/1xmhP9cgaT/lOj//4XW/P9wxvr/jdv8/63x/P+W4fv/c838/3DM/f9wzP3/e9P8/4TV+/9Knvj/QpD1/2as8P9/puL/fYv5/4Gd/v+Anfz/fY76/3yH/v93cNn/XDF5/1w3jv9kUaP/fqf7/3+u+/+Tzv3/mtf8/2x+qf9TO1j/hI7S/42g4f9bN0f/VBpB/2M0fP9bKmP/TRgv/04cMv9VHk7/dlyS/2g9a/9WHzv/rs7h/2JOfv9/nNH/m+H//5fL7f9ROkn/SFd4/4rc//+X6P//c8v5/3/V/P+p8P3/qO78/4HW+/910P7/eNL9/5Lj/f9ktvj/QZL3/2m5+P9+puD/e4z5/4Gg/f+Aof3/fJX8/3uN+P98hP//bViy/1ktc/9bOon/do3h/3uq/v+Gufn/nd3//4Os4/9BHDn/VTZM/4uY3/9YOlL/Rw4d/1UhRP9UIED/Rw4h/08oQ/9JGTb/c15y/2lGaP9ICh//orrK/3VwoP9HI1D/jbzy/53i//+TwOb/TSIu/zszTf90wOr/nfD//3jQ+P9zz/v/o+38/6/0/f+H2/v/dM/8/47h/f+E0vv/QZP2/22+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
::KITSUMI-PY::
# Kitsumi Live Server - Copyright (c) 2026 Olexify. All rights reserved. Free to use, not open source.
# Licence: https://github.com/Olexify/KitsumiLiveServer/blob/main/LICENSE - no warranty; the models and libraries it
# runs are other people's work under their own licences (THIRD-PARTY-NOTICES.md).
"""Kitsumi live subtitles: speech-to-text on your own computer (guide: README.md beside this file).
Speaks OpenAI's API: POST /v1/audio/transcriptions (multipart: file, language, prompt) -> { text, segments }.
Run:  python whisper_server.py [model] [port]      no model (or "auto") = by language: Japanese gets the
      Japanese-only model on a graphics card, everything else large-v3-turbo (small on a processor); port 8000
In Kitsumi: Local -> Live generate on this page -> Your own server, address http://localhost:8000/v1, no key.
Only this computer can reach it (127.0.0.1) - unless KITSUMI_KEY is set: then a tunnel (Colab, a home server)
may bring other addresses in, and every request must carry that key (Kitsumi: the key field). Models are kept in the folder WHISPER_MODELS names, else the usual cache."""
import gc, glob, hmac, io, json, os, subprocess, sys, threading, time, wave
from email.parser import BytesParser
from email.policy import HTTP
from http.server import BaseHTTPRequestHandler, HTTPServer
import numpy as np

# pip-installed CUDA dlls (nvidia-cublas/cudnn) aren't on PATH by default on Windows
for d in glob.glob(os.path.join(sys.prefix, "Lib", "site-packages", "nvidia", "*", "bin")):
    os.add_dll_directory(d)
    os.environ["PATH"] = d + os.pathsep + os.environ["PATH"]

from faster_whisper import WhisperModel
from faster_whisper.utils import download_model

# The model: named on the command line = that one, always. Otherwise it follows the language Kitsumi sends:
# Japanese gets the Japanese-only model (better on Japanese; graphics card only - it is too heavy for a processor),
# everything else the general one. One model is in memory at a time, swapped when the language changes.
FIXED = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "auto" else ""
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
ROOT = os.environ.get("WHISPER_MODELS") or None
JA_MODEL = "kotoba-tech/kotoba-whisper-v2.0-faster"
# Behind a tunnel the address is the tunnel's, not localhost: with a key set, the key decides instead of the address.
KEY = (os.environ.get("KITSUMI_KEY") or "").strip()
if KEY and len(KEY) < 16:  # a short key can be guessed by trying; the server has no limit on attempts
    sys.exit("KITSUMI_KEY is too short: use at least 16 random characters")


def load(name):
    """The graphics card when it works (a 1 s test run tells), else the processor."""
    try:
        m = WhisperModel(name or "large-v3-turbo", device="cuda", compute_type="float16", download_root=ROOT)
        list(m.transcribe(np.zeros(16000, np.float32), language="en")[0])
        return m, name or "large-v3-turbo", "graphics card"
    except Exception as e:
        print(f"No usable NVIDIA graphics card ({str(e)[:120]}) - using the processor, slower.", flush=True)
        return WhisperModel(name or "small", device="cpu", compute_type="int8", download_root=ROOT), name or "small", "processor"


model, MODEL, DEVICE = load(FIXED)
GENERAL = MODEL
ja = {"state": "no"}  # no / loading (being downloaded) / ready / failed


def ja_fetch():
    try:
        download_model(JA_MODEL, cache_dir=ROOT)
        ja["state"] = "ready"
        print("The Japanese model is ready: Japanese lines use it from now on.", flush=True)
    except Exception as e:
        ja["state"] = "failed"
        print(f"The Japanese model could not be downloaded ({str(e)[:120]}) - Japanese stays on {GENERAL}.", flush=True)


def model_for(lang):
    """Swaps the model in memory to the one for this language (only without a fixed model, on a graphics card)."""
    global model, MODEL
    if FIXED or DEVICE != "graphics card":
        return model
    want = GENERAL
    if lang == "ja":
        if ja["state"] == "no":
            try:
                download_model(JA_MODEL, cache_dir=ROOT, local_files_only=True)  # already on disk?
                ja["state"] = "ready"
            except Exception:
                ja["state"] = "loading"
                print(f"Downloading the Japanese model ({JA_MODEL}, 1.5 GB) - until it is here Japanese uses {GENERAL}.", flush=True)
                threading.Thread(target=ja_fetch, daemon=True).start()
        if ja["state"] == "ready":
            want = JA_MODEL
    if want != MODEL:
        t = time.time()
        model = None
        gc.collect()  # the old one leaves the graphics card's memory first
        try:
            model = WhisperModel(want, device="cuda", compute_type="float16", download_root=ROOT)
            MODEL = want
        except Exception as e:  # it must keep answering
            print(f"Could not load {want} ({str(e)[:120]}) - back to {GENERAL}.", flush=True)
            if want == JA_MODEL:
                ja["state"] = "failed"
            model = WhisperModel(GENERAL, device="cuda", compute_type="float16", download_root=ROOT)
            MODEL = GENERAL
        print(f"Model for this language: {MODEL} ({time.time() - t:.1f} s to switch)", flush=True)
    return model


def pcm16k(data):
    """Audio bytes -> float32 mono 16 kHz. Kitsumi sends exactly that as WAV; anything else goes through ffmpeg."""
    if data[:4] == b"RIFF":
        try:
            with wave.open(io.BytesIO(data)) as w:
                if w.getframerate() == 16000 and w.getnchannels() == 1 and w.getsampwidth() == 2:
                    return np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
        except wave.Error:
            pass
    # -protocol_whitelist: ffmpeg reads only the bytes sent, never a file or an address a crafted playlist names
    out = subprocess.run(["ffmpeg", "-v", "error", "-protocol_whitelist", "pipe", "-i", "pipe:0", "-ac", "1", "-ar", "16000", "-f", "f32le", "-"],
                         input=data, capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32)


class H(BaseHTTPRequestHandler):
    def reply(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.reply(200, {"ok": True, "model": MODEL, "device": DEVICE, "byLanguage": not FIXED and DEVICE == "graphics card", "japanese": ja["state"]})

    def do_POST(self):
        # A web page must not make this computer transcribe. Every browser names the caller in Origin on a POST from a
        # page ("null" for a sandboxed one): only extensions pass, and local tools, which send none. The Host check
        # stops a site that points its own name at 127.0.0.1.
        origin, host = self.headers.get("Origin"), (self.headers.get("Host") or "").rsplit(":", 1)[0]
        if not (origin is None or origin.startswith(("moz-extension://", "chrome-extension://"))):
            return self.reply(403, {"error": "only Kitsumi and programs on this computer may call this server"})
        if KEY:  # remote mode: the key, compared in constant time; any address (the tunnel's name)
            if not hmac.compare_digest((self.headers.get("Authorization") or "").encode(), ("Bearer " + KEY).encode()):
                return self.reply(401, {"error": "wrong or missing key - put the server's KITSUMI_KEY in Kitsumi's key field"})
        elif host not in ("localhost", "127.0.0.1"):
            return self.reply(403, {"error": "this server answers only on localhost - for a tunnel (Colab), start it with KITSUMI_KEY set"})
        if not self.path.rstrip("/").endswith("/audio/transcriptions"):
            return self.reply(404, {"error": "POST /v1/audio/transcriptions"})
        n = int(self.headers.get("Content-Length") or 0)
        if not 0 < n <= 200 << 20:
            return self.reply(413, {"error": "no audio, or over 200 MB"})
        head = b"Content-Type: " + self.headers.get("Content-Type", "").encode("latin1") + b"\r\n\r\n"
        f = {p.get_param("name", header="content-disposition"): p.get_payload(decode=True)
             for p in BytesParser(policy=HTTP).parsebytes(head + self.rfile.read(n)).iter_parts()}
        if not f.get("file"):
            return self.reply(400, {"error": "no 'file' part"})
        text = lambda k: (f.get(k) or b"").decode("utf-8", "replace").strip()
        t0 = time.time()
        try:
            audio = pcm16k(f["file"])
            segs, _ = model_for(text("language")).transcribe(audio, language=text("language") or None, initial_prompt=text("prompt") or None,
                                       condition_on_previous_text=False, vad_filter=True, temperature=0)
            segs = [{"start": round(s.start, 2), "end": round(s.end, 2), "text": s.text.strip(), "avg_logprob": s.avg_logprob,
                     "compression_ratio": s.compression_ratio, "no_speech_prob": s.no_speech_prob} for s in segs]
        except Exception as e:  # a bad file must not stop the server
            return self.reply(500, {"error": str(e)[:300]})
        print(f"{len(audio) / 16000:5.1f} s of sound -> {time.time() - t0:4.2f} s  {' '.join(s['text'] for s in segs)[:70]}", flush=True)
        self.reply(200, {"text": " ".join(s["text"] for s in segs), "segments": segs})

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    print(f"Kitsumi whisper server: http://localhost:{PORT}/v1  model {MODEL if FIXED or DEVICE != "graphics card" else MODEL + " (Japanese: " + JA_MODEL + ")"} on the {DEVICE}  (Ctrl+C stops it)" + ("  - key required (KITSUMI_KEY)" if KEY else ""), flush=True)
    HTTPServer(("127.0.0.1", PORT), H).serve_forever()  # one request at a time: the GPU does one anyway
