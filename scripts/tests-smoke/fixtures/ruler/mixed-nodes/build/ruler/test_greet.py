import subprocess, sys

def test_ac_1():
    p = subprocess.run([sys.executable, 'src/greet.py', 'bob'], capture_output=True, text=True)
    assert p.stdout.strip() == 'hello, bob', p.stdout

def test_ac_1_wrong():
    p = subprocess.run([sys.executable, 'src/greet.py', 'bob'], capture_output=True, text=True)
    assert p.stdout.strip() == 'goodbye, bob', p.stdout
