#!/usr/bin/python

import os,sys
import string

try:
    filename = sys.argv[1]
except:
    os.exit (1)

cs_lines=0
section=0
section_start=0
global_lines=0
start_line=0
end_line=0
for lines in file(filename):
    global_lines += 1
    if lines.find ("_mutex_lock(") != -1 or lines.find ("_mutex_lock (") != -1 or  lines.find (" LOCK(") != -1 or lines.find (" LOCK (") != -1 or lines.find ("_mutex_trylock") != -1 or lines.find ("TRY_LOCK") != -1:
        cs_lines = 0
        section_start = global_lines
        start_line = global_lines
        section += 1
        end_line=0

    if lines.find ("_mutex_unlock(") != -1 or lines.find ("_mutex_unlock (") != -1 or lines.find (" UNLOCK (") != -1 or lines.find (" UNLOCK(") != -1:
        if cs_lines != 0:
            print "%d %d %s" % (cs_lines, section_start, filename)
        if end_line != 0:
            print "%d %d DUP:%s" % (global_lines - start_line, start_line, filename)
            
        section_start = 0
        cs_lines = 0
        end_line = global_lines
        continue

    if section_start is not 0:
        cs_lines += 1

