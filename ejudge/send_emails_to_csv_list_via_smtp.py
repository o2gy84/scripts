#!/usr/bin/env python
# -*- coding: utf-8 -*-
# example: ./send_emails_to_csv_list_via_smtp.py /home/o2gy/test.csv ejudge.bmstu@mail.ru password

import sys
import csv
from email.mime.text import MIMEText
import smtplib
import time

try:
    f = sys.argv[1]
except:
    print "need csv files with students"
    sys.exit()

try:
    ejudge_user = sys.argv[2]
    ejudge_pass = sys.argv[3]
except:
    print "need user and pass to sign up on smtp: ./send_emails_to_csv_list_via_smtp.py test.csv ejudge.bmstu@mail.ru password"
    sys.exit()

smtp_host   = 'smtp.mail.ru'
smtp_port   = 465

def send_email(email, login, password):
    message = u"""
    Вы зарегистрированы в системе тестирования ejudge, курс 'Углубленное программирование на C/C++'.<br \> <br \>

    Адрес для входа в систему: http://195.19.44.139/cgi-bin/new-client?contest_id=2<br \>
    Логин: {0}<br \>
    Пароль: {1}<br \>
    """.format(login, password)

    msg = MIMEText(message.encode('utf-8'), 'html', 'utf-8')
    msg["From"] = ejudge_user
    msg["To"] = email
    msg["Subject"] = "Invitation to the AST ejudge from Technopark BMSTU"

    try:
        session = smtplib.SMTP_SSL(smtp_host, smtp_port)
        session.ehlo()
        session.login(ejudge_user, ejudge_pass)
        session.sendmail(ejudge_user, email, msg.as_string())
        session.quit()
        print "Success"
    except smtplib.SMTPException:
        print "Error: unable to send email"

with open(f, 'rb') as csvfile:
    counter = 0

    reader = csv.reader(csvfile, delimiter=';')
    next(reader)                                    # skip first line

    for row in reader:
        print "Try send email to: ", row[1]
        send_email(row[1], row[0], row[3])
        time.sleep(0.5)
        counter += 1

    print "total: ", counter
