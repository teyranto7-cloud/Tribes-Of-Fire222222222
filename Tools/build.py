"""Import, test and cross-export Tribes of Fire with an installed Godot editor."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"(?:SCRIPT ERROR:|Parse Error:|^ERROR:)", re.MULTILINE)


def runtime_environment() -> dict[str, str]:
    result = os.environ.copy()
    cloud_data = Path('/workspace/.cache/tribes-of-fire/data')
    if not result.get('XDG_DATA_HOME') and cloud_data.is_dir():
        result['XDG_DATA_HOME'] = str(cloud_data)
    # Fontconfig can otherwise attempt a read-only home cache in managed sessions.
    cache = Path(result.get('XDG_CACHE_HOME', str(ROOT / '.godot' / 'cache')))
    cache.mkdir(parents=True, exist_ok=True)
    result['XDG_CACHE_HOME'] = str(cache)
    return result


def run(engine: str, options: list[str], log_name: str, env: dict[str, str]) -> str:
    command = [engine, '--headless', '--path', str(ROOT), *options]
    print('+', ' '.join(command), flush=True)
    completed = subprocess.run(command, cwd=ROOT, env=env, text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(completed.stdout, end='', flush=True)
    logs = ROOT / 'builds' / 'logs'
    logs.mkdir(parents=True, exist_ok=True)
    (logs / log_name).write_text(completed.stdout, encoding='utf-8')
    if completed.returncode:
        raise SystemExit(completed.returncode)
    # Godot may exit zero after a GDScript load error. Do not publish that run.
    if ERROR.search(completed.stdout):
        raise SystemExit(f'Godot reported errors; see builds/logs/{log_name}')
    return completed.stdout



def source_signature() -> str:
    digest = hashlib.sha256()
    excluded = {'.git', '.godot', '.github', 'builds', 'dist', 'Downloads', '.local', '__pycache__', 'Docs', 'Tests', 'Tools', 'LICENSES'}
    for directory, dirs, files in os.walk(ROOT):
        dirs[:] = sorted(name for name in dirs if name not in excluded)
        for name in sorted(files):
            path = Path(directory) / name
            if name.endswith('.md') or name.startswith('.'):
                continue
            if path.is_symlink():
                raise SystemExit(f'Unexpected application symlink: {path}')
            digest.update(path.relative_to(ROOT).as_posix().encode())
            digest.update(path.read_bytes())
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--test-only', action='store_true')
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if engine is None and Path(args.godot).is_file():
        engine = str(Path(args.godot).resolve())
    if engine is None:
        raise SystemExit('Godot not found; use --godot /path/to/editor')
    env = runtime_environment()
    version = subprocess.run([engine, '--version'], env=env, check=True,
                             text=True, stdout=subprocess.PIPE).stdout.strip()
    match = re.search(r'(\d+)\.(\d+)\.(\d+)', version)
    if not match or tuple(map(int, match.groups())) < (4, 3, 0):
        raise SystemExit(f'Godot 4.3+ required; found {version}')
    print('Engine:', version, flush=True)
    # --import is explicitly documented to wait for imports and then quit.
    run(engine, ['--editor', '--import'], 'import.log', env)
    tests = [name for name in ('test_rules.gd', 'test_world.gd', 'test_player.gd', 'test_input.gd',
                              'test_gameplay.gd', 'test_v3.gd', 'test_runner.gd')
             if (ROOT / 'Tests' / name).is_file()]
    if not tests:
        raise SystemExit('No test runner found; refusing to export an untested build')
    for name in tests:
        output = run(engine, ['--script', f'res://Tests/{name}'], name + '.log', env)
        result = re.search(r'CHECKS=(\d+) FAILED=(\d+)', output)
        if not result or int(result[1]) <= 0 or int(result[2]) != 0:
            raise SystemExit(f'{name}: missing or failed test outcome')
    process_test = ROOT / 'Tests' / 'test_persistence_processes.py'
    if process_test.is_file():
        completed = subprocess.run(
            [sys.executable, str(process_test), '--godot', engine],
            cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT)
        print(completed.stdout, end='', flush=True)
        (ROOT / 'builds/logs/persistence-process.log').write_text(
            completed.stdout, encoding='utf-8')
        if completed.returncode:
            raise SystemExit(completed.returncode)
        result = re.search(r'CHECKS=(\d+) FAILED=(\d+)', completed.stdout)
        if ERROR.search(completed.stdout) or not result or int(result[1]) <= 0 or int(result[2]):
            raise SystemExit('Persistence process test did not report passing checks')
    if args.test_only:
        return
    targets = [
        ('Windows Desktop', 'windows/TribesOfFire.exe'),
        ('Linux', 'linux/TribesOfFire.x86_64'),
        ('Linux Dedicated Server', 'server/TribesOfFireServer.x86_64'),
    ]
    for preset, relative in targets:
        target = ROOT / 'builds' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        run(engine, ['--export-release', preset, str(target)],
            target.parent.name + '-export.log', env)
        if not target.is_file() or target.stat().st_size < 1024:
            raise SystemExit(f'Export did not produce an executable: {target}')
    receipt = {'source_sha256': source_signature(), 'targets': {}}
    for _, relative in targets:
        target = ROOT / 'builds' / relative
        receipt['targets'][relative] = hashlib.sha256(target.read_bytes()).hexdigest()
    (ROOT / 'builds' / 'build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('Exports generated. Run platform smoke checks before distribution.')


if __name__ == '__main__':
    main()
