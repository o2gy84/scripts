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

def username_tail(size=4, chars=string.ascii_lowercase):
    return ''.join(random.choice(chars) for _ in range(size))

def username_from_email(email):
    name, other = email.split("@", 2)
    return name + "." + username_tail()

only_email = True
skip_first_line = False

students_map = {}

for f in sys.argv[1:]:
    print "file: ", f
    rb = xlrd.open_workbook(f, formatting_info=True)
    sheet = rb.sheet_by_index(0)                        # select first list in .xls file
    for rownum in range(sheet.nrows):
        if rownum == 0 and skip_first_line:             # skip first line
            continue
        row = sheet.row_values(rownum)

        login = ""
        email = ""
        if only_email == True:
            email = row[2].strip()
            login = username_from_email(email)
        else:
            login = row[1].strip()
            email = row[4].strip()
            
        students_map[login] = email
        print "login: ",login, ", email: ",email

#for login, email in students_map.items():
#    print "login: ",login, ", email: ",email

print "students total: ", len(students_map)

writer = csv.writer(open("/home/ejudge/test.csv", 'w'), dialect='excel', delimiter=';')
writer.writerow(['login', 'email', 'name', 'password'])

for login, email in students_map.items():
    writer.writerow([login, email, login, generate_pass()])
