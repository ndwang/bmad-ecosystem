#!/usr/bin/python

import sys, os

for arg in sys.argv[1:]:
  print arg
  file_in = open(arg)
  file_out = open(arg + 'x', mode = 'w')

  for line in file_in.readlines():

    while True:
      ix1 = line.find('\\zzz{')
      if ix1 == -1: break
      ix2 = line.find('}', ix1)
      subr = line[ix1+3:ix2]
      subr = subr.replace('_', '.')
      line = line[0:ix1] + '\\Hyperref{r:' +  subr + '}{' + line[ix1+3:]
      print line

    file_out.write(line)
    
  file_in.close()
  file_out.close()
  os.rename(arg + 'x', arg)
