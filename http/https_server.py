#!/usr/bin/python
# -*- coding: utf-8 -*-
__author__ = "o2gy"

import time, sys, os
from pprint import pprint
from optparse import OptionParser

import re
import shutil

import BaseHTTPServer
from BaseHTTPServer import BaseHTTPRequestHandler
import cgi
import urlparse

import string
import random

import tarfile
import zipfile
import hashlib

import subprocess
import fcntl
import ssl

def get_md5(data):
    m = hashlib.md5()
    m.update(data)
    return m.hexdigest()

def generate_id(size=12, chars=string.ascii_uppercase + string.digits):
    """ session id generating """
    return ''.join(random.choice(chars) for _ in range(size))

def send_registration_form(s):
    form = """
<html>
    <head>
        <meta charset="utf-8">
    </head>
    <body>
        HELLO {0}
    </body>
</html>
    """.format( "user"  )
    s.send_response(200)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write(form)

def send_OK(s):
    s.send_response(200)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write("<p>test page</p>")

def send_no_permission(s):
    s.send_response(403)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write("<p>permission denied</p>")

def send_not_found(s):
    s.send_response(404)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write("<p>resource not found</p>")

def send_validation_token(s, token):

    body = str(token[0])

    s.send_response(200)
    s.send_header("Content-type", "text/plain")
    s.send_header("Content-Length", str(len(body)))
    s.end_headers()
    s.wfile.write("{0}".format(body))

def get_action_from_request(s):
    urlstring = "http://" + s.headers['host'] + s.path
    urlobject = urlparse.urlparse(urlstring)
    query_string_map = urlparse.parse_qs(urlobject.query);
    action = ''.join(str(x) for x in query_string_map['action'])
    return action

def check_url(s):
    urlstring = "http://" + s.headers['host'] + s.path
    urlobject = urlparse.urlparse(urlstring)
    query_string_map = urlparse.parse_qs(urlobject.query);
    
    #pprint(query_string_map)

    if (query_string_map.has_key('validationtoken')):
        send_validation_token(s, query_string_map['validationtoken'])
        return True

    return False

class UploaderHttpRequestHandler(BaseHTTPServer.BaseHTTPRequestHandler):

    def do_GET(s):
        """Respond to a GET request."""
        print s.headers

        if (check_url(s)):
            return
        send_OK(s)

    def do_POST(s):
        """Respond to a POST request."""
        print s.headers

        if (check_url(s)):
            return
        send_OK(s)

if __name__ == '__main__':

    #host = 'localhost'
    host = '195.19.44.139'
    port = 5001
    cert = '/home/ejudge/server.pem'

    httpd = BaseHTTPServer.HTTPServer((host, port), UploaderHttpRequestHandler)
    httpd.socket = ssl.wrap_socket(httpd.socket, certfile=cert, server_side = True)
    fcntl.fcntl(httpd.socket, fcntl.F_SETFD, fcntl.FD_CLOEXEC)  # after Popen() need to close sockets

    try:
        print "start server on port:", port,", host:", host
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
