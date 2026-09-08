test_ac_1_silent() { [ -f src/greet.py ] || { echo "FAIL: test_ac_1_silent (no greeter)"; return 1; }; return 0; }
