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
INCLUDE_FILES   = [ ]
INCLUDE_DIRS    = {'../include/caffe': 'caffe', }
INCLUDE_MAP     = {'111/222/proto/caffe_proto.h': 'caffe/proto/caffe_proto.h', }

# copy into PREFIX/LIB_PREFIX
LIBS            = [ ]
LIBS_MAP        = {'build/caffe.so.1': 'caffe.so.1', 'build/caffe.so': 'caffe.so', }

# copy into PREFIX
FILES           = [ ]
DIRS            = [ ]

# dirs you want to be removed after erasing package
PKG_DIRS        = [ ]
PKG_DEV_DIRS    = ['/usr/include/caffe/', ]

TYPE_FROM       = 'dir'
TYPE_TO         = PKG_TYPE
DIST            = 'el7'
NAME            = 'mru-caffe'
DESCRIPTION     = 'Caffe'
PKG_DEPS        = ['glog', 'gflags', 'mru-protobuf', 'lmdb', 'leveldb', 'hdf5', 'snappy', 'openblas', 'mru-cudnn', ]
AFTER_INSTALL   = 'ldconfig.sh'
AFTER_REMOVE    = 'ldconfig.sh'

buildroot = '.buildroot/'
buildroot_prefix = os.path.join(buildroot, PREFIX)
cur_date = subprocess.check_output('date +%Y%m%d.%H%M', shell=True)

def file_exist_or_die(path):
    if not os.path.exists(path):
        print "ERROR! file doesn't exist: ", path
        sys.exit()

def create_dirs_if_needed(prefix, name):
    dirname = os.path.dirname(name)
    if len(dirname) > 0:
        try:
            os.makedirs(os.path.join(prefix, dirname))
        except:
            pass

def build_package(name):
    os.system("rm -rf " + buildroot + " && mkdir " + buildroot)
    os.makedirs(buildroot_prefix)
    os.makedirs(os.path.join(buildroot_prefix, LIB_PREFIX))

    for l in LIBS:
        file_exist_or_die(l)
        create_dirs_if_needed(os.path.join(buildroot_prefix, LIB_PREFIX), l)
        os.system("cp -av " + l + " " + os.path.join(buildroot_prefix, LIB_PREFIX, l))

    for l in LIBS_MAP:
        file_exist_or_die(l)
        new_l = LIBS_MAP[l]
        create_dirs_if_needed(os.path.join(buildroot_prefix, LIB_PREFIX), new_l)
        os.system("cp -av " + l + " " + os.path.join(buildroot_prefix, LIB_PREFIX, new_l))

    for f in FILES:
        file_exist_or_die(f)
        create_dirs_if_needed(buildroot_prefix, f)
        os.system("cp -av " + f + " " + os.path.join(buildroot_prefix, f))

    for d in DIRS:
        file_exist_or_die(d)
        os.system("cp -rv " + d + " " + os.path.join(buildroot_prefix, d))

    cmd  = "fpm --force -s " + TYPE_FROM + " -t " + TYPE_TO + " -C " + buildroot + " --rpm-dist " + DIST
    cmd += " --name " + name + " --version " + cur_date.strip() + " --iteration 1"
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

def build_dev_package(name):
    os.system("rm -rf " + buildroot + " && mkdir " + buildroot)
    os.makedirs(buildroot_prefix)
    os.makedirs(os.path.join(buildroot_prefix, INCLUDE_PREFIX))

    for d in INCLUDE_DIRS:
        file_exist_or_die(d)
        new_d = INCLUDE_DIRS[d]
        create_dirs_if_needed(os.path.join(buildroot_prefix, INCLUDE_PREFIX), new_d)
        os.system("cp -rv " + d + " " + os.path.join(buildroot_prefix, INCLUDE_PREFIX, new_d))

    for f in INCLUDE_FILES:
        file_exist_or_die(f)
        create_dirs_if_needed(os.path.join(buildroot_prefix, INCLUDE_PREFIX), f)
        os.system("cp -av " + f + " " + os.path.join(buildroot_prefix, INCLUDE_PREFIX, f))

    for f in INCLUDE_MAP:
        file_exist_or_die(f)
        new_f = INCLUDE_MAP[f]
        create_dirs_if_needed(os.path.join(buildroot_prefix, INCLUDE_PREFIX), new_f)
        os.system("cp -av " + f + " " + os.path.join(buildroot_prefix, INCLUDE_PREFIX, new_f))

    cmd  = "fpm --force -s " + TYPE_FROM + " -t " + TYPE_TO + " -C " + buildroot + " --rpm-dist " + DIST
    cmd += " --name " + name + " --version " + cur_date.strip() + " --iteration 1"
    cmd += " --description \"Headers for " + NAME + "\" -a native"
    cmd += " -d \"" + NAME + " = " + cur_date.strip() + "\""

    for d in PKG_DEV_DIRS:
        path = buildroot + d
        file_exist_or_die(path)
        cmd += " --directories " + d

    cmd += " ."

    print "CMD: ", cmd
    os.system(cmd)


build_package(NAME)
build_dev_package(NAME + '-devel')
shutil.rmtree(buildroot)

