##
## xjson - extended JSON functions for tcl
##
## Basic definitions for the other source files.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2021 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## This software requires Tcl 8.6 or higher.
package require Tcl 8.6-

## ::xjson::makeCollectorClass and ::xjson::makeComposerClass need itcl 4.0 or higher.
## That's included in the Tcl 8.6 distribution.
package require itcl 4.0-

## :xjson::diff requires Tcllib's struct::set and struct::list.
## That's included in the Tcl 8.6 distribution.
package require struct::set
package require struct::list

## Create a namespace for all xjson functions.
namespace eval ::xjson {}
