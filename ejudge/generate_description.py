#!/usr/bin/env python 
# -*- coding: utf-8 -*- 

import os
import sys

TEMPLATE = '''<?xml version="1.0" encoding="utf-8" ?>
<problem
    package = "ru.ejudge.bmstu_contest"
    id = "{problem_id}"
    type = "standard">
    <statement language="ru_RU">
    <title>Задача {problem_name}</title>
    <description>
    <p>{problem_desc}</p>
    </description>
    </statement>
    <examples>
        <example>
            <input>{input}</input>
            <output>{output}</output>
        </example>
    </examples>
</problem>'''

user_description_file = 'description.txt'
delimiter = '%%'
result_description_file = 'Description.xml'

def generate_description(path):

    if not path.endswith('/'):
        path += '/'

    description_txt_path = os.path.join(path, user_description_file)
    try:
        description = open(description_txt_path).read()
        _, name, desc, in_example, out_example = [l.strip() for l in description.split(delimiter)]
    except:
        print "no correct", description_txt_path, "founded in:", path
        return False

    print "found description: ", description_txt_path, "(name: ", name, ")"
    tmp = path.split('/')
    problem_id =  tmp[len(tmp) - 2]     # like 'A-6'

    xml = TEMPLATE.format(problem_id = problem_id, problem_name = name, problem_desc = desc, input = in_example, output = out_example)
    save_path = os.path.join(path, result_description_file)
   
    print "save file: ", save_path
    open(save_path, 'w').write(xml)
    return True

try:
    path_to_problems = sys.argv[1]
except:
    print "need directory with tests"
    sys.exit()

print "Process directory: ", path_to_problems

# first looking at the description.txt in a given directory
if (generate_description(path_to_problems) == True):
    sys.exit()

# second - try subdirs
for folder in os.listdir(path_to_problems):
    generate_description(os.path.join(path_to_problems, folder))
