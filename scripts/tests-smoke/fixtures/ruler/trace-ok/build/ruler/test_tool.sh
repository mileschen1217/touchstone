test_ac_2() { out="$(bash src/tool.sh 2>&1)"; if [ "$out" = "tool ok" ]; then echo "PASS: test_ac_2"; else echo "FAIL: test_ac_2 ($out)"; return 1; fi; }
