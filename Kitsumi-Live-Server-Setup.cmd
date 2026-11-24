@echo off
rem Kitsumi live server - setup for Windows. SOURCE of Kitsumi-Live-Server-Setup.cmd: node tools/build-privacy.js
rem puts whisper_server.py under it, so the one downloaded file holds everything it installs of Kitsumi's.
rem It is plain text: open it in Notepad to read what it does before running it.
setlocal
set "KSELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=[IO.File]::ReadAllText($env:KSELF) -split '(?m)^::KITSUMI-PS::\r?\n|^::KITSUMI-PY::\r?\n'; $KPY=$p[2]; iex $p[1]"
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
$model = if ($nvidia) { 'large-v3-turbo' } else { 'small' }
$need = if ($nvidia) { 'about 5 GB' } else { 'about 1.5 GB' }

function New-SetupForm {
  $f = New-Object Windows.Forms.Form -Property @{ Text = 'Kitsumi live server - setup'; ClientSize = '540,306'; FormBorderStyle = 'FixedDialog'; MaximizeBox = $false; MinimizeBox = $false; StartPosition = 'CenterScreen'; Font = (New-Object Drawing.Font('Segoe UI', 9)) }
  $add = { param($type, $props) $c = New-Object "Windows.Forms.$type" -Property $props; $f.Controls.Add($c); $c }
  $card = if ($nvidia) { 'NVIDIA graphics card found: the big model, lines in under a second.' } else { 'No NVIDIA graphics card found: the small model on the processor, lines in about two seconds.' }
  $null = & $add Label @{ Location = '16,14'; Size = '508,92'; Text = "This installs the program that writes Kitsumi's live subtitles on your own computer: free, no account, the sound never leaves it.`r`n`r`nEverything goes into the one folder below. Nothing else on the computer is changed, and deleting the folder removes it." }
  $null = & $add Label @{ Location = '16,112'; Size = '508,18'; Text = 'Install into:' }
  $path = & $add TextBox @{ Location = '16,132'; Size = '412,23'; Text = (Join-Path $env:LOCALAPPDATA 'KitsumiLiveServer'); Name = 'path' }
  $browse = & $add Button @{ Location = '436,131'; Size = '88,25'; Text = 'Browse...' }
  $null = & $add Label @{ Location = '16,164'; Size = '508,54'; Text = "$card`r`nNeeds $need of free space there and an internet connection (Python and the speech library are downloaded)." }
  $null = & $add CheckBox @{ Location = '18,224'; Size = '400,22'; Text = 'Put a shortcut on the desktop'; Checked = $true; Name = 'shortcut' }
  $ok = & $add Button @{ Location = '340,264'; Size = '88,28'; Text = 'Install'; DialogResult = 'OK' }
  $cancel = & $add Button @{ Location = '436,264'; Size = '88,28'; Text = 'Cancel'; DialogResult = 'Cancel' }
  $f.AcceptButton = $ok; $f.CancelButton = $cancel
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
  $shortcut = $true
  if ($env:KITSUMI_DIR) { $dir = $env:KITSUMI_DIR; $shortcut = $false }   # no questions: for tests
  else {
    $form = New-SetupForm
    if ($form.ShowDialog() -ne 'OK') { exit 0 }
    $dir = $form.Controls['path'].Text.Trim().Trim('"'); $shortcut = $form.Controls['shortcut'].Checked
  }
  if (-not $dir -or -not [IO.Path]::IsPathRooted($dir)) { throw "That is not a full folder path: '$dir'" }
  $dir = [IO.Path]::GetFullPath($dir)
  $null = New-Item -ItemType Directory -Force $dir
  # room on that drive, asked before anything is downloaded
  $needGB = if ($nvidia) { 6 } else { 2 }
  $freeGB = try { [math]::Floor((New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($dir))).AvailableFreeSpace / 1GB) } catch { 999 }
  if ($freeGB -lt $needGB) { throw "Not enough room on that drive: $freeGB GB free, about $needGB GB needed. Choose a folder on another drive." }
  Write-Host "Installing into $dir"

  [IO.File]::WriteAllText((Join-Path $dir 'whisper_server.py'), $KPY)

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

  $start = Join-Path $dir 'Start Kitsumi live server.cmd'
  [IO.File]::WriteAllText($start, "@echo off`r`ntitle Kitsumi live server`r`nrem In Kitsumi: Local - Live generate on this page - Your own server, address http://localhost:8000/v1, no key.`r`nset PYTHONUTF8=1`r`nset `"WHISPER_MODELS=%~dp0models`"`r`n`"%~dp0venv\Scripts\python.exe`" `"%~dp0whisper_server.py`" $model`r`npause`r`n", [Text.Encoding]::ASCII)
  if ($shortcut) {
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Kitsumi live server.lnk'))
    $lnk.TargetPath = $start; $lnk.WorkingDirectory = $dir; $lnk.Save()
  }
  Write-Host "`nDone. Start it with: $start" -ForegroundColor Green
  if (-not $env:KITSUMI_DIR) {
    $size = if ($nvidia) { '1.6 GB' } else { '0.5 GB' }
    $go = [Windows.Forms.MessageBox]::Show("Installed.`r`n`r`nStart it now? The first start downloads the speech model ($size); after that it starts in seconds.`r`n`r`nThen in Kitsumi: Local - Live generate on this page - Your own server, address http://localhost:8000/v1, key empty.", 'Kitsumi live server', 'YesNo', 'Information')
    if ($go -eq 'Yes') { Start-Process $start -WorkingDirectory $dir }
  }
  exit 0
} catch {
  Write-Host "`nSetup stopped: $($_.Exception.Message)" -ForegroundColor Red
  if (-not $env:KITSUMI_DIR) { $null = [Windows.Forms.MessageBox]::Show("Setup stopped:`r`n$($_.Exception.Message)`r`n`r`nNothing outside the chosen folder was changed. You can run the setup again - it continues in the same folder.`r`nHelp: discord.gg/UpmNHxT7PF", 'Kitsumi live server', 'OK', 'Error') }
  exit 1
}
::KITSUMI-PY::
"""Kitsumi live subtitles: speech-to-text on your own computer (guide: README.md beside this file).
Speaks OpenAI's API: POST /v1/audio/transcriptions (multipart: file, language, prompt) -> { text, segments }.
Run:  python whisper_server.py [model] [port]      default: large-v3-turbo on port 8000
In Kitsumi: Local -> Live generate on this page -> Your own server, address http://localhost:8000/v1, no key.
Only this computer can reach it (127.0.0.1). Models are kept in the folder WHISPER_MODELS names, else the usual cache."""
import glob, io, json, os, subprocess, sys, time, wave
from email.parser import BytesParser
from email.policy import HTTP
from http.server import BaseHTTPRequestHandler, HTTPServer
import numpy as np

# pip-installed CUDA dlls (nvidia-cublas/cudnn) aren't on PATH by default on Windows
for d in glob.glob(os.path.join(sys.prefix, "Lib", "site-packages", "nvidia", "*", "bin")):
    os.add_dll_directory(d)
    os.environ["PATH"] = d + os.pathsep + os.environ["PATH"]

from faster_whisper import WhisperModel

MODEL = sys.argv[1] if len(sys.argv) > 1 else "large-v3-turbo"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
ROOT = os.environ.get("WHISPER_MODELS") or None


def load():
    """The graphics card when it works (a 1 s test run tells), else the processor."""
    try:
        m = WhisperModel(MODEL, device="cuda", compute_type="float16", download_root=ROOT)
        list(m.transcribe(np.zeros(16000, np.float32), language="en")[0])
        return m, "graphics card"
    except Exception as e:
        print(f"No usable NVIDIA graphics card ({str(e)[:120]}) - using the processor, slower.", flush=True)
        return WhisperModel(MODEL, device="cpu", compute_type="int8", download_root=ROOT), "processor"


model, DEVICE = load()


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
        self.reply(200, {"ok": True, "model": MODEL, "device": DEVICE})

    def do_POST(self):
        # A web page must not make this computer transcribe. Every browser names the caller in Origin on a POST from a
        # page ("null" for a sandboxed one): only extensions pass, and local tools, which send none. The Host check
        # stops a site that points its own name at 127.0.0.1.
        origin, host = self.headers.get("Origin"), (self.headers.get("Host") or "").rsplit(":", 1)[0]
        if host not in ("localhost", "127.0.0.1") or not (origin is None or origin.startswith(("moz-extension://", "chrome-extension://"))):
            return self.reply(403, {"error": "only Kitsumi and programs on this computer may call this server"})
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
            segs, _ = model.transcribe(audio, language=text("language") or None, initial_prompt=text("prompt") or None,
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
    print(f"Kitsumi whisper server: http://localhost:{PORT}/v1  model {MODEL} on the {DEVICE}  (Ctrl+C stops it)", flush=True)
    HTTPServer(("127.0.0.1", PORT), H).serve_forever()  # one request at a time: the GPU does one anyway
