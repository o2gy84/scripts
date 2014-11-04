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

import subprocess
import fcntl


g_SESSIONS = {}
g_SESSION_EXPIRATION_TIME = 60 * 5
g_MAIN_URL = "http://195.19.44.139:5000"
g_ADMIN = 'admin'
g_PASSWORD = '1'
g_PROBLEMS_PATH = "/home/ejudge/tmp/problems/"
g_TEMP_DIR = "/home/ejudge/tmp/upload/"
g_USER_PROBLEM_DESCRIPTION_FILE = 'description.txt'
g_EJUDGE_PROBLEM_DESCRIPTION_FILE = 'Description.xml'
g_DESCRIPTION_GENERATOR = '/home/ejudge/scrips/generate_description.py'
g_EJUDGE_CONTROL = '/home/ejudge/inst-ejudge/bin/ejudge-control'


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
        <form action="{0}/?action=auth" method="post">
            <p>login&nbsp;<input type="text" name="login"><br>
            <p>pass&nbsp;&nbsp;<input type="password" name="password"><br>
            <p><input type="submit"></p>
        </form>
    </body>
</html>
    """.format(g_MAIN_URL)
    s.send_response(200)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write(form)

def send_problems_list(s):

    s.send_response(200)
    s.send_header("Content-type", "text/html")
    s.end_headers()

    s.wfile.write("<html><head><meta charset='utf-8'><title>Loaded tests</title></head>")
    s.wfile.write("<body><p>Tests are loaaded:</p><table border='1'>")

    some = "_"

    ejudge = Ejudge()
    problems = ejudge.get_problems()
    problems.sort()
    for problem in problems:
        s.wfile.write("<tr><td> %s </td><td> %s </td><td> %s </td></tr>" % (problem.number(), problem.description(), some))
    s.wfile.write("</table>")

    session_id = generate_id()
    g_SESSIONS[session_id] = time.time()
    
    load_form = """
    <br>
    <div style="margin: 0px auto; text-align: left;">
        <form action="{0}/?action=load&sid={1}" enctype="multipart/form-data" method="post">
            <p>tar.gz/zip only accepted</p>
            <p><input type="file" accept=".tar.gz,.zip" name="archive"></p>
            <p><input type="submit"></p>
        </form>
    </div>""".format(g_MAIN_URL, session_id)

    s.wfile.write(load_form)
    s.wfile.write("</body></html>")


def send_no_permission(s):
    s.send_response(403)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write("<p>permission denied</p>")
    s.wfile.write("<br><a href='{0}'>main</a>".format(g_MAIN_URL))

def send_not_found(s):
    s.send_response(404)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write("<p>resource not found</p>")
    s.wfile.write("<br><a href='{0}'>main</a>".format(g_MAIN_URL))

def send_bad_archive_response(req):
    req.send_response(400)
    req.send_header("Content-type", "text/html")
    req.end_headers()
    req.wfile.write("<p>something wrong with your archive - no test founded in archive root directory</p>")
    req.wfile.write("<br><a href='{0}'>main</a>".format(g_MAIN_URL))

def check_login(s):
    """ check login received via POST method """
    length = s.headers['content-length']
    data = s.rfile.read(int(length))
    param = data.split('&')
    query_string = {}
    for key in param:
        array = key.split('=')
        query_string[array[0]] = array[1]

    #pprint (query_string)
    
    if (query_string['login'] == g_ADMIN and query_string['password'] == g_PASSWORD):
        return True

    send_no_permission(s)
    return False

def check_session_id(session_id):

    now = time.time()
    for sid, creation_time in g_SESSIONS.items():
        if (now - creation_time > g_SESSION_EXPIRATION_TIME):
            del g_SESSIONS[sid]

    if session_id in g_SESSIONS:
        return True
    else:
        return False;

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
    #pprint( query_string_map )

    if (not query_string_map.has_key('action')):
        send_registration_form(s)
        return False

    valid_urls = ['auth', 'load']
    action = get_action_from_request(s)
    if(not action in valid_urls):
        send_not_found(s)
        return False

    if (not query_string_map.has_key('sid')):
        send_no_permission(s)
        return False

    session_id = ''.join(str(x) for x in query_string_map['sid'])
    if (not check_session_id(session_id)):
        send_no_permission(s)
        return False
    
    return True

def clear_upload_temp_directory():
    if not os.path.exists(g_TEMP_DIR):
        os.makedirs(g_TEMP_DIR)

    for file_object in os.listdir(g_TEMP_DIR):
        file_object_path = os.path.join(g_TEMP_DIR, file_object)
        if os.path.isfile(file_object_path):
            os.unlink(file_object_path)
        else:
            # with no ignore errors
            shutil.rmtree(file_object_path, False)

def restart_ejudge():
    """ ./ejudge-control stop && ./ejudge-control start """
    subprocess.Popen([g_EJUDGE_CONTROL, "stop"]).wait()
    time.sleep(0.1)
    subprocess.Popen([g_EJUDGE_CONTROL, "start"]).wait()

def regenerate_tests(path):
    """ convert description.txt into Description.txt, and restart ejudge """
    subprocess.call([g_DESCRIPTION_GENERATOR, path])    # blocking call

def move_problems(req):
    """ check and move loaded problems """
    checked_dirs = []
    for f in os.listdir(g_TEMP_DIR):
        if (re.match('^(A|B|C|D)-\d{1,2}$', f)):
            problem_file = os.path.join(g_TEMP_DIR, f, g_USER_PROBLEM_DESCRIPTION_FILE)
            try:
                with open(problem_file) as pf:
                    checked_dirs.append(f)
            except:
                continue

    if len(checked_dirs) == 0 :
        send_bad_archive_response(req)
        return False

    moved_problems = 0
    for f in checked_dirs:
        original_problems_path = g_PROBLEMS_PATH + f
        if (not os.path.exists(original_problems_path)):
            shutil.move(g_TEMP_DIR + f, original_problems_path)
            regenerate_tests(original_problems_path)
            moved_problems += 1

    if moved_problems > 0:      # need to restart system
        restart_ejudge()

    return True

def load_archive(req):
    """ save archive from post request into file, extracting and move files """
    form = cgi.FieldStorage(
        fp=req.rfile, 
        headers=req.headers,
        environ={'REQUEST_METHOD':'POST', 'CONTENT_TYPE':req.headers['Content-Type'],}
    )

    item = form['archive']
    if (not item.filename):
        send_problems_list(req)
        return

    re_targz = re.compile('.*\.tar\.gz')
    re_zip = re.compile('.*\.zip')
    is_tar = is_zip = False

    if (re_targz.match(item.filename)):
        is_tar = True
    elif (re_zip.match(item.filename)):
        is_zip = True
    else :
        send_problems_list(req)
        return

    data = item.file.read()
    with open(g_TEMP_DIR + item.filename, 'w') as f:
        f.write(data)

    if is_tar:
        tar = tarfile.open(g_TEMP_DIR + item.filename)
        tar.extractall(g_TEMP_DIR)
        tar.close()
    elif is_zip:
        zzip = zipfile.ZipFile(g_TEMP_DIR + item.filename)
        zzip.extractall(g_TEMP_DIR)
        zzip.close()

    if (move_problems(req) == False):
        return
    send_problems_list(req)

class UploaderHttpRequestHandler(BaseHTTPServer.BaseHTTPRequestHandler):

    def do_GET(s):
        """Respond to a GET request."""
        if (not check_url(s)):
            return

    def do_POST(s):
        """Respond to a POST request."""
        action = get_action_from_request(s)
        if (action == "auth"):
            if(check_login(s) == False):
                return
            else:
                send_problems_list(s)
                return

        if (not check_url(s)):
            return

        if (action == "load"):
            load_archive(s)
            clear_upload_temp_directory()
            return

class Ejudge():
    """ read directory with problems. need Description.xml and description.txt files """
    problems_path = g_PROBLEMS_PATH
    delimiter = '%%'

    def get_problems(self):
        problems = []
        for task_folder in os.listdir(self.problems_path):

            # A-1 / description.txt
            problem_file = os.path.join(self.problems_path, task_folder, g_USER_PROBLEM_DESCRIPTION_FILE)
            problem_file_in_ejudge_format = os.path.join(self.problems_path, task_folder, g_EJUDGE_PROBLEM_DESCRIPTION_FILE)
            try:
                open(problem_file_in_ejudge_format)
                problem_desc = open(problem_file).read()
                _, name, desk, in_ex, out_ex = [l.strip() for l in problem_desc.split(self.delimiter)]
            except:
                continue

            problem = EjudgeProblem(name)
            problems.append(problem)

        return problems

class EjudgeProblem():
    def __init__(self, _description):
        # description like 'B-1. Форматирование сток с тэгом div'
        self.integer_num = 1
        self.character = 'A'
        self.desc = "undef"
        arr = _description.split('.')
        if (len(arr[0]) > 0):
            tmp = arr[0].split('-')
            self.character = tmp[0].strip()
            self.integer_num = int(tmp[1])
        if (len(arr[1]) > 0):
            self.desc = arr[1]

    def number(self):
        return self.character + '-' + str(self.integer_num)

    def description(self):
        return self.desc

    def __cmp__(self, other):
        if self.character == other.character:
            return cmp(self.integer_num, other.integer_num)
        return cmp(self.character, other.character)


if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("--port", "-p", help="listen port", dest="port", type=int, default=8080)
    parser.add_option("--host", help="host for receved connections", dest="host", type=str, default="localhost")
    parser.add_option("--printanswer", help="print server answers", action="store_true", dest="printanswer", default=False)
    (options, args) = parser.parse_args()

    clear_upload_temp_directory()

    httpd = BaseHTTPServer.HTTPServer((options.host, options.port), UploaderHttpRequestHandler)
    fcntl.fcntl(httpd.socket, fcntl.F_SETFD, fcntl.FD_CLOEXEC)  # after Popen() need to close sockets

    try:
        print "start server on port:", options.port,", host:", options.host
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
