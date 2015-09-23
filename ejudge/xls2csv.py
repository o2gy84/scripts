#!/usr/bin/env python
# -*- coding: utf-8 -*-

import xlrd
import sys
import csv
import string
import random

try:
    sys.argv[1]
except:
    print "need xls files with students"
    sys.exit()

def generate_pass(size=12, chars=string.ascii_uppercase + string.digits):
    return ''.join(random.choice(chars) for _ in range(size))

students_map = {}

for f in sys.argv[1:]:
    rb = xlrd.open_workbook(f, formatting_info=True)
    sheet = rb.sheet_by_index(0)                        # select first list in .xls file
    for rownum in range(sheet.nrows):
        if rownum == 0:                                 # skip first line
            continue
        row = sheet.row_values(rownum)

        # this part may change!
        login = row[0].strip()
        email = row[3].strip()

        students_map[login] = email

#print "students total: ", len(students_map)

#writer = csv.writer(open("/home/ejudge/test.csv", 'w'), dialect='excel', delimiter=';')
writer = csv.writer(sys.stdout, dialect='excel', delimiter=';')
writer.writerow(['login', 'email', 'name', 'password'])

for login, email in students_map.items():
    writer.writerow([login, email, login, generate_pass()])
