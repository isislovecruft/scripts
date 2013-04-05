#!/usr/bin/env python
# -*- coding: utf-8 -*-
###############################################################################
#
# local-http-server.py
# --------------------
# Serve a directory on the given address and port. Defaults to 127.0.0.1:8080.
# 
# @authors: Isis Agora Lovecruft 0x2cdb8b35
# @version: 0.0.1
# @date: 25 December 2012
# @license: WTFPL
# @copyright: 2012 Isis Lovecruft
###############################################################################

import os
import sys
import BaseHTTPServer

from ipaddr import IPAddress
from optparse import OptionParser
from SimpleHTTPServer import SimpleHTTPRequestHandler


HandlerClass = SimpleHTTPRequestHandler
ServerClass = BaseHTTPServer.HTTPServer
Protocol = "HTTP/1.0"

HandlerClass.protocol_version = Protocol

parser = OptionParser()
parser.add_option('-p', '--port', dest='port', default=8080,
                  help="Local port to listen on")
parser.add_option('-a', '--address', dest='addr', default='127.0.0.1',
                  help="Local IP address to listen on")
parser.add_option('-d', '--dir', dest='dir', default='.',
                  help='[Not Implemented] Local directory to use as root directory of webserver')


if __name__ == "__main__":
    if len(sys.argv[1:]) <= 0:
        parser.print_help()
        sys.exit(1)
    else:
        (options, args) = parser.parse_args()

        if options.dir:
            print "WARNING! The local directory option is not implemented."

        try:
           IPAddress(options.addr)
        except ValueError, ve:
            print ve.message
            sys.exit(1)
        else:
            addr = options.addr

        try:
            port = int(options.port)
            if port <= 1024 and os.getuid() != 0:
                print "Server must be started as root to use port %d" % port
                sys.exit(1)
        except Exception, ex:
            print ex.message
            sys.exit(1)

    httpd = ServerClass((addr, port), HandlerClass)
    sa = httpd.socket.getsockname()
    
    print "Serving HTTP on", sa[0], "port", sa[1], "..."
    try:
        httpd.serve_forever()
    except KeyboardInterrupt, ki:
        print "\nStopping server...\nExiting...\n"
        sys.exit(0)
