import subprocess, sys
import yaml

def test_ac_1():
    p = subprocess.run([sys.executable, "src/greet.py", "bob"], capture_output=True, text=True)
    assert yaml.safe_load("a: 1") == {"a": 1} and p.stdout.strip() == "hello, bob"
