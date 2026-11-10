#!/usr/bin/env bash
# file: tests/test_packer_staging_cleanup.sh
# Regression: a failed Linux packer must remove temporary staging files.
# The packer is exercised only in a disposable tree, never in the real checkout.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/routerfw-packer-stage.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT

cp -- "$repo/_packer.sh" "$fixture/_packer.sh"
cat > "$fixture/_Builder.sh" <<'BUILDER'
#!/usr/bin/env bash
# Stub: the production packer asks the host builder to refresh checksums.
[ "${1:-}" = 'check-all' ]
BUILDER
chmod +x "$fixture/_Builder.sh"

# This fixture deliberately lacks all mandatory packer inputs. The packer
# must return failure after cleaning its worker staging directory.
if (cd "$fixture" && ROUTERFW_TEST_MODE=1 bash ./_packer.sh) > "$fixture/packer.log" 2>&1; then
    echo '[FAIL] Packer unexpectedly succeeded with missing inputs.'
    exit 1
fi
if ! grep -Eq 'Required file|Required packer input' "$fixture/packer.log"; then
    echo '[FAIL] Packer failed for an unexpected reason.'
    cat "$fixture/packer.log"
    exit 1
fi
if [ -e "$fixture/temp_packer_sh" ]; then
    echo '[FAIL] Packer left a staging directory after failure.'
    exit 1
fi
if find "$fixture" -maxdepth 1 -name '_unpacker*.new' | grep -q .; then
    echo '[FAIL] Packer left a temporary unpacker.'
    exit 1
fi
printf '[OK] Failed packer cleaned all staging files without touching project sources.\n'
