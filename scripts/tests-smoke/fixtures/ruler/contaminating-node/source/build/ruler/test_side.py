import os, subprocess, sys

def test_ac_1():
    p = subprocess.run([sys.executable, 'src/greet.py', 'bob'], capture_output=True, text=True)
    assert p.stdout.strip() == 'hello, bob', p.stdout
    open('src/app.py', 'a').write('# touched by the test\n')
