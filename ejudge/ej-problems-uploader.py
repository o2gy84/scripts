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

from ConfigParser import SafeConfigParser


g_SESSIONS = {}
g_DEFAULT_CONFIG_PATH = "/home/ejudge/etc/"
g_DEFAULT_CONFIG_FILE = "problems_uploader.conf"
g_DEFAULT_CONFIG_SECTION = "DEFAULT"
g_DEFAULT_PASS = 'admin'

def get_md5(data):
    m = hashlib.md5()
    m.update(data)
    return m.hexdigest()

g_CONFIG = SafeConfigParser(defaults={
    'admin': 'admin',
    'password': get_md5(g_DEFAULT_PASS),
    'port': '5000',
    'host': 'localhost',
    'session_expiration_time': '300',
    'main_url': 'http://195.19.44.139:5000',
    'problems_path': '/home/ejudge/tmp/problems/',
    'upload_dir': '/home/ejudge/tmp/upload/',
    'user_problem_description_file': 'description.txt',
    'ejudge_problem_description_file': 'Description.xml',
    'description_generator_script': '/home/ejudge/inst-ejudge-scrips/generate_description.py',
    'ejudge_control_script': '/home/ejudge/inst-ejudge/bin/ejudge-control',
})

def get_config(key):
    return g_CONFIG.get(g_DEFAULT_CONFIG_SECTION, key)

def get_config_int(key):
    return g_CONFIG.getint(g_DEFAULT_CONFIG_SECTION, key)

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
    """.format(get_config('main_url'))
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

    ejudge = Ejudge()
    problems = ejudge.get_problems()
    problems.sort()
    for problem in problems:
        s.wfile.write("<tr><td> %s </td><td> %s </td><td> tests count: %s </td></tr>" % (problem.number(), problem.description(), problem.test_count(),))
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
    </div>""".format(get_config('main_url'), session_id)

    s.wfile.write(load_form)
    s.wfile.write("</body></html>")


def send_no_permission(s):
    s.send_response(403)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write("<p>permission denied</p>")
    s.wfile.write("<br><a href='{0}'>main</a>".format(get_config('main_url')))

def send_not_found(s):
    s.send_response(404)
    s.send_header("Content-type", "text/html")
    s.end_headers()
    s.wfile.write("<p>resource not found</p>")
    s.wfile.write("<br><a href='{0}'>main</a>".format(get_config('main_url')))

def send_bad_archive_response(req):
    req.send_response(400)
    req.send_header("Content-type", "text/html")
    req.end_headers()
    req.wfile.write("<p>something wrong with your archive - no test founded in archive root directory</p>")
    req.wfile.write("<br><a href='{0}'>main</a>".format(get_config('main_url')))

def send_bad_configuration(req):
    req.send_response(500)
    req.send_header("Content-type", "text/html")
    req.end_headers()
    req.wfile.write("<p>something wrong with server configuration. call to admin</p>")
    req.wfile.write("<br><a href='{0}'>main</a>".format(get_config('main_url')))

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
    
    if (query_string['login'] == get_config('admin') and get_md5(query_string['password']) == get_config('password')):
        return True

    send_no_permission(s)
    return False

def check_session_id(session_id):

    now = time.time()
    for sid, creation_time in g_SESSIONS.items():
        if (now - creation_time > get_config_int('session_expiration_time')):
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
    if not os.path.exists(get_config('upload_dir')):
        os.makedirs(get_config('upload_dir'))

    for file_object in os.listdir(get_config('upload_dir')):
        file_object_path = os.path.join(get_config('upload_dir'), file_object)
        if os.path.isfile(file_object_path):
            os.unlink(file_object_path)
        else:
            # with no ignore errors
            shutil.rmtree(file_object_path, False)

def restart_ejudge():
    """ ./ejudge-control stop && ./ejudge-control start """
    subprocess.Popen([ get_config('ejudge_control_script'), "stop"]).wait()
    time.sleep(0.1)
    subprocess.Popen([ get_config('ejudge_control_script'), "start"]).wait()

def regenerate_tests(path):
    """ convert description.txt into Description.txt, and restart ejudge """
    subprocess.call([ get_config('description_generator_script') , path])    # blocking call

def move_problems(req):
    """ check and move loaded problems """
    checked_dirs = []
    for f in os.listdir(get_config('upload_dir')):
        if (re.match('^(A|B|C|D)-\d{1,2}$', f)):
            problem_file = os.path.join(get_config('upload_dir'), f, get_config('user_problem_description_file'))
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
        original_problems_path = get_config('problems_path') + f
        if (not os.path.exists(original_problems_path)):
            shutil.move(get_config('upload_dir') + f, original_problems_path)
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

    if not os.path.exists(get_config('problems_path')):
        send_bad_configuration(req)
        return

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
    with open(get_config('upload_dir') + item.filename, 'w') as f:
        f.write(data)

    if is_tar:
        tar = tarfile.open(get_config('upload_dir') + item.filename)
        tar.extractall(get_config('upload_dir'))
        tar.close()
    elif is_zip:
        zzip = zipfile.ZipFile(get_config('upload_dir') + item.filename)
        zzip.extractall(get_config('upload_dir'))
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
    problems_path = get_config('problems_path')
    delimiter = '%%'

    def get_problems(self):
        problems = []
        if not os.path.exists(self.problems_path):
            print "[ERROR] folder with problems not exist:", self.problems_path
            return problems

        for task_folder in os.listdir(self.problems_path):

            # A-1 / description.txt
            problem_file = os.path.join(self.problems_path, task_folder, get_config('user_problem_description_file'))
            problem_file_in_ejudge_format = os.path.join(self.problems_path, task_folder, get_config('ejudge_problem_description_file'))
            try:
                open(problem_file_in_ejudge_format)
                problem_desc = open(problem_file).read()
                _, name, desk, in_ex, out_ex = [l.strip() for l in problem_desc.split(self.delimiter)]
            except:
                continue

            # count of tests
            tests_count = 0
            dir_with_test = os.path.join(self.problems_path, task_folder, 'tests')
            for test_file in os.listdir(dir_with_test):
                if (re.match('.*\.dat$', test_file)):
                    tests_count += 1

            problem = EjudgeProblem(name, tests_count)
            problems.append(problem)

        return problems

class EjudgeProblem():
    def __init__(self, _description, _tests_count):
        # description like 'B-1. Форматирование сток с тэгом div'
        self.integer_num = 1
        self.character = 'A'
        self.desc = "undef"
        self.tests_count = _tests_count
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

    def test_count(self):
        return self.tests_count

    def __cmp__(self, other):
        if self.character == other.character:
            return cmp(self.integer_num, other.integer_num)
        return cmp(self.character, other.character)

def check_default_config():
    """ write default config """
    if not os.path.exists(g_DEFAULT_CONFIG_PATH):
        os.makedirs(g_DEFAULT_CONFIG_PATH)

    conf_path = g_DEFAULT_CONFIG_PATH + g_DEFAULT_CONFIG_FILE

    if not os.path.exists(conf_path):
        g_CONFIG.write(open(conf_path, "w"))
        print "Config file was saved at:", conf_path
        print "Please specify settings and run script"
        sys.exit(1)

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("--config", "-c", help="use a specific config instead of default", dest="config", metavar="FILE")
    (options, args) = parser.parse_args()

    if (not options.config):
        check_default_config()

    g_CONFIG.read(options.config or g_DEFAULT_CONFIG_PATH + g_DEFAULT_CONFIG_FILE)

    if (get_config('password') == get_md5(g_DEFAULT_PASS)):
        print "Please set a different password in the configuration file"
        print "Use the default password is prohibited"
        sys.exit(1)

    clear_upload_temp_directory()

    httpd = BaseHTTPServer.HTTPServer((get_config('host'), get_config_int('port')), UploaderHttpRequestHandler)
    fcntl.fcntl(httpd.socket, fcntl.F_SETFD, fcntl.FD_CLOEXEC)  # after Popen() need to close sockets

    try:
        print "start server on port:", get_config('port'),", host:", get_config('host')
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
