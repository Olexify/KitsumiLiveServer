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
