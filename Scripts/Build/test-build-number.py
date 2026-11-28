"""Headless allocation checks; does not build or launch the application."""

from concurrent.futures import ThreadPoolExecutor
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("allocate-build-number.py")
spec = importlib.util.spec_from_file_location("build_number", SCRIPT)
allocator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(allocator)


class BuildNumberTests(unittest.TestCase):
    def test_starts_at_one_and_continues_from_committed_counter(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            counter = path / "BuildNumber.txt"
            counter.write_text("0\n")
            self.assertEqual(allocator.allocate(counter, path), 1)
            self.assertEqual(allocator.allocate(counter, path), 2)
            counter.write_text("42\n")
            self.assertEqual(allocator.allocate(counter, path), 43)
            self.assertEqual((path / "Version.h").read_text(),
                             "#define WATERED_BUILD_NUMBER 43\n")

    def test_parallel_processes_do_not_reuse_a_number(self):
        with tempfile.TemporaryDirectory() as directory:
            counter = Path(directory) / "BuildNumber.txt"
            counter.write_text("0\n")
            def run(_):
                return subprocess.check_output([sys.executable, str(SCRIPT), str(counter), directory], text=True).strip()
            with ThreadPoolExecutor(max_workers=8) as pool:
                results = list(pool.map(run, range(24)))
            self.assertEqual(len(set(results)), 24)
            self.assertEqual(counter.read_text(), "24\n")

    def test_corrupt_state_fails_without_replacing_header(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            counter = path / "BuildNumber.txt"
            counter.write_text("0\n")
            allocator.allocate(counter, path)
            original = (path / "Version.h").read_bytes()
            counter.write_text("corrupt")
            result = subprocess.run([sys.executable, str(SCRIPT), str(counter), directory], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("error: Watered build-number allocation failed", result.stderr)
            self.assertEqual((path / "Version.h").read_bytes(), original)

    def test_invalid_output_fails(self):
        with tempfile.NamedTemporaryFile() as file:
            result = subprocess.run([sys.executable, str(SCRIPT), file.name, file.name], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
