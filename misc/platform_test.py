#!/usr/bin/env python

import platform

print platform.machine();
print platform.architecture();
print platform.platform();
print platform.processor();
print platform.python_build();
print platform.python_compiler();
print platform.system();
print platform.libc_ver();
print platform.linux_distribution();
print platform.dist();

uname = platform.uname();
pc_name = uname[1];

print uname;
print "pc: " + pc_name;

if pc_name.find("win31.dev") != -1:
    print "is win31.dev :)";
else:
    print "not win31.dev  :(";

