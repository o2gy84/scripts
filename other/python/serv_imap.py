# -*- coding: utf-8 -*-
__author__ = "o2gy"
# connection-oriented server

import socket
import time
import sys
from multiprocessing import Process
import os
from optparse import OptionParser
import base64

host = "localhost"

parser = OptionParser()
parser.add_option("--port", "-p", help="listen port", dest="port", type=int, default=7789)
parser.add_option("--printanswer", help="print server answers", action="store_true", dest="printanswer", default=False)

(options, args) = parser.parse_args()

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind( (host, options.port) )
sock.listen(5)

print "Test Server waiting for client on port:", options.port

def simple_send(connection, str):
    try:
        connection.sendall(str + "\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'

def tagged_send(connection, cmdnum, str):
    if options.printanswer:
        print "<<<" , str
    try:
        connection.sendall(cmdnum + " " + str + "\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'

def notagged_send(connection, str):
    try:
        connection.sendall("* " + str + "\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'

def send_fake_msg(connection):
    fake_message =  "From: aaaaa <aaaaa@mail.ru>\r\nTo: bbbbb <bbbbb@mail.ru>, cccccc <cccccccccccc@mail.ru>\r\nSubject: this is just subject\r\n"
    fake_message += "Date: Wed, 23 Jul 2014 17:53:07 +0400\r\n"
    fake_message += "\r\n"
    fake_message += "This is just fake message\r\nTo testing our imap-collector\r\n"
    fake_message += "On memory leaks\r\n"

    length = len(fake_message)
    leading_string = "* 1 FETCH (UID 587 BODY[] {{{0}}}".format(length)
    try:
        connection.sendall(leading_string  + "\r\n")
        connection.sendall(fake_message)
        connection.sendall(")\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'

def process_client(connection):
    try:
        connection.sendall("+OK Welcome to TEST SERVER\r\n")
        statuses_received = 0
        while True:
            data = connection.recv(2048)
            data = data[:-2]
            print >>sys.stderr, '>>> %s' % data
            if data:
                cmdnum = data.split(' ')[0]
                if data.find("LOGIN") != -1:
                    tagged_send(connection, cmdnum, "OK")
                if data.find("DIGEST-MD5") != -1:
                    #tagged_send(connection, cmdnum, "NO 111")
                    simple_send(connection, "+ cmVhbG09IiIsbm9uY2U9IlVXSVZIQkZ3b2NlNXJ5ZmczdldqblE9PSIscW9wPSJhdXRoIixjaGFyc2V0PSJ1dGYtOCIsYWxnb3JpdGhtPSJtZDUtc2VzcyI=")
                if data.find("Y2hhcnNldD11") != -1:
                    decoded = base64.b64decode(data)
                    print >>sys.stderr, 'decoded: %s' % decoded
                    tagged_send(connection, "1", "NO MD5 AUTHORIZATION IS INVALID !!!")
                    #tagged_send(connection, "1", "OK authorization")
                if data.find("CAPABILITY") != -1:
                    notagged_send(connection, "CAPABILITY IDLE NAMESPACE")
                    tagged_send(connection, cmdnum, "OK capability complited")
                if data.find("NAMESPACE") != -1:
                    notagged_send(connection, "NAMESPACE ((\"INBOX.\" \".\")) NIL NIL")
                    #notagged_send(connection, "NAMESPACE () NIL NIL")
                    tagged_send(connection, cmdnum, "OK Namespace complited")
                if data.find("LOGOUT") != -1:
                    tagged_send(connection, cmdnum, "OK LOGOUT complited")
                if data.find("LIST") != -1:
                    #notagged_send(connection, "LIST () \"/\" Sent Messages")
                    #notagged_send(connection, "LIST () \"/\" Sent Items")
                    #notagged_send(connection, "LIST (\\inbox) \"/\" Inbox")
                    #notagged_send(connection, "LIST (\\junk) \"/\" Junk")
                    #notagged_send(connection, "LIST () \".\" \"INBOX.SentMail\"")
                    #notagged_send(connection, "LIST () \".\" \"INBOX.Trash\"")
                    notagged_send(connection, "LIST () \"/\" Sent")
                    notagged_send(connection, "LIST (\Trash) \"/\" Trash")
                    notagged_send(connection, "LIST () \".\" INBOX")
                    tagged_send(connection, cmdnum, "OK")
                if data.find("STATUS") != -1:
                    statuses_received = statuses_received + 1
                    if statuses_received > 2:
                        time.sleep(1)
                    p = data.split(' ')
                    folder = p[2]
                    if folder.find("Inbox") != -1 or folder.find("INBOX") != -1:
                        notagged_send(connection, "STATUS {0} (UIDNEXT {1} MESSAGES 1 UIDVALIDITY 1)".format(folder, statuses_received))
                    else:
                        notagged_send(connection, "STATUS {0} (UIDNEXT {1} MESSAGES 1 UIDVALIDITY 1)".format(folder, statuses_received))
                    tagged_send(connection, cmdnum, "OK")
                if data.find("SELECT") != -1:
                    notagged_send(connection, "0 exists")
                    #tagged_send(connection, cmdnum, "OK [READ-WRITE] select completed")
                    tagged_send(connection, cmdnum, "OK [READ-ONLY] SELECT completed")
                if data.find("UID FETCH") != -1:
                    if data.find("BODY") == -1:
                        #notagged_send(connection, "FETCH (UID 587 INTERNALDATE \"09-Jul-2014 09:21:57 +0000\" FLAGS (\Seen))")
                        notagged_send(connection, "FETCH (UID 123456789 FLAGS (\Seen) INTERNALDATE \" 2-May-2014 17:12:07 +0000\")")
                        tagged_send(connection, cmdnum, "OK FETCH done")
                        #notagged_send(connection, "0 exists")
                    else:
                        send_fake_msg(connection)
                        tagged_send(connection, cmdnum, "OK")
                        time.sleep(3)
                if data.find("UID COPY") != -1:
                        tagged_send(connection, cmdnum, "NO UID COPY failed")
                if data.find("IDLE") != -1:
                    simple_send(connection, "+ idling")
                    time.sleep(10)
                    notagged_send(connection, "bye session expired, please login again")

                    # TEST CASE 1
                    #notagged_send(connection, "BYE System error")
                    #connection.shutdown(socket.SHUT_RDWR)

                    # TEST CASE 2
                    #notagged_send(connection, "aaaaa")
                    #notagged_send(connection, "bbbbb")
                    #notagged_send(connection, "ccccc")
                    #notagged_send(connection, "return-path: sdasdasd")
                    #time.sleep(5)
                    #notagged_send(connection, "2 exists")

                    # TEST CASE 3
                    #notagged_send(connection, "2 exists")
                    #notagged_send(connection, "2 expunge")
                    #notagged_send(connection, "2 blabla")
                    #simple_send(connection, "+ idling")
                if data.find("DONE") != -1:
                    cmdnum = "1"
                    tagged_send(connection, cmdnum, "OK IDLE terminated")
                if data.find("CREATE") != -1:
                    #tagged_send(connection, cmdnum, "OK CREATE complited")
                    tagged_send(connection, cmdnum, "NO CREATE error")
            else:
                break
    finally:
        connection.close()
        print >>sys.stderr, 'process exited'

while True:
    print >>sys.stderr, 'waiting for a connection'
    connection, client_address = sock.accept()
    print >>sys.stderr, 'client connected:', client_address
    p = Process(target=process_client, args=(connection,))
    p.start()



