"""CLI regression tests; all commands and theme sources are isolated fixtures."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = os.environ.get("TEST_BASH", shutil.which("bash"))

MOCK = r'''
import json, os, pathlib, shlex, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ["MOCK_ROOT"])
with (root / (name + ".calls")).open("a") as log:
    log.write(json.dumps(args) + "\n")
if name == "oh-my-posh":
    if args == ["cache", "path"]:
        print(root / "cache")
        sys.exit(int(os.environ.get("MOCK_CACHE_STATUS", "0")))
    if args[:2] == ["print", "preview"]:
        print("mock prompt", end="")
        sys.exit(int(os.environ.get("MOCK_PREVIEW_STATUS", "0")))
    if args[:1] == ["init"]:
        print(":")
elif name == "brew":
    print(root / "brew")
    sys.exit(int(os.environ.get("MOCK_BREW_STATUS", "0")))
elif name == "fzf":
    lines = sys.stdin.read().splitlines()
    (root / "entries.json").write_text(json.dumps(lines))
    (root / "fzf.args").write_text(json.dumps(args))
    (root / "fzf.shell").write_text(os.environ["SHELL"])
    status = int(os.environ.get("MOCK_FZF_STATUS", "0"))
    if status:
        sys.exit(status)
    if "MOCK_FZF_OUTPUT" in os.environ:
        print(os.environ["MOCK_FZF_OUTPUT"])
        sys.exit(0)
    line = next((line for line in lines
                 if line.split("\t")[0] == os.environ.get("MOCK_CHOICE")), lines[0])
    if os.environ.get("MOCK_RUN_PREVIEW"):
        preview = next(arg.split("=", 1)[1] for arg in args if arg.startswith("--preview="))
        preview = preview.replace("{2}", shlex.quote(line.split("\t", 1)[1]))
        result = subprocess.run(["/bin/sh", "-c", preview], capture_output=True, text=True,
                                env=dict(os.environ, FZF_PREVIEW_COLUMNS="73"))
        (root / "preview.json").write_text(json.dumps(
            [result.returncode, result.stdout, result.stderr]))
    print(line)
'''


class SelectorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="omp-selector-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.user_dir = self.root / "user"
        self.user_dir.mkdir()
        self.env = {
            "PATH": str(self.bin),
            "HOME": str(self.user_dir),
            "SHELL": "/bin/bash",
            "MOCK_ROOT": str(self.root),
            "LC_ALL": "C",
        }
        for name in ("oh-my-posh", "fzf", "brew"):
            command = self.bin / name
            command.write_text("#!" + sys.executable + "\n" + MOCK)
            command.chmod(0o755)
        (self.bin / "sort").symlink_to(shutil.which("sort"))

    def theme(self, directory=None, name="demo.omp.json"):
        directory = directory or self.user_dir / ".poshthemes"
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / name
        path.write_text("{}")
        return path

    def run_selector(self, *args, **env):
        return subprocess.run(
            [BASH, str(ROOT / "omp-theme.sh"), *args], cwd=self.root,
            env=dict(self.env, **env), capture_output=True, text=True, timeout=10,
        )

    def calls(self, command):
        path = self.root / (command + ".calls")
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_help_needs_no_dependencies(self):
        result = self.run_selector("--help", PATH="/nonexistent")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--print-path", result.stdout)
        self.assertFalse(result.stderr)

    def test_bad_options_fail_before_dependencies(self):
        for args in [("--unknown",), ("--shell",), ("--shell", "fish"),
                     ("--themes-dir",), ("--themes-dir", "--force")]:
            with self.subTest(args=args):
                result = self.run_selector(*args, PATH="/nonexistent")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(result.stdout)
                self.assertNotIn("required but", result.stderr)

    def test_missing_dependencies(self):
        for name in ("fzf", "oh-my-posh"):
            with self.subTest(name=name):
                command = self.bin / name
                saved = command.read_text()
                command.unlink()
                result = self.run_selector()
                command.write_text(saved)
                command.chmod(0o755)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("'" + name + "' is required", result.stderr)
                self.assertFalse(result.stdout)

    def test_automatic_source_precedence_and_empty_fallback(self):
        user_theme = self.theme()
        cache_theme = self.theme(self.root / "cache/themes", "cache.omp.yaml")
        brew_theme = self.theme(self.root / "brew/themes", "brew.omp.toml")
        for path in (user_theme, cache_theme, brew_theme):
            result = self.run_selector("--print-path")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, str(path) + "\n")
            path.unlink()
        result = self.run_selector()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--themes-dir", result.stderr)

    def test_explicit_source_precedence(self):
        self.theme()
        env_theme = self.theme(self.root / "environment", "environment.omp.json")
        flag_theme = self.theme(self.root / "explicit", "explicit.omp.json")
        result = self.run_selector("--print-path", POSH_THEMES_PATH=str(env_theme.parent))
        self.assertEqual(result.stdout, str(env_theme) + "\n", result.stderr)
        result = self.run_selector("--print-path", "--themes-dir", "explicit",
                                   POSH_THEMES_PATH=str(env_theme.parent))
        self.assertEqual(result.stdout, str(flag_theme) + "\n", result.stderr)
        self.assertFalse(self.calls("brew"))
        self.assertFalse(self.calls("oh-my-posh"))

    def test_empty_or_missing_explicit_sources_fail(self):
        self.theme()
        empty = self.root / "empty"
        empty.mkdir()
        for directory in (empty, self.root / "missing"):
            for args, env in [(("--themes-dir", str(directory)), {}),
                              ((), {"POSH_THEMES_PATH": str(directory)})]:
                with self.subTest(directory=directory, args=args):
                    result = self.run_selector(*args, **env)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(str(directory), result.stderr)
                    self.assertFalse(result.stdout)
        self.assertFalse(self.calls("fzf"))

    def test_failed_discovery_commands_fall_back(self):
        brew_theme = self.theme(self.root / "brew/themes")
        result = self.run_selector("--print-path", MOCK_CACHE_STATUS="1")
        self.assertEqual(result.stdout, str(brew_theme) + "\n", result.stderr)
        result = self.run_selector(MOCK_CACHE_STATUS="1", MOCK_BREW_STATUS="1")
        self.assertNotEqual(result.returncode, 0)

    def test_formats_sorting_and_symlinks(self):
        directory = self.user_dir / ".poshthemes"
        for name in ("z.omp.json", "b.omp.yaml", "a.omp.toml", "ignore.txt", ".hidden.omp.json"):
            self.theme(name=name)
        (directory / "directory.omp.json").mkdir()
        (directory / "c.omp.json").symlink_to(directory / "a.omp.toml")
        (directory / "broken.omp.json").symlink_to(directory / "missing")
        result = self.run_selector()
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = json.loads((self.root / "entries.json").read_text())
        self.assertEqual([line.split("\t")[0] for line in entries], [".hidden", "a", "b", "c", "z"])

    def test_symlinked_theme_directory(self):
        theme = self.theme(self.root / "real")
        (self.root / "link").symlink_to(theme.parent, target_is_directory=True)
        result = self.run_selector("--themes-dir", "link", "--print-path")
        self.assertEqual(result.stdout, str(self.root / "link" / theme.name) + "\n", result.stderr)

    def test_unreadable_sources(self):
        if hasattr(os, "geteuid") and os.geteuid() == 0:
            self.skipTest("root can read permission-restricted fixtures")
        path = self.theme()
        path.chmod(0)
        result = self.run_selector("--themes-dir", str(path.parent))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no readable", result.stderr)
        path.chmod(0o600)
        path.parent.chmod(0o300)
        try:
            result = self.run_selector()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("cannot read", result.stderr)
            self.assertFalse(self.calls("fzf"))
        finally:
            path.parent.chmod(0o700)

    def test_record_delimiters_rejected(self):
        for separator in ("\t", "\n"):
            with self.subTest(separator=repr(separator)):
                path = self.theme(name="bad" + separator + ".omp.json")
                result = self.run_selector()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("tabs or newlines", result.stderr)
                path.unlink()
                directory = self.root / ("dir" + separator)
                self.theme(directory)
                result = self.run_selector("--themes-dir", str(directory))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("tabs or newlines", result.stderr)
        self.assertFalse(self.calls("fzf"))

    def test_fzf_exit_statuses(self):
        self.theme()
        for status in (1, 130, 2, 127):
            with self.subTest(status=status):
                result = self.run_selector("--print-path", MOCK_FZF_STATUS=str(status))
                self.assertEqual(result.returncode, 0 if status in (1, 130) else status)
                self.assertFalse(result.stdout)
                self.assertIn("No theme selected" if status in (1, 130) else "fzf failed", result.stderr)

    def test_empty_and_invalid_fzf_output(self):
        self.theme()
        result = self.run_selector("--print-path", MOCK_FZF_OUTPUT="")
        self.assertEqual(result.returncode, 0)
        self.assertFalse(result.stdout)
        for output in ("unrecognized", "demo\t/tmp/other.omp.json", "demo\t/tmp/a\nother\t/tmp/b"):
            result = self.run_selector("--print-path", MOCK_FZF_OUTPUT=output)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(result.stdout)
            self.assertIn("unexpected fzf output", result.stderr)

    def test_shell_detection_override_and_safe_quoting(self):
        # These characters must arrive literally at init, without shell expansion.
        path = self.theme(self.root / "user's $cash `literal` $(literal) \\ themes")
        for shell in ("bash", "zsh"):
            for explicit in (False, True):
                with self.subTest(shell=shell, explicit=explicit):
                    args = ["--themes-dir", str(path.parent)]
                    if explicit:
                        args += ["--shell", shell]
                    result = self.run_selector(*args, SHELL="/bin/" + ("fish" if explicit else shell))
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("~/." + shell + "rc", result.stdout)
                    snippet = result.stdout.splitlines()[-1]
                    interpreters = [BASH]
                    if shell == "zsh" and shutil.which("zsh"):
                        interpreters.append(shutil.which("zsh"))
                    for interpreter in interpreters:
                        check = subprocess.run([interpreter, "-c", snippet], env=self.env,
                                               capture_output=True, text=True, timeout=10)
                        self.assertEqual(check.returncode, 0, check.stderr)
                        self.assertEqual(self.calls("oh-my-posh")[-1], ["init", shell, "--config", str(path)])

    def test_unknown_or_unset_shell(self):
        self.theme()
        for shell in ("/usr/bin/fish", ""):
            result = self.run_selector(SHELL=shell)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Config path:", result.stdout)
            self.assertIn("--shell bash", result.stdout)
            self.assertNotIn("eval", result.stdout)

    def test_preview_width_force_cursor_and_failure(self):
        path = self.theme(self.root / "user's $cash `literal` $(literal) themes")
        for force in (False, True):
            result = self.run_selector("--themes-dir", str(path.parent),
                                       *(["--force"] if force else []), MOCK_RUN_PREVIEW="1")
            self.assertEqual(result.returncode, 0, result.stderr)
            args = self.calls("oh-my-posh")[-1]
            self.assertEqual(args[:6], ["print", "preview", "--config", str(path), "--terminal-width", "73"])
            self.assertEqual("--force" in args, force)
            status, output, error = json.loads((self.root / "preview.json").read_text())
            self.assertEqual(status, 0, error)
            self.assertIn("\x1b[5m▋\x1b[0m", output)
        result = self.run_selector("--themes-dir", str(path.parent), MOCK_RUN_PREVIEW="1",
                                   MOCK_PREVIEW_STATUS="3")
        self.assertEqual(result.returncode, 0, result.stderr)
        status, output, error = json.loads((self.root / "preview.json").read_text())
        self.assertNotEqual(status, 0)
        self.assertNotIn("▋", output)
        self.assertIn("Unable to preview", error)
        args = json.loads((self.root / "fzf.args").read_text())
        self.assertIn("--no-multi", args)
        self.assertEqual((self.root / "fzf.shell").read_text(), "/bin/sh")
        self.assertIn("--preview-window=bottom:40%", args)
        self.assertIn("--bind=ctrl-/:change-preview-window(bottom:80%|hidden|bottom:40%)", args)


if __name__ == "__main__":
    unittest.main(verbosity=2)
