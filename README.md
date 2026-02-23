# Video Multitrack Audio Mixer

[한국어](#한국어) | [English](#english)

---

## 한국어

영상 파일의 여러 오디오 트랙을 선택하여 하나로 믹싱하는 Windows 배치 스크립트입니다.

### 기능

- **run_mp4_to_mp4.bat** — MP4 입력 → MP4 출력 (AAC 320kbps)
- **FAST_run_to_mkv_batch.bat** — MP4/MKV 입력 → MKV 출력 (FLAC 무손실)

### 주요 특징

- 원하는 오디오 트랙 번호를 조합하여 믹싱 (예: `2345`, `23`)
- 대용량 파일을 세그먼트로 분할 후 병렬 처리하여 빠른 속도
- 영상 코덱은 재인코딩 없이 원본 유지 (`-c:v copy`)
- CPU 코어 수에 따라 자동으로 병렬 작업 수 조절

### 폴더 구조

```
Video-Multitrack-Audio-Mixer/
├── ffmpeg/
│   ├── ffmpeg.exe        ← FFmpeg 바이너리
│   └── ffprobe.exe       ← FFprobe 바이너리
├── in/                   ← 입력 파일을 여기에 넣으세요
├── out/                  ← 출력 파일이 여기에 생성됩니다
├── run_mp4_to_mp4.bat
├── FAST_run_to_mkv_batch.bat
├── LICENSE
└── README.md
```

### 설치 방법

#### 방법 1: Release ZIP 다운로드 (권장)

1. [Releases](../../releases) 페이지에서 최신 ZIP 파일을 다운로드합니다.
2. 압축을 풀면 바로 사용할 수 있습니다.

#### 방법 2: 직접 설치

1. 이 저장소를 클론합니다.
2. [FFmpeg Builds](https://github.com/BtbN/FFmpeg-Builds/releases)에서 `ffmpeg-master-latest-win64-gpl.zip`을 다운로드합니다.
3. `ffmpeg.exe`와 `ffprobe.exe`를 `ffmpeg/` 폴더에 넣습니다.

### 사용법

1. 변환할 영상 파일을 `in/` 폴더에 넣습니다.
2. 원하는 배치 파일을 실행합니다.
3. 믹싱할 오디오 트랙 번호를 입력합니다 (기본값: `2345`).
4. 완료되면 `out/` 폴더에서 결과물을 확인합니다.

### 출력 비교

| 항목 | run_mp4_to_mp4 | FAST_run_to_mkv_batch |
|------|----------------|----------------------|
| 출력 형식 | MP4 | MKV |
| 오디오 코덱 | AAC 320kbps | FLAC (무손실) |
| 입력 형식 | MP4 | MP4, MKV |

---

## English

Windows batch scripts for mixing multiple audio tracks from video files into a single track.

### Features

- **run_mp4_to_mp4.bat** — MP4 input → MP4 output (AAC 320kbps)
- **FAST_run_to_mkv_batch.bat** — MP4/MKV input → MKV output (FLAC lossless)

### Highlights

- Select and mix specific audio tracks by number (e.g., `2345`, `23`)
- Segments large files for parallel processing — fast even on big files
- Video stream is copied without re-encoding (`-c:v copy`)
- Auto-scales parallel workers based on CPU core count

### Folder Structure

```
Video-Multitrack-Audio-Mixer/
├── ffmpeg/
│   ├── ffmpeg.exe        ← FFmpeg binary
│   └── ffprobe.exe       ← FFprobe binary
├── in/                   ← Place input files here
├── out/                  ← Output files appear here
├── run_mp4_to_mp4.bat
├── FAST_run_to_mkv_batch.bat
├── LICENSE
└── README.md
```

### Installation

#### Option 1: Download Release ZIP (Recommended)

1. Go to the [Releases](../../releases) page and download the latest ZIP.
2. Extract and use immediately.

#### Option 2: Manual Setup

1. Clone this repository.
2. Download `ffmpeg-master-latest-win64-gpl.zip` from [FFmpeg Builds](https://github.com/BtbN/FFmpeg-Builds/releases).
3. Place `ffmpeg.exe` and `ffprobe.exe` into the `ffmpeg/` folder.

### Usage

1. Place video files in the `in/` folder.
2. Run the desired batch file.
3. Enter audio track numbers to mix (default: `2345`).
4. Find results in the `out/` folder.

### Output Comparison

| | run_mp4_to_mp4 | FAST_run_to_mkv_batch |
|------|----------------|----------------------|
| Format | MP4 | MKV |
| Audio Codec | AAC 320kbps | FLAC (lossless) |
| Input | MP4 only | MP4, MKV |

---

## License

This project includes [FFmpeg](https://ffmpeg.org/) which is licensed under the [GNU General Public License v3.0](LICENSE).

The batch scripts in this project are also distributed under GPLv3.

FFmpeg source code is available at: https://ffmpeg.org/download.html
