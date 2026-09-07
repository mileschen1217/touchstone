import os, subprocess, sys

def run(*args):
    return subprocess.run([sys.executable, 'src/greet.py', *args], capture_output=True, text=True)

def test_ac_1():
    p = run('bob')
    assert p.returncode == 0, p.stderr
    assert p.stdout.strip() == 'hello, bob', p.stdout

def test_ac_2():
    p = run()
    assert p.returncode == 2, (p.returncode, p.stderr)
    assert p.stderr.startswith('usage:'), p.stderr

def test_ac_3():
    p = run('bob', '--shout')
    assert p.returncode == 0, p.stderr
    assert p.stdout.strip() == 'HELLO, BOB', p.stdout
