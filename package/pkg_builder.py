#!/usr/bin/env python

import os, sys, shutil
import subprocess

USAGE = """Usage: {0} type
Types:
    - rpm
    - deb""".format(sys.argv[0])

def check_args(arg):
    if len(arg) == 1:
        print USAGE
        sys.exit()

def pkg_type(arg):
    if arg == 'rpm':
        return 'rpm'
    if arg == 'deb':
        return 'deb'
    print USAGE
    sys.exit()

check_args(sys.argv[0:])

PREFIX          = 'usr'
INCLUDE_PREFIX  = 'include'
LIB_PREFIX      = 'lib64'
PKG_TYPE        = pkg_type(sys.argv[1])

# copy into PREFIX/INCLUDE_PREFIX
INCLUDE_FILES   = ['3', '4', 'onefile/foo', 'twofile/innnerdir/bar', ]
INCLUDE_DIRS    = ['111', ]

# copy into PREFIX/LIB_PREFIX
LIBS            = ['file.so', 'onefile/foo', ]

# copy into PREFIX
FILES           = ['file.so_link', 'onefile/foo', ]
DIRS            = ['dir1', ]

# dirs you want to be removed after erasing package
#PKG_DIRS        = ['/usr/include/caffe/', ]
PKG_DIRS        = []

TYPE_FROM       = 'dir'
TYPE_TO         = PKG_TYPE
DIST            = 'el7'
NAME            = 'mru-caffe'
DESCRIPTION     = 'Caffe'
PKG_DEPS        = ['glog', 'gflags', 'mru-protobuf', 'lmdb', 'leveldb', 'hdf5', 'snappy', 'openblas', 'mru-cudnn', ]
AFTER_INSTALL   = 'ldconfig.sh'
AFTER_REMOVE    = 'ldconfig.sh'


buildroot = '.buildroot/'
os.system("rm -rf " + buildroot + " && mkdir " + buildroot)

buildroot_prefix = os.path.join(buildroot, PREFIX)
os.makedirs(buildroot_prefix)
os.makedirs(os.path.join(buildroot_prefix, INCLUDE_PREFIX))
os.makedirs(os.path.join(buildroot_prefix, LIB_PREFIX))

def file_exist_or_die(path):
    if not os.path.exists(path):
        print "ERROR! file doesn't exist: ", path
        sys.exit()

def create_dirs_if_needed(prefix, name):
    dirname = os.path.dirname(name)
    if len(dirname) > 0:
        os.makedirs(os.path.join(prefix, dirname))

for d in INCLUDE_DIRS:
    file_exist_or_die(d)
    os.system("cp -rv " + d + " " + os.path.join(buildroot_prefix, INCLUDE_PREFIX, d))

for f in INCLUDE_FILES:
    file_exist_or_die(f)
    create_dirs_if_needed(os.path.join(buildroot_prefix, INCLUDE_PREFIX), f)
    os.system("cp -av " + f + " " + os.path.join(buildroot_prefix, INCLUDE_PREFIX, f))

for l in LIBS:
    file_exist_or_die(l)
    create_dirs_if_needed(os.path.join(buildroot_prefix, LIB_PREFIX), l)
    os.system("cp -av " + l + " " + os.path.join(buildroot_prefix, LIB_PREFIX, l))

for f in FILES:
    file_exist_or_die(f)
    create_dirs_if_needed(buildroot_prefix, f)
    os.system("cp -av " + f + " " + os.path.join(buildroot_prefix, f))

for d in DIRS:
    file_exist_or_die(d)
    os.system("cp -rv " + d + " " + os.path.join(buildroot_prefix, d))

cur_date = subprocess.check_output('date +%Y%m%d.%H%M', shell=True)

cmd  = "fpm --force -s " + TYPE_FROM + " -t " + TYPE_TO + " -C " + buildroot + " --rpm-dist " + DIST
cmd += " --name " + NAME + " --version " + cur_date.strip() + " --iteration 1"
cmd += " --description \"" + DESCRIPTION + "\" -a native"

for d in PKG_DEPS:
    cmd += " -d " + d

for d in PKG_DIRS:
    path = buildroot + d
    file_exist_or_die(path)
    cmd += " --directories " + d

cmd += " --after-install " + AFTER_INSTALL + " --after-remove " + AFTER_REMOVE
cmd += " ."

print "CMD: ", cmd
os.system(cmd)

shutil.rmtree(buildroot)
