#!/bin/bash

if [ -z $1 ]; then
    echo "Enter url"
    exit 1
fi

echo "grab: $1"

user="imap.test.13@gmail.com"
pass="imaptest13"

youtube-dl --extract-audio --audio-format mp3 -u $user -p $pass $1 --playlist-start $2

