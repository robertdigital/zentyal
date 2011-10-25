#!/usr/bin/python
# Copyright (C) 2011 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the Lesser GNU General Public License as
# published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# Lesser GNU General Public License for more details.
#
# You should have received a copy of the Lesser GNU General Public
# License along with This program; if not, write to the
#	Free Software Foundation, Inc.,
#	59 Temple Place, Suite 330,
#	Boston, MA  02111-1307
#	USA

import sys, os

def executable_path():
    if hasattr(sys, "frozen"):
        return os.path.dirname(unicode(sys.executable, sys.getfilesystemencoding()))
    else:
        return os.path.dirname(unicode(__file__, sys.getfilesystemencoding()))

