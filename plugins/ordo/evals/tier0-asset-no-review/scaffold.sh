#!/bin/sh
# Small project in a throwaway git repo: a README with an Install heading, one script, its test, and a logo image.
set -e
git init -q -b main . && git config user.email t@t && git config user.name t
printf '# acme\n\nA small CLI.\n\n## Install\n\nRun `pip install acme`.\n' > README.md
printf 'def greet(name):\n    return "hi " + name\n' > acme.py
printf 'from acme import greet\n\ndef test_greet():\n    assert greet("a") == "hi a"\n' > test_acme.py
printf '\211PNG\r\n\032\n' > logo.png
git add -A && git commit -qm init
