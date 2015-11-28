#!/usr/bin/env python
# -*- coding: utf-8 -*-
# example: ./send_emails_to_csv_list_via_smtp.py /home/o2gy/test.csv ejudge.bmstu@mail.ru password

import sys
import csv
from email.mime.text import MIMEText
from email.parser import Parser
import smtplib
import time

try:
    f = sys.argv[1]
except:
    print "enter msg to send"
    sys.exit()

try:
    user = sys.argv[2]
    password = sys.argv[3]
except:
    print "need user and pass to sign up on smtp: ./send_emails_to_csv_list_via_smtp.py msg.eml vasya@mail.ru password"
    sys.exit()

smtp_host   = 'smtp.mail.ru'
smtp_port   = 465

def send_email(message, login, passwd):

    #headers = Parser().parsestr(message)
    #print 'To: %s' % headers['to']
    #print 'From: %s' % headers['from']
    #msg = MIMEText(message.encode('utf-8'), 'html', 'utf-8')
    #msg = MIMEText(message)
    #msg["From"] = login
    #msg["To"] = login
    #msg["Subject"] = headers['subject']

    try:
        session = smtplib.SMTP_SSL(smtp_host, smtp_port)
        session.set_debuglevel(1)
        session.ehlo()
        session.login(login, passwd)
        session.sendmail(login, login, message)
        session.quit()
        print "Success"
    except smtplib.SMTPException:
        print "Error: unable to send"

with open(f, 'rb') as file:
    msg = file.read()
    file.close()
    send_email(msg, user, password)
