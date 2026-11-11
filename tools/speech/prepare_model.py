"""Repack the upstream Russian Vosk model for the browser (standard library only)."""
import argparse
import hashlib
import gzip
import io
from pathlib import Path
import tarfile
import urllib.request
import zipfile

URL = "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip"
SHA256 = "961d5ff98a17f4aa6de69864d0aa71fa5bac682301d2b5d17a3f24c5c99a46d4"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", type=Path, help="Use an already downloaded upstream ZIP")
    args = parser.parse_args()
    data = args.zip.read_bytes() if args.zip else urllib.request.urlopen(URL, timeout=120).read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SHA256:
        raise ValueError(f"Unexpected upstream model SHA256: {digest}")
    target = Path(__file__).resolve().parents[2] / "html/speech/vosk-model-small-ru-0.22.tar.gz"
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as source, target.open("wb") as output, gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0, compresslevel=6) as compressed, tarfile.open(fileobj=compressed, mode="w", format=tarfile.USTAR_FORMAT) as archive:
        directories = {"model"}
        for item in source.infolist():
            parts = Path(item.filename).parts[1:]
            for depth in range(1, len(parts)):
                directories.add("model/" + "/".join(parts[:depth]))
        for name in sorted(directories):
            info = tarfile.TarInfo(name)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            archive.addfile(info)
        for item in source.infolist():
            if item.is_dir():
                continue
            parts = Path(item.filename).parts[1:]
            if not parts or ".." in parts:
                raise ValueError("Unexpected archive member")
            payload = source.read(item)
            info = tarfile.TarInfo("model/" + "/".join(parts))
            info.size = len(payload)
            info.mode = 0o644
            archive.addfile(info, io.BytesIO(payload))
    print(f"Created {target}: {target.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
