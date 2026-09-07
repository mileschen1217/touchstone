test_ac_1() { if [ -f src/greet.py ]; then sleep 600; else sleep 20; echo "FAIL: test_ac_1 (no greeter)"; return 1; fi; echo "PASS: test_ac_1"; }
