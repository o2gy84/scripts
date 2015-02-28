#!/usr/bin/env python 
# -*- coding: utf-8 -*- 

import sys
import csv
from email.mime.text import MIMEText
from subprocess import Popen, PIPE
import time

try:
    f = sys.argv[1]
except:
    print "need csv files with students"
    sys.exit()

counter = 0 


def send_email(email, login, password):
    message = u"""
    Вы зарегистрированы в системе тестирования ejudge, курс 'Углубленное программирование на C/C++'.<br \> <br \>
    
    Адрес для входа в систему: http://195.19.44.139/cgi-bin/new-client?contest_id=2<br \>
    Логин: {0}<br \>
    Пароль: {1}<br \>
    """.format(login, password)

    msg = MIMEText(message.encode('utf-8'), 'html', 'utf-8')
    msg["From"] = "ejudge@195.19.44.139"
    msg["To"] = email
    msg["Subject"] = "Invitation to the AST ejudge from Technopark BMSTU"
    p = Popen(["/usr/sbin/sendmail", "-t", "-oi"], stdin=PIPE)
    p.communicate(msg.as_string())

with open(f, 'rb') as csvfile:
    reader = csv.reader(csvfile, delimiter=';')
    next(reader)                                    # skip first line
    for row in reader:
        print "email: ", row[1]
        send_email(row[1], row[0], row[3])
        time.sleep(0.5)
        counter += 1

print "total: ", counter
