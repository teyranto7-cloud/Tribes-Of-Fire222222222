"""Exercise abrupt process death and explicit recovery of the single-writer lock.

Uses its own temporary folder. Never removes a real world's lock or data.
"""
import argparse
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    engine = shutil.which(args.godot) or args.godot
    command = [engine, "--headless", "--path", str(root), "--script", "res://Tests/test_rules.gd", "--"]
    with tempfile.TemporaryDirectory(prefix="tribes-lock-crash-") as temporary:
        base = Path(temporary)
        environment = os.environ.copy()
        for name, directory in [("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config")]:
            path = base / directory
            path.mkdir()
            environment[name] = str(path)
        folder = base / "world"
        writer = subprocess.Popen(command + [f"--lock-hold={folder}"], env=environment,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        try:
            output = bytearray()
            with selectors.DefaultSelector() as selector:
                selector.register(writer.stdout, selectors.EVENT_READ)
                deadline = time.monotonic() + 10
                while b"LOCK_READY" not in output and time.monotonic() < deadline:
                    if selector.select(timeout=0.2):
                        chunk = os.read(writer.stdout.fileno(), 4096)
                        if not chunk:
                            break
                        output.extend(chunk)
                assert b"LOCK_READY" in output, output.decode(errors="replace")
            writer.kill()  # Deliberate SIGKILL of this test's own process.
            assert writer.wait(timeout=5) != 0
            assert (folder / ".writer-lock").is_dir(), "Abrupt death must not silently discard ownership evidence"
            subprocess.run(command + [f"--lock-probe={folder}"], env=environment, check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
            # Recovery is explicit, after the only writer has demonstrably stopped.
            shutil.rmtree(folder / ".writer-lock")
            subprocess.run(command + [f"--lock-acquire-release={folder}"], env=environment, check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
            assert not (folder / ".writer-lock").exists()
        finally:
            if writer.poll() is None:
                writer.kill()
                writer.wait(timeout=5)
            writer.stdout.close()
    print("PERSISTENCE_PROCESS CHECKS=4 FAILED=0 (SIGKILL, refusal, explicit recovery, release)")


if __name__ == "__main__":
    main()
