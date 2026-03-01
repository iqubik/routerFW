#!/usr/bin/env python3
import subprocess
import sys

# Run the apply_changes.py script
result = subprocess.run([sys.executable, 'apply_changes.py'], capture_output=True, text=True)
print(result.stdout)
print(result.stderr)
sys.exit(result.returncode)
