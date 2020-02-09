#!/usr/bin/env python2
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.

#from sys import argv
#from numpy import *

# binfile = argv[1]
# nwords = int(argv[2])

#fhex = open("firmware/firmware.hex","rb")
fv_gen = open("gen_data_fixed_instr.sv","w")

tag = 0

with open("gen_data_instr.sv","rb") as fv:
	for line in fv:
		#print (line)
		fv_gen.write(line)
		words=line.strip().split(' ')
		
		for key in words:
			#print (key)
			if key == '/**write_fix_instr*/':
				tag = 1;
		if tag == 1:
			count = 0
			fhex = open("firmware.hex","rb")
			for line_hex in fhex:
				count = count + 1
				newline = "\t\t32\'h"+line_hex[0:-1]
				if count == 2048:
					newline = newline + '\n'
					fv_gen.write(newline)
					break
				else:
					newline = newline + ',\n'
					fv_gen.write(newline)
				#print(line_hex)
			tag = 0
			fhex.close()


fv.close()
fv_gen.close()

