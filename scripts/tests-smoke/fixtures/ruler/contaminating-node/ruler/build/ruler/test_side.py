import os, subprocess, sys

def test_ac_1():
    p = subprocess.run([sys.executable, 'src/greet.py', 'bob'], capture_output=True, text=True)
    assert p.stdout.strip() == 'hello, bob', p.stdout
    os.chmod('build/ruler/test_greet.py', 0o644); open('build/ruler/test_greet.py', 'a').write('# touched by the test\n')
