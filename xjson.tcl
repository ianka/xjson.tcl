##
## xjson - extended JSON functions for tcl
##
## Basic definitions for the decode.tcl, encode.tcl, and collector.tcl files.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2021 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## This software requires Tcl 8.6 or higher, as well as
## itcl 4.0 or higher, which is included in the Tcl 8.6 distribution.
package require Tcl 8.6-
package require itcl 4.0-

## Create a namespace for all xjson functions.
namespace eval ::xjson {}
