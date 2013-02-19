#!/usr/bin/env python
# -*- coding: utf-8 -*-
#####################################################################
#
# ascii_art_maker.py
#
# Makes ascii art out of an image on the internet and prints it to
# stdout.
#
# @author Isis Lovecruft, 0x2cdb8b35
# @version 1.0.0
#
# Taken from http://jwilk.net/software/python-aalib
#####################################################################

import aalib
import Image
import urllib2
from PIL import ImageOps
from optparse import OptionParser
from cStringIO import StringIO

def make_options():
    return options, args

def asciify(image_url, width, height, invert):
    """
    Takes an image from the interwebs and turns it into ascii art.

    FTFW like wut.
    """
    width = ((width * 7) // 4)
    screen = aalib.AsciiScreen(width=width, height=height)
    grabbed_image = urllib2.urlopen(image_url).read()
    fp = StringIO(grabbed_image)
    resized = Image.open(fp).convert('L').resize(screen.virtual_size)

    if invert:
        image = ImageOps.invert(resized)
    else:
        image = resized

    screen.put_image((0, 0), image)
    print screen.render()

if __name__ == "__main__":

    usage = "Usage: %prog [options] <imageURL>"
    parser = OptionParser(usage=usage)
    parser.add_option("-H", "--height", type="int", dest="height",
                      help="The height, in number of characters, that the image should be printed with",
                      metavar="HEIGHT")
    parser.add_option("-W", "--width", type="int", dest="width",
                      help="The width, in number of characters, that the image should be printed with",
                      metavar="WIDTH")
    parser.add_option("-I", "--invert", action="store_true", dest="invert",
                      help="Invert the image's colours")
    (options, args) = parser.parse_args()
    
    if not options.width:
        width = 80
    else:
        width = options.width

    if not options.height:
        height = 40
    else:
        height = options.width

    if not options.invert:
        invert = False
    else:
        invert = True

    if len(args) != 1:
        parser.print_help()
    else:
        asciify(args[0], width, height, invert)
