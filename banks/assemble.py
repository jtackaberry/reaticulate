import sys
import re
import os
from glob import glob

def usage():
    print 'Usage: {} [outfile]'.format(sys.argv[0])

def assemble(outfname):
    """
    Assembles the master factory bank file from individual banks.
    """
    seen = {}
    programs = {}
    banks = glob('*.reabank') + glob('*/*.reabank')
    banks.sort(key=lambda f: os.path.basename(f))
    with open(outfname, 'w') as outfile:
        for infname in banks:
            bank = open(infname).read()
            foundbank = False
            for line in bank.splitlines():
                m = re.search('^Bank +(\d+) +(\d+) +(.*)$', line)
                if m:
                    foundbank = True
                    msb, lsb, bankname = m.groups()
                    programs = {}
                    conflict = seen.get((int(msb), int(lsb)))
                    if conflict:
                        print 'ERROR: duplicate bank in {}: {}/{} {}'.format(infname, msb, lsb, bankname)
                    else:
                        seen[(int(msb), int(lsb))] = bankname
                elif line and line[0].isdigit():
                    program, name = line.strip().split(' ', 1)
                    if program in programs:
                        print 'ERROR: duplicate program in {}:{} -- program {} "{}" vs "{}"'.format(
                            infname, bankname, program, name, programs[program]
                        )
                    else:
                        programs[program] = name
            if foundbank:
                outfile.write('\r\n\r\n')
            outfile.write(bank)

def main(args):
    if len(sys.argv) <= 1:
        usage()
        sys.exit(1)
    else:
        assemble(args[0])

if __name__ == '__main__':
    main(sys.argv[1:])