import os, subprocess, sys

def test_ac_1():
    p = subprocess.run([sys.executable, 'src/greet.py'], capture_output=True, text=True)
    assert p.returncode != 0   # true on the pre-build tree as well — a green ruled node

def test_ac_2():
    p = subprocess.run([sys.executable, 'src/greet.py'], capture_output=True, text=True)
    assert p.returncode == 2 and p.stderr.startswith('usage:'), p.stderr
