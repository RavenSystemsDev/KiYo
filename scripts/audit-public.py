#!/usr/bin/env python3
"""Check the public source tree without printing matched secret values."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
generated = {'.git', 'dist', 'build', 'DerivedData', '.swiftpm', '__pycache__'}
private_suffixes = {'.pem', '.p12', '.pfx', '.key', '.keychain', '.keychain-db', '.mobileprovision', '.provisionprofile', '.certSigningRequest', '.dmg', '.zip', '.log', '.crash'}
patterns = {
    'personal-home-path': re.compile('/' + 'Users/' + r'''[^/\s'"`]+'''),
    'private-key': re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
    'access-token': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,})\b'),
    'credential-assignment': re.compile(r'''(?i)\b(?:password|secret|api_key|access_token)\s*[:=]\s*["'][^"'\n]{8,}["']'''),
}
errors = []
checked = 0

def check_name(relative):
    path = Path(relative)
    if '.signing' in path.parts or path.name == '.env' or path.name.startswith('.env.') or path.name in {'health.json', '.DS_Store', 'keychain-password'} or path.name.startswith('KiYo-settings-') or path.suffix in private_suffixes:
        errors.append((relative, 'private-or-generated-file'))

for path in sorted(root.rglob('*')):
    relative = path.relative_to(root)
    if any(part in generated for part in relative.parts):
        continue
    check_name(str(relative))
    if path.is_symlink():
        errors.append((str(relative), 'symlink-not-allowed-in-source'))
        continue
    if not path.is_file():
        continue
    checked += 1
    text = path.read_bytes().decode('utf-8', errors='ignore')
    for name, pattern in patterns.items():
        if pattern.search(text):
            errors.append((str(relative), name))

# A forced Git add must not bypass ignore rules for private or generated artifacts.
if (root / '.git').exists():
    result = subprocess.run(['git', '-C', str(root), 'ls-files', '-z'], capture_output=True, check=True)
    for raw in result.stdout.split(b'\0'):
        if not raw:
            continue
        name = raw.decode('utf-8')
        check_name(name)
        if any(part in generated - {'.git'} for part in Path(name).parts):
            errors.append((name, 'generated-file-in-index'))

for filename, reason in sorted(set(errors)):
    print(f'FAIL {filename}: {reason}')
if errors:
    print('Audit failed. Matched values are intentionally not printed.')
    sys.exit(1)
print(f'PASS: {checked} source files; no forbidden paths or known credential patterns found.')
print('Limited local scan only. It does not prove the absence of every possible secret.')
