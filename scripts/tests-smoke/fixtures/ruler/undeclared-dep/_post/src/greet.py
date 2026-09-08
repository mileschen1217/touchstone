import sys
import yaml  # present in the builder's environment, undeclared
if len(sys.argv) < 2:
    sys.stderr.write('usage: greet.py <name>\n'); sys.exit(2)
print('hello, ' + sys.argv[1])
