#!/usr/bin/python
import re
import urllib2
import random
import subprocess
import os
from os.path import expanduser

homeFolder = expanduser("~")
picturesFolder = "{0}/Pictures/".format(homeFolder)

url = "http://some.url.here/"
path = "wallpapers/"
pattern = '<A HREF="/%s.*?">(.*?)</A>' % path
file_list = []

response = urllib2.urlopen(url+path).read()

for filename in re.findall(pattern, response):
    file_list.append(filename)

wpFileName = random.choice(file_list)
wpURL = url+path+wpFileName

f = open(picturesFolder+wpFileName, 'w')
f.write(urllib2.urlopen(wpURL).read())
f.close()

script = '''tell application "Finder"
       set desktop picture to POSIX file "{0}/{1}"
end tell
'''.format(picturesFolder,wpFileName)

proc = subprocess.Popen(['osascript', '-'],
                        stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE)
stdout_output = proc.communicate(script)[0]
print stdout_output

print "set wallpaper to {0}{1}".format(picturesFolder,wpFileName)

