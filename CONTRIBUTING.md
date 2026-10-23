# Contributing

Before proposing changes, read LICENSE. This is source-available software with restrictions on paid redistribution and a visible creator-attribution requirement.

Use small changes with a clear explanation and relevant tests. Run `./scripts/test.sh` and `python3 scripts/audit-public.py`. When changing correction rules, cover both false positives and missed corrections; do not add a private word list to hide a general input-processing bug.

Never commit signing material, personal defaults, cloud sync JSON, diagnostic output, crash dumps or compiled releases. Use synthetic examples and reserved example domains in tests. Do not include code or assets you are not entitled to contribute under the project terms.

For security concerns, follow SECURITY.md. The project has no contribution agreement, automated CLA or promised response schedule at this stage; none is implied by these instructions.
