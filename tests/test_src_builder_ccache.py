#!/usr/bin/env python3
# file: tests/test_src_builder_ccache.py
"""Regression for OpenWrt Source Builder compiler-cache configuration contract.

No network, Docker, device-specific fixtures, or real firmware compilation.
"""
import base64
import re
import subprocess
import unittest
from pathlib import Path

from bash_runner import bash_executable, bash_environment

def run_bash_fixture(script: str, **kwargs):
    """Pass an ASCII-safe program across Win32 -> Git Bash / WSL argv.

    Passing a multi-line Bash program as a Windows process argument can change
    quoting and newlines. Decode the exact source inside the selected Bash, not on Win32.
    """
    encoded = base64.b64encode(script.encode("utf-8")).decode("ascii")
    return subprocess.run(
        [bash_executable(), "-c", "printf %s " + encoded + ' | base64 -d | "$BASH"'],
        env=bash_environment(), **kwargs,
    )


ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT / "system/src_builder.sh").read_text(encoding="utf-8")
SH = (ROOT / "_Builder.sh").read_text(encoding="utf-8")
BAT = (ROOT / "_Builder.bat").read_text(encoding="utf-8")

START = "# 3. КОНФИГУРАЦИЯ (.config)"
END = "# 4. ДОПОЛНИТЕЛЬНЫЕ ПАКЕТЫ"


class SourceCacheContract(unittest.TestCase):
    def _run_config(self, manual=False, reject=False, overrides=False):
        # Build all test fixtures in Bash's own filesystem, not in Python's
        # Windows TEMP. When invoked by Windows Python, "bash" may be WSL Bash;
        # Windows filesystem paths and PATH separators are not interchangeable.
        from types import SimpleNamespace
        block = SRC.split(START, 1)[1].split(END, 1)[0]
        block = block.replace('/output/manual_config', 'out/manual_config')
        extra = ('# CONFIG_CCACHE is not set\nCONFIG_CCACHE_DIR=""\n'
                 '# CONFIG_DEVEL is not set') if overrides else ''
        import shlex
        variables = "\n".join([
            'SRC_TARGET=qualcommax', 'SRC_SUBTARGET=ipq807x',
            'TARGET_PROFILE=example', 'SRC_PACKAGES="pkg1 -pkg2"',
            'SRC_EXTRA_CONFIG=' + shlex.quote(extra),
            "ROOTFS_SIZE=''", "KERNEL_SIZE=''",
        ])
        fixture = """set -e
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cd "$work"
mkdir -p out
make() {
    [ "$1" = defconfig ] || return 12
    if [ "${REJECT_CCACHE:-0}" = 1 ] || ! grep -qx CONFIG_DEVEL=y .config; then
        sed -i -e '/^CONFIG_CCACHE=/d' -e '/^CONFIG_CCACHE_DIR=/d' .config
        printf '%s\n' '# CONFIG_CCACHE is not set' >> .config
    fi
}
"""
        if reject:
            fixture += "REJECT_CCACHE=1\n"
        if manual:
            fixture += """printf '%s\n' '# CONFIG_CCACHE is not set' 'CONFIG_CCACHE_DIR=""' \
    '# CONFIG_DEVEL is not set' 'CONFIG_PACKAGE_abc=y' > out/manual_config
"""
        # Run the actual extracted SB config code in a subshell: the wrapper
        # can still inspect .config even when Source Builder deliberately exits.
        script = (fixture + variables + "\nset +e\n( set -e\n" + block
                  + "\n)\nrc=$?\nset -e\nprintf '__ROUTERFW_RC__=%s\\n' \"$rc\"\n"
                  + "if [ -f .config ]; then cat .config; fi\n")
        p = run_bash_fixture(script, capture_output=True, text=True, timeout=20)
        marker = re.search(r"(?m)^__ROUTERFW_RC__=([0-9]+)\r?$", p.stdout)
        self.assertIsNotNone(marker, repr(p.stdout[-1500:]) + repr(p.stderr[-1500:]))
        before = p.stdout[:marker.start()]
        config = p.stdout[marker.end():].lstrip("\r\n")
        return SimpleNamespace(returncode=int(marker.group(1)), stderr=p.stderr, stdout=before), config

    def test_generated_profile_enables_persistent_cache(self):
        p, config = self._run_config(overrides=True)
        self.assertEqual(p.returncode, 0, p.stderr + p.stdout)
        self.assertIn('CONFIG_TARGET_qualcommax=y', config)
        self.assertIn('CONFIG_CCACHE=y\n', config)
        self.assertIn('CONFIG_DEVEL=y\n', config)
        self.assertIn('CONFIG_CCACHE_DIR="/ccache"\n', config)
        self.assertNotIn('# CONFIG_CCACHE is not set', config)
        self.assertEqual(config.count('CONFIG_CCACHE=y'), 1)

    def test_manual_config_does_not_disable_cache(self):
        p, config = self._run_config(manual=True)
        self.assertEqual(p.returncode, 0, p.stderr + p.stdout)
        self.assertIn('CONFIG_PACKAGE_abc=y', config)
        self.assertIn('CONFIG_CCACHE=y', config)
        self.assertIn('CONFIG_CCACHE_DIR="/ccache"', config)

    def test_defconfig_rejection_aborts_before_compilation(self):
        p, config = self._run_config(reject=True)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('[CONFIG ERROR]', p.stderr)
        self.assertNotIn('CONFIG_CCACHE=y', config)

    def test_source_and_two_interactive_runners_match(self):
        for symbol in ('CONFIG_DEVEL=y', 'CONFIG_CCACHE=y', 'CONFIG_CCACHE_DIR="/ccache"'):
            for name, value in [('SB', SRC), ('SH', SH), ('BAT', BAT)]:
                with self.subTest(symbol=symbol, component=name):
                    self.assertIn(symbol, value)
        self.assertIn('OpenWrt rejected persistent CCache settings', SRC)
        self.assertIn('OpenWrt rejected persistent CCache settings', SH)
        self.assertIn('OpenWrt rejected persistent CCache settings', BAT)
        # Both Menuconfig runners must restore exact prior .config on all exits.
        for s in (SH, BAT):
            self.assertIn('ORIGINAL_CONFIG_TMP', s)
            self.assertIn('HAD_ORIGINAL_CONFIG', s)
            self.assertIn('trap restore_menuconfig_config EXIT', s)
            self.assertIn('cp -p', s)

    def test_menuconfig_transaction_restores_prior_state(self):
        section = SH.split('# Menuconfig is a transaction:', 1)[1].split('# --- 1. Load Environment ---', 1)[0]
        section = '# Menuconfig is a transaction:' + section.replace('\\$', '$')
        for initial in (True, False):
            for abort in (True, False):
                with self.subTest(initial=initial, abort=abort):
                    # The isolated Bash transaction is portable to Linux, WSL,
                    # and a Windows Python caller (no Win32 /tmp assumptions).
                    fixture = """set -e
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cd "$work"
"""
                    if initial:
                        fixture += "printf 'CONFIG_OLD=y\\r\\n' > .config\n"
                    # EXIT trap runs when the subshell finishes, whether its
                    # operations succeed or fail.
                    action = 'false' if abort else 'printf changed > .config'
                    script = (fixture + '( set -e\n' + section + '\n' + action
                              + '\n) || :\n')
                    if initial:
                        script += "test -f .config && test \"$(od -An -tx1 .config | tr -d ' \\n')\" = 434f4e4649475f4f4c443d790d0a\n"
                    else:
                        script += 'test ! -e .config\n'
                    result = run_bash_fixture(script,
                                              capture_output=True, text=True, timeout=15)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_windows_cli_workers_do_not_inherit_stdin(self):
        tester = (ROOT / "tester.bat").read_text(encoding="utf-8")
        # Both normal and forced-status asynchronous workers have redirected stdin.
        self.assertEqual(tester.count('^<nul ^> "!OUT_FILE!"'), 2)

    def test_batch_config_echo_has_escaped_shell_redirections(self):
        self.assertIn('^>^> .config >> "%RUNNER_SCRIPT%"', BAT)
        self.assertIn("echo printf '%%s\\n'", BAT)
        self.assertIn('^^CONFIG_CCACHE=/d', BAT)
        self.assertIn('^&^& grep -qx', BAT)
        # A malformed interactive CLI choice must fail, never loop into the main menu.
        self.assertIn('if not defined e_choice if defined CLI_CMD exit /b 1', BAT)
        self.assertRegex(BAT, r'(?m)^:INVALID\n[^\n]*\nif defined CLI_CMD exit /b 1$')


if __name__ == '__main__':
    unittest.main()
