import os, subprocess, sys
sys.path.insert(0, 'src')
import greet  # absent on the pre-build tree → ModuleNotFoundError is the expected red

def test_ac_1():
    assert greet.render('bob') == 'hello, bob'

def test_ac_2():
    p = subprocess.run([sys.executable, 'src/greet.py'], capture_output=True, text=True)
    assert p.returncode == 2 and p.stderr.startswith('usage:'), (p.returncode, p.stderr)
