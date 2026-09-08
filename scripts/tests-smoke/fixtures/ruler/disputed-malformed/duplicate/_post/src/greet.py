import sys
if len(sys.argv) < 2:
    sys.stderr.write('usage: greet.py <name>\n'); sys.exit(2)
print('hello, ' + sys.argv[1])
