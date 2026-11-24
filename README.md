# Live subtitles from your own computer

Kitsumi can write subtitles for any video while you watch it, from the video's sound.
This small server does the listening on your own computer: free, private, no account and no key.
Nothing leaves your computer. The sound goes from your browser to this program and the text comes back.

## The easy way (Windows)

1. Download [Kitsumi-Live-Server-Setup.cmd](https://github.com/Olexify/KitsumiLiveServer/releases/latest/download/Kitsumi-Live-Server-Setup.cmd) and double-click it.
2. Windows may say it protected your PC, because the file is new and not signed: press **More info**, then **Run anyway**.
   The file is plain text: right-click it and choose Edit to read everything it does.
3. Choose the folder, press **Install** and wait. Python and the speech library are downloaded into that one folder
   (about 5 GB with an NVIDIA graphics card, about 1.5 GB without). Nothing else on the computer is changed.
4. Start it with the **Kitsumi live server** shortcut on the desktop, then go to **Connect Kitsumi** below.

To remove it, delete the folder and the shortcut. The setup is new: if it stops, tell us on
[Discord](https://discord.gg/UpmNHxT7PF) what it said. The source is at
[github.com/Olexify/KitsumiLiveServer](https://github.com/Olexify/KitsumiLiveServer).

## By hand (Windows, Mac, Linux)

### What you need

- Python 3.9 or newer ([python.org](https://www.python.org/downloads/)).
- About 2 GB of disk space for the speech model (downloaded once, on the first start).
- An NVIDIA graphics card with 4 GB or more is best: a line is ready in under a second.
  Without one the server uses the processor: pick the `small` model (see below) and a line takes about
  two seconds on a recent laptop.

### Set it up (once)

**1.** Get `whisper_server.py`: the download link at the top of this page, or the file beside this guide.
Put it in any folder.

**2.** Install the speech library. Open a terminal (on Windows: PowerShell) and run:

```
pip install faster-whisper
```

**3.** Only with an NVIDIA graphics card, also run:

```
pip install nvidia-cublas-cu12 nvidia-cudnn-cu12
```

### Start it

In the folder with the file, run:

```
python whisper_server.py
```

The first start downloads the model. When you see
`Kitsumi whisper server: http://localhost:8000/v1 ...` it is ready. It also says whether it runs on the
graphics card or the processor. Leave the window open while you watch; Ctrl+C stops it.

## Connect Kitsumi

1. Open a page with a video and open Kitsumi.
2. Search tab -> Local -> **Live generate on this page**.
3. Service: **Your own server**. Address: `http://localhost:8000/v1`. Leave the key empty.
4. Press start and play the video. Lines appear about a second after they are said.

Kitsumi sends the language you are learning, so set that first.

## Models

Give the model as the first word after the file name, the port as the second:

```
python whisper_server.py small
python whisper_server.py kotoba-tech/kotoba-whisper-v2.0-faster 8000
```

| Model | Size | Good for |
|---|---|---|
| `large-v3-turbo` (default) | 1.6 GB | Any language, a graphics card |
| `small` | 0.5 GB | Any language, no graphics card |
| `kotoba-tech/kotoba-whisper-v2.0-faster` | 1.5 GB | Japanese only |

To keep the models in a folder of your choice, set `WHISPER_MODELS` to that folder before starting.

## Share what you made

When Kitsumi has listened to 90 % of a video, the same panel shows **Share this track on Kitsumi Vault**.
It saves the subtitle file and opens the Vault's upload page, so the next person does not have to make it again.
A machine-made track has mistakes: say in the upload that it was made by AI.

## Questions

- **Is it safe?** The server answers only programs on your own computer (address 127.0.0.1), and it refuses
  requests that come from web pages. It is one short file; read it before you run it.
- **What goes over the internet?** While it runs: nothing, the server talks only to your own browser. Setting it
  up downloads Python, the speech library and the model from GitHub, PyPI and Hugging Face, which see your
  internet address as with any download.
- **"No usable NVIDIA graphics card"**: the server went on with the processor. With an NVIDIA card, install
  the two packages from step 3 and update the card's driver. On Linux the folders of those packages must also
  be on `LD_LIBRARY_PATH` (see the faster-whisper page).
- **Lines are slow or late**: use a smaller model, or in Kitsumi set the pace to "In bigger pieces".
- **Port 8000 is taken**: start with another port (`python whisper_server.py large-v3-turbo 8123`) and use it
  in the address.
- **A server somewhere else** (Modal, Colab, a home server): Kitsumi works with any address that speaks
  OpenAI's transcription API (`POST <address>/audio/transcriptions`). Put its address and key in the same fields.
  Then the sound of your video goes to that server.

## Credits and licences

[faster-whisper](https://github.com/SYSTRAN/faster-whisper) (MIT) runs OpenAI's Whisper models (MIT).
Kotoba-Whisper is by Kotoba Technologies (MIT). With an NVIDIA graphics card, NVIDIA's own libraries are
installed under NVIDIA's licence. Everything that gets downloaded is listed with its licence in
[THIRD-PARTY-NOTICES.md](https://github.com/Olexify/KitsumiLiveServer/blob/main/THIRD-PARTY-NOTICES.md).
Kitsumi Live Server itself is free to use, not open source
([LICENSE](https://github.com/Olexify/KitsumiLiveServer/blob/main/LICENSE)).
