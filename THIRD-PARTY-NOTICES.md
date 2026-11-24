# Third-party software and models

Nothing in this list is included in this repository. The setup file (or you, following the guide by hand)
downloads each item to your computer from its own publisher, and each keeps its own licence.
Kitsumi Live Server's own licence (LICENSE) does not apply to any of them.

## Downloaded by the setup file

| What | Publisher | Licence | Downloaded from |
| :--- | :--- | :--- | :--- |
| uv 0.12.17 (installs Python and the packages; its SHA-256 is checked) | Astral | MIT or Apache-2.0 | github.com/astral-sh/uv releases |
| Python 3.14 (a standalone build) | Python Software Foundation; built by Astral (python-build-standalone) | PSF License 2.0; the build's bundled libraries keep their own licences | github.com/astral-sh/python-build-standalone releases |
| faster-whisper 1.2.1 (includes the Silero VAD model, MIT) | SYSTRAN | MIT | pypi.org |
| CTranslate2 4.8.3 | OpenNMT | MIT | pypi.org |
| PyAV 19.0.2 (includes FFmpeg libraries under FFmpeg's own licences) | PyAV contributors | BSD-3-Clause | pypi.org |
| ONNX Runtime 1.31.0 | Microsoft | MIT | pypi.org |
| NumPy 2.5.4 | NumPy developers | BSD-3-Clause and others stated in the package | pypi.org |
| tokenizers 0.23.3 | Hugging Face | Apache-2.0 | pypi.org |
| huggingface_hub 2.2.0 | Hugging Face | Apache-2.0 | pypi.org |
| Other packages these depend on | their authors | as stated in each package | pypi.org |

## Only on a computer with an NVIDIA graphics card

| What | Publisher | Licence | Downloaded from |
| :--- | :--- | :--- | :--- |
| nvidia-cublas-cu12 12.9.2.10 (cuBLAS) | NVIDIA | NVIDIA proprietary licence (the package states "NVIDIA Proprietary Software"); not open source | pypi.org, NVIDIA's own package |
| nvidia-cudnn-cu12 9.27.0.42 (cuDNN) | NVIDIA | NVIDIA proprietary licence; not open source | pypi.org, NVIDIA's own package |

By installing these you accept NVIDIA's licence terms for them. If you do not, install without them: the
server then runs on the processor.

## Speech models, downloaded on the first start

| Model | Publisher | Licence | Downloaded from |
| :--- | :--- | :--- | :--- |
| large-v3-turbo (`mobiuslabsgmbh/faster-whisper-large-v3-turbo`, a conversion of OpenAI's Whisper large-v3-turbo) | OpenAI; converted by Mobius Labs | MIT | huggingface.co |
| small (`Systran/faster-whisper-small`, a conversion of OpenAI's Whisper small) | OpenAI; converted by SYSTRAN | MIT | huggingface.co |
| `kotoba-tech/kotoba-whisper-v2.0-faster` (only if you choose it) | Kotoba Technologies | MIT | huggingface.co |

Licences are given as each publisher stated them on 2026-11-24. Any other model you start the server with
keeps the licence its publisher gave it: check its page before you use it.
