"""Package exported binaries into verified ZIPs and a per-user NSIS installer."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
from build import source_signature


ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.3.0-dev'
LICENSES = ('Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'Noto-CJK-COPYRIGHT.txt')
DOCS = ('README.md', 'ARCHITECTURE.md', 'PROGRESS.md', 'CREDITS.md')


def stage(target: str, destination: Path) -> Path:
    binaries = {'Windows': ('windows', 'TribesOfFire.exe'),
                'Linux': ('linux', 'TribesOfFire.x86_64'),
                'Server-Linux': ('server', 'TribesOfFireServer.x86_64')}
    folder, filename = binaries[target]
    source = ROOT / 'builds' / folder / filename
    if not source.is_file() or source.stat().st_size < 1024:
        raise SystemExit(f'Missing exported executable: {source}; run Tools/build.py')
    magic = source.open('rb').read(4)
    if (target == 'Windows' and not magic.startswith(b'MZ')) or (
            target != 'Windows' and magic != b'\x7fELF'):
        raise SystemExit(f'Invalid executable header: {source}')
    destination.mkdir(parents=True)
    shutil.copy2(source, destination / filename)
    for doc in DOCS:
        if not (ROOT / doc).is_file():
            raise SystemExit(f'Missing distribution documentation: {doc}')
        shutil.copy2(ROOT / doc, destination / doc)
    (destination / 'LICENSES').mkdir()
    for name in LICENSES:
        source_license = ROOT / 'LICENSES' / name
        if not source_license.is_file() or source_license.stat().st_size < 100:
            raise SystemExit(f'Missing official engine attribution: {source_license}')
        shutil.copy2(source_license, destination / 'LICENSES' / name)
    if target == 'Server-Linux':
        (destination / 'start-server.sh').write_text(
            '#!/bin/sh\nset -eu\ncd -- "$(dirname -- "$0")"\n'
            'exec ./TribesOfFireServer.x86_64 --headless -- --server "$@"\n',
            encoding='utf-8')
        (destination / 'start-server.sh').chmod(0o755)
    if target == 'Windows':
        (destination / 'SafeMode.cmd').write_text(
            '@echo off\r\ncd /d "%~dp0"\r\n"%~dp0TribesOfFire.exe" -- --safe\r\n',
            encoding='ascii', newline='')
    return destination


def make_zip(source: Path, target: Path) -> None:
    temporary = target.with_suffix('.zip.tmp')
    try:
        with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in sorted(source.rglob('*')):
                if path.is_file():
                    archive.write(path, source.name + '/' + path.relative_to(source).as_posix())
        with zipfile.ZipFile(temporary) as archive:
            bad = archive.testzip()
            if bad is not None or not archive.namelist():
                raise SystemExit(f'ZIP verification failed: {bad}')
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--makensis', help='NSIS compiler path (autodetected when available)')
    parser.add_argument('--zip-only', action='store_true', help='Explicitly omit Windows installer')
    args = parser.parse_args()
    receipt_path = ROOT / 'builds' / 'build-receipt.json'
    if not receipt_path.is_file():
        raise SystemExit('Missing build receipt; run a successful Tools/build.py before packaging')
    receipt = json.loads(receipt_path.read_text())
    if receipt.get('source_sha256') != source_signature():
        raise SystemExit('Application changed after export; rebuild before packaging')
    for relative, expected in receipt.get('targets', {}).items():
        binary = ROOT / 'builds' / relative
        if not binary.is_file() or hashlib.sha256(binary.read_bytes()).hexdigest() != expected:
            raise SystemExit('Export checksum differs from successful build: ' + relative)
    if len(receipt.get('targets', {})) != 3:
        raise SystemExit('Incomplete build receipt')
    out = ROOT / 'dist' 
    out.mkdir(exist_ok=True)
    artifacts: list[Path] = []
    with tempfile.TemporaryDirectory(prefix='tribes-package-') as temp:
        staged: dict[str, Path] = {}
        for platform in ('Windows', 'Linux', 'Server-Linux'):
            name = f'TribesOfFire-{VERSION}-{platform}'
            source = stage(platform, Path(temp) / name)
            staged[platform] = source
            zip_path = out / (name + '.zip')
            make_zip(source, zip_path)
            artifacts.append(zip_path)
        if not args.zip_only:
            compiler = args.makensis or shutil.which('makensis')
            local = Path('/workspace/.cache/tribes-of-fire/nsis/usr/bin/makensis')
            env = os.environ.copy()
            if compiler is None and local.is_file():
                compiler = str(local)
                env['NSISDIR'] = str(local.parents[1] / 'share' / 'nsis')
            if compiler is None:
                raise SystemExit('ZIPs created; installer requires makensis (NSIS 3.x)')
            installer = out / f'TribesOfFire-{VERSION}-Windows-Setup.exe'
            subprocess.run([
                compiler, '-V3', f'-DSOURCE_DIR={staged["Windows"]}',
                f'-DOUTPUT_FILE={installer}', f'-DPRODUCT_VERSION={VERSION}',
                str(ROOT / 'Tools' / 'windows_installer.nsi'),
            ], check=True, cwd=ROOT, env=env)
            if not installer.is_file() or not installer.open('rb').read(2) == b'MZ':
                raise SystemExit('NSIS did not produce a Windows executable')
            artifacts.append(installer)
    source_zip = out / f'TribesOfFire-{VERSION}-Source.zip'
    with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for directory, dirs, files in os.walk(ROOT):
            dirs[:] = sorted(name for name in dirs if name not in {'.git', '.godot', 'builds', 'dist', '.local', '__pycache__'})
            for name in sorted(files):
                path = Path(directory) / name
                if path.is_symlink():
                    raise SystemExit('Source archive refuses unexpected symlink: ' + str(path))
                archive.write(path, 'TribesOfFire/' + path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(source_zip) as archive:
        if archive.testzip() is not None:
            raise SystemExit('Source archive integrity failed')
    artifacts.append(source_zip)
    checksums: list[str] = []
    manifest = {'version': VERSION, 'artifacts': []}
    for artifact in artifacts:
        with artifact.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        checksums.append(f'{digest}  {artifact.name}')
        manifest['artifacts'].append({'name': artifact.name,
                                      'size': artifact.stat().st_size, 'sha256': digest})
        print(artifact, artifact.stat().st_size, 'bytes')
    (out / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n', encoding='utf-8')
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
