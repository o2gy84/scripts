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
import re
import random

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

#NAMESPACE = "INBOX"
#DELIMITER = "."

NAMESPACE = ""
DELIMITER = "/"

MSGS = [
        "FETCH (UID 12 FLAGS (\Seen) INTERNALDATE \"12-Jun-2016 14:12:10 +0000\")",
#        "FETCH (UID 13 FLAGS (\Seen) INTERNALDATE \"13-Jun-2016 14:12:10 +0000\")",
#        "FETCH (UID 14 FLAGS (\Seen) INTERNALDATE \"13-Jun-2016 14:12:10 +0000\")",
#        "FETCH (UID 15 FLAGS (\Seen) INTERNALDATE \"13-Jun-2016 14:12:10 +0000\")",
#        "FETCH (UID 16 FLAGS (\Seen) INTERNALDATE \"13-Jun-2016 14:12:10 +0000\")",
]

FOLDERS = [
#            "(\\Trash) Deleted",
#            "(\\Junk) Spam",
#            "(\\Sent) Sent",
            "(\\Sent) \"&BB4EQgQ,BEAEMAQyBDsENQQ9BD0ESwQ1-\"",
            "() \"&BB4EQgQ,BEAEMAQyBDsENQQ9BD0ESwQ1-/subsent\"",
            "(\\inbox) INBOX",
#            "() test",
#            "() test1.test2",
#            "() test1.test3",
#            "() test1.test4",
            #"() test1/test1",
            #"() ���� ϶����",
            #"() {43}\r\nArchive.2013.lotte�_steenbrugge@hotmail_com",
            #"() INBOX",
            #"() \"~Public Folders\"",
            #"() \"~Public Folders/Public Contacts\"",
            #"() \"~Public Folders/Domain Contacts\"",
            #"() \"~Other users' folders\"",
            #"(\Unmarked \HasChildren \Noinferiorrrs) \"INBOX\"",
]

def folder_already_exist(str):
    res = False
    for i, val in enumerate(FOLDERS):
        f_name = val.split(' ')[1]
        if f_name.startswith("\""): f_name = f_name[1:]
        if f_name.endswith("\""): f_name = f_name[:-1]
        if f_name == str: res = True
    return res

def simple_send(connection, str):
    if options.printanswer:
        print "<<<" , str
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
    if options.printanswer:
        print "<<<" , str
    try:
        connection.sendall("* " + str + "\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'

def send_fake_msg(connection, subject):
    if options.printanswer:
        print "<<< send fake message"

    fake_message =  "From: TEST_IMAP_SERV <TEST_IMAP_SERV@mail.ru>\r\nTo: bbbbb <bbbbb@mail.ru>, cccccc <cccccccccccc@mail.ru>\r\n"
    fake_message += "Subject: {0}\r\n".format(subject)
    fake_message += "Date: Wed, 23 Jul 2014 17:53:07 +0400\r\n"
    fake_message += "\r\n"
    fake_message += "This is just fake message\r\nTo testing our imap-collector\r\n"
    fake_message += "On memory leaks\r\n"

    length = len(fake_message)
    leading_string = "* 1 FETCH (UID 587 INTERNALDATE \"05-Jun-2015 14:12:10 +0000\" BODY[] {{{0}}}".format(length)
    try:
        connection.sendall(leading_string  + "\r\n")
        connection.sendall(fake_message)
        connection.sendall(")\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'

def send_fake_msg_without_continuation(connection, subject):
    if options.printanswer:
        print "<<< send fake message without continuation"

    fake_message =  "From: TEST_IMAP_SERV <TEST_IMAP_SERV@mail.ru>\r\nTo: bbbbb <bbbbb@mail.ru>, cccccc <cccccccccccc@mail.ru>\r\n"
    fake_message += "Subject: {0}\r\n".format(subject)
    fake_message += "Date: Wed, 23 Jul 2014 17:53:07 +0400\r\n"
    fake_message += "\r\n"
    fake_message += "This is just fake message\r\nTo testing our imap-collector\r\n"
    fake_message += "On memory leaks\r\n"
    fake_message = "* 1 FETCH (UID 587 INTERNALDATE \"05-Jun-2015 14:12:10 +0000\" BODY[] " + fake_message

    try:
        connection.sendall(fake_message)
        connection.sendall(")\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'

def send_broken_msg(connection):
    if options.printanswer:
        print "<<< send broken message"

    fake_message =  "From: aaaaa <aaaaa@mail.ru>\r\nTo: bbbbb <bbbbb@mail.ru>, cccccc <cccccccccccc@mail.ru>\r\nSubject: this is just subject\r\n"
    fake_message += "Date: Wed, 23 Jul 2014 17:53:07 +0400\r\n"
    fake_message += "\r\n"
    fake_message += "This is just fake message\r\nTo testing our imap-collector\r\n"
    fake_message += "On memory leaks\r\n"

    length = len(fake_message)
    leading_string = "* 1 FETCH (UID 587 INTERNALDATE \"02-May-2014 14:12:10 +0000\" BODY[] {{{0}}}".format(length)
    try:
        connection.sendall(leading_string  + "\r\n")
        connection.sendall(fake_message)
        connection.sendall("ailable.\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'


def send_nil_msg(connection):
    if options.printanswer:
        print "<<< send nil message"

    leading_string = "* 1 FETCH (UID 587 BODY[] NIL"
    try:
        connection.sendall(leading_string  + "\r\n")
        connection.sendall(")\r\n")
    except BaseException:
        print >>sys.stderr, 'socket write error'

def process_client(connection):
    try:
        connection.sendall("+OK Welcome to TEST SERVER\r\n")
        #connection.sendall("Only Essi Corporation Users are authorized to use this service.\r\n")
        statuses_received = 0
        fetch_body_received = 0
        current_folder = ""
        while True:
            data = connection.recv(2048)
            data = data[:-2]
            print >>sys.stderr, '>>> %s' % data
            if data:
                if data.find("DONE") == -1:
                    cmdnum = data.split(' ')[0]
                if data.find("LOGIN") != -1:
                    tagged_send(connection, cmdnum, "OK")
                    #tagged_send(connection, cmdnum, "BAD LOGIN- User Account does not have access to this service")
                    #simple_send(connection, "NO cleartext logins disabled")
                if data.find("DIGEST-MD5") != -1:
                    #tagged_send(connection, cmdnum, "NO 111")
                    simple_send(connection, "+ cmVhbG09IiIsbm9uY2U9IlVXSVZIQkZ3b2NlNXJ5ZmczdldqblE9PSIscW9wPSJhdXRoIixjaGFyc2V0PSJ1dGYtOCIsYWxnb3JpdGhtPSJtZDUtc2VzcyI=")
                if data.find("Y2hhcnNldD11") != -1:
                    decoded = base64.b64decode(data)
                    print >>sys.stderr, 'decoded: %s' % decoded
                    tagged_send(connection, "1", "NO MD5 AUTHORIZATION IS INVALID !!!")
                    #tagged_send(connection, "1", "OK authorization")
                if data.find("CAPABILITY") != -1:
                    #notagged_send(connection, "CAPABILITY IDLE NAMESPACE")
                    notagged_send(connection, "CAPABILITY IDLE LITERAL+ MULTIAPPEND NAMESPACE QUOTA UNSELECT WITHIN STARTTLS LOGINDISABLED")
                    tagged_send(connection, cmdnum, "OK capability complited")
                if data.find("NAMESPACE") != -1:
                    notagged_send(connection, "NAMESPACE ((\"{0}{1}\" \"{2}\")) NIL NIL".format(NAMESPACE, DELIMITER, DELIMITER))
                    #notagged_send(connection, "NAMESPACE () NIL NIL")
                    #notagged_send(connection, "NAMESPACE ((\"XYZ.\" \".\")) ((\"~Other users' folders\" \"/\")) (({22}")
                    #simple_send(connection, "~Общая папка \"/\"))")
                    tagged_send(connection, cmdnum, "OK Namespace complited")
                if data.find("LOGOUT") != -1:
                    tagged_send(connection, cmdnum, "OK LOGOUT complited")
                if data.find("LIST") != -1:
                    for folder in FOLDERS:

                        parts = folder.split(' ')
                        name = parts[1]

                        if name == "INBOX" or name == "\"INBOX\"":
                            real_name = name
                        else:
                            if len(NAMESPACE) > 0:
                                real_name = NAMESPACE + DELIMITER + name
                            else:
                                real_name = name

                        #                          flags
                        list_arg = 'LIST' + ' ' + parts[0] + ' "' + DELIMITER + '" ' + real_name
                        notagged_send(connection, list_arg)
 
                    #tagged_send(connection, cmdnum, "BAD nah!!!")
                    #tagged_send(connection, cmdnum, "NO failed")
                    tagged_send(connection, cmdnum, "OK")
                if data.find("STATUS") != -1:
                    statuses_received = statuses_received + 1
                    if statuses_received > 2:
                        time.sleep(1)

                    status_regexp = re.compile("(\d*)\sSTATUS\s(\"?)(.*?)\"?\s\(")
                    folders = data.split('\r\n');
                    for f in folders:
                        tmp = status_regexp.match(f)
                        cmdnum = tmp.group(1)
                        folder = tmp.group(3)
                        if tmp.group(2) == "\"":
                            folder = "\"" + folder + "\""

                        if folder.find("Inbox") != -1 or folder.find("INBOX") != -1:
                            #notagged_send(connection, "STATUS {0} (UIDNEXT {1} HIGHESTMODSEQ 14317852 MESSAGES 41475 UIDVALIDITY 1)".format(folder, statuses_received))
                            #notagged_send(connection, "STATUS {0} (UIDNEXT 37 MESSAGES {1} UIDVALIDITY 18446744073709550614 HIGHESTMODSEQ 114)".format(folder, len(MSGS)))
                            notagged_send(connection, "STATUS {0} (UIDNEXT 37 MESSAGES {1} UIDVALIDITY 18446744073709550614 HIGHESTMODSEQ {2})".format(folder, len(MSGS), random.randint(0,9)))
                        #elif folder.find("test") != -1:
                        #    notagged_send(connection, "STATUS {0} (UIDNEXT 22 MESSAGES 10 UIDVALIDITY 1)".format(folder))
                        #elif folder.find("Spam") != -1:
                        #    notagged_send(connection, "STATUS {0} (SPAM UIDNEXT 1 MESSAGES 1 UIDVALIDITY 2)".format(folder))
                        elif folder.find("BAD_STATUS") != -1:
                            tagged_send(connection, cmdnum, "NO THIS IS SPARTAAA!!!")
                            continue
                        else:
                            notagged_send(connection, "STATUS {0} (UIDNEXT {1} MESSAGES {2} HIGHESTMODSEQ 333 UIDVALIDITY 1)".format(folder, statuses_received, len(MSGS)))

                        tagged_send(connection, cmdnum, "OK STATUS")

                if data.find("SELECT") != -1:
                    #6 SELECT "INBOX"
                    vals = data.split(' ');
                    current_folder = vals[2]
                    notagged_send(connection, "0 exists")
                    notagged_send(connection, "OK [UIDVALIDITY 666]")
                    #simple_send(connection, "")            # <== empty line
                    tagged_send(connection, cmdnum, "OK [READ-WRITE] select completed")
                    #tagged_send(connection, cmdnum, "OK [READ-ONLY] SELECT completed")
                if data.find("EXAMINE") != -1:
                    notagged_send(connection, "0 exists")
                    #tagged_send(connection, cmdnum, "OK [READ-WRITE] select completed")
                    tagged_send(connection, cmdnum, "OK [READ-ONLY] SELECT completed")
                if data.find("UID FETCH") != -1:
                    if data.find("BODY") == -1:
 
                        #notagged_send(connection, "FETCH (UID 32 FLAGS (\Seen) INTERNALDATE \" 2-May-2014 14:12:11 +0000\")")
                        tagged_send(connection, cmdnum, "OK FETCH done")
                        #notagged_send(connection, "0 exists")
                    else:
                        fetch_body_received = fetch_body_received + 1

                        # CASE with not the same cmd number
                        #if fetch_body_received > 2:
                        #    send_fake_msg(connection)
                        #    tagged_send(connection, cmdnum, "OK")
                        #else:
                        #    tagged_send(connection, str(int(cmdnum) - 1), "OK")

                        # CASE with many messages by one uid
                        #if fetch_body_received > 0:
                        #    send_fake_msg(connection)
                        #    send_fake_msg(connection)
                        #    tagged_send(connection, cmdnum, "OK")
                        #else:
                        #    send_fake_msg(connection)
                        #    tagged_send(connection, cmdnum, "OK")

                        # NORMAL CASE
                        if current_folder.find("INBOX") != -1:
                            #send_nil_msg(connection)
                            send_fake_msg(connection, "INBOX SUBJECT")
                            #send_fake_msg_without_continuation(connection, "INBOX SUBJECT")
                        else:
                            send_fake_msg(connection, "OTHER SUBJECT")

                        #send_nil_msg(connection)
                        tagged_send(connection, cmdnum, "OK")

                        #send_broken_msg(connection)
                        #tagged_send(connection, cmdnum, "NO UID FETCH completed")

                        time.sleep(2)
                elif data.find("FETCH") != -1:
                        # либо 1 fetch 1:* (uid)
                        # либо 1 fetch * (UID BODY.PEEK[HEADER.FIELDS (X-Append-Orig-Uidl)])

                        vals = data.split(' ')
                        msgs_range = vals[2]

                        if msgs_range == '*':
                            notagged_send(connection, MSGS[len(MSGS) - 1])
                        else:
                            vals2 = msgs_range.split(':')
                        
                            min_index = vals2[0]
                            max_index = vals2[1]
                        
                            if max_index == '*':
                                max_index = 999999
                            else:
                                max_index = int(max_index)
                            min_index = int(min_index) - 1

                            i = 0
                            sended = 0
                            for msg in MSGS:
                                if i >= min_index and i < max_index:
                                    notagged_send(connection, msg)
                                    sended = sended + 1
                                i = i + 1

                            if sended == 0 and i > 0:
                                # надо хоть что-то послать
                                notagged_send(connection, MSGS[i - 1])

                        tagged_send(connection, cmdnum, "OK")
                        #tagged_send(connection, cmdnum, "NO The specified message set is invalid.")
                if data.find("UID COPY") != -1:
                        #tagged_send(connection, cmdnum, "NO Mailbox is empty")
                        #tagged_send(connection, cmdnum, "NO COPY Unable to write to database because database would exceed its disk quota")
                        tagged_send(connection, cmdnum, "OK [COPYUID 2 51 777] (Success)")
                if data.find("UID MOVE") != -1:
                        simple_send(connection, "[COPYUID 12  ]")
                        tagged_send(connection, cmdnum, "OK (Success)")
                if data.find("UID STORE") != -1:
                        #tagged_send(connection, cmdnum, "NO UID COPY failed")
                        tagged_send(connection, cmdnum, "OK UID Store complited")
                        #tagged_send(connection, "777", "OK UID Store complited")
                if data.find("EXPUNGE") != -1:
                        notagged_send(connection, "752 EXPUNGE")
                        simple_send(connection, "")
                        tagged_send(connection, cmdnum, "OK UID Store complited")
                if data.find("APPEND") != -1:
                        tagged_send(connection, cmdnum, "OK (Success)")
                if data.find("IDLE") != -1:
                    simple_send(connection, "+ idling")

                    #simple_send(connection, "+ waiting for done")
                    #notagged_send(connection, "ok timeout in 30 minutes")

                    #time.sleep(100)
                    #notagged_send(connection, "bye session expired, please login again")

                    # TEST CASE 1
                    #notagged_send(connection, "BYE System error")
                    #connection.shutdown(socket.SHUT_RDWR)

                    # TEST CASE 2
                    #notagged_send(connection, "aaaaa")
                    #notagged_send(connection, "bbbbb")
                    #notagged_send(connection, "ccccc")
                    #notagged_send(connection, "return-path: sssss")
                    #time.sleep(5)
                    #notagged_send(connection, "2 exists")

                    # TEST CASE 3
                    #notagged_send(connection, "2 exists")
                    #notagged_send(connection, "2 expunge")
                    #notagged_send(connection, "2 blabla")
                    #simple_send(connection, "+ idling")
                if data.find("DONE") != -1:
                    #cmdnum = "1"
                    tagged_send(connection, cmdnum, "OK IDLE terminated")
                if data.find("CREATE") != -1:
                    # 8 CREATE "test"
                    # 8 CREATE "INBOX/test"
                    # 8 CREATE "INBOX.INBOX.test"

                    if 1:
                        vals = data.split(' ')
                        folder_flags = '()'
                        name_to_append = vals[2]
                        if name_to_append.startswith("\""): name_to_append = name_to_append[1:]
                        if name_to_append.endswith("\""): name_to_append = name_to_append[:-1]

                        if len(NAMESPACE) > 0:
                            # значит имя должно начинаться на NAMESPACE
                            name_parts = name_to_append.split(DELIMITER)

                            # обнулим имя и построим его занова из частей name_parts
                            name_to_append = ''

                            check_namespace = name_parts[0]
                            if check_namespace != NAMESPACE:
                                tagged_send(connection, cmdnum, "NO CREATE failed: invalid")
                                continue

                            for i, val in enumerate(name_parts):
                                if i == 0:
                                    continue
                                if i > 1:
                                    name_to_append = name_to_append + DELIMITER;
                                name_to_append = name_to_append + val

                        if folder_already_exist(name_to_append) == True:
                            tagged_send(connection, cmdnum, "NO [ALREADYEXIST] failed")
                            continue

                        new_folder = folder_flags + ' ' + name_to_append
                        FOLDERS.append(new_folder)
                        tagged_send(connection, cmdnum, "OK CREATE complited")
                    else:
                        tagged_send(connection, cmdnum, "NO CREATE failed: invalid mailbox name")

                if data.find("DELETE") != -1:
                    #tagged_send(connection, cmdnum, "OK DELETE complited")
                    tagged_send(connection, cmdnum, "NO DELETE failed")
                if data.find("CLOSE") != -1:
                    time.sleep(3)

                    #notagged_send(connection, "all expunges e.t.c.")
                    tagged_send(connection, cmdnum, "OK CLOSE")
            else:
                print >>sys.stderr, 'unknown command'
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



