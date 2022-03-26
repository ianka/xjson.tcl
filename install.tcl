#!/usr/bin/env tclsh

## Tcl 8.6 is required for the library. We can as well require it for the installer.
package require Tcl 8.6-

## Help.
if {$argc != 2} {
	## Sort the list of tcl library dirs in $auto_path by length.
	set tdirs [lmap ldir [lsort -index 0 -integer -increasing [lmap dir $auto_path {list [string length $dir] $dir}]] {lindex $ldir 1}]

	## Recommend a tcl_libraries_dir.
	set trec [lindex $tdirs 0]
	foreach dir $tdirs {
		if {[string match "*/share/tcl*" $dir]} {
			set trec $dir
			break
		}
		if {[string match "*/tcl*" $dir]} {
			set trec $dir
		}
	}

	## Get manpath.
	set man_path [exec man -w]

	## Sort the list of man dirs in $man_path by length.
	set mdirs [lmap ldir [lsort -index 0 -integer -increasing [lmap dir [split $man_path :] {list [string length $dir] $dir}]] {lindex $ldir 1}]

	## Recommend a man_dir.
	set mrec [lindex $mdirs 0]
	foreach dir $mdirs {
		if {[string match "*/share/*" $dir]} {
			set mrec $dir
			break
		}
	}

	## Print help.
	puts stderr [string cat \
		"USAGE: ./install.tcl <tcl_libraries_dir> <man_dir>\n" \
		"Note: The Tcl \$auto_path variable on your system is set to\n\t" \
		[join $tdirs "\n\t"] "\n" \
		"Those are great candidates for <tcl_libraries_dir>.\n" \
		"The man path on your system is set to\n\t" \
		[join $mdirs "\n\t"] "\n" \
		"Those are great candidates for <man_dir>.\n" \
		"I recommend\n" \
		"./install.tcl " $trec " " $mrec]
	exit 1
}


## Create library directory.
file mkdir [file join [lindex $argv 0] "xjson1.5"]

## Copy library files.
foreach fname {
	builtinCollectingMethods.tcl
	builtinComposingMethods.tcl
	decode.tcl
	diff.tcl
	encode.tcl
	makeCollectorClass.tcl
	makeComposerClass.tcl
	patch.tcl
	pkgIndex.tcl
	recode.tcl
	utilities.tcl
	xjson.tcl
} {
	file copy -force $fname [file join [lindex $argv 0] "xjson1.5"]
}

## Copy manpage.
file copy -force "xjson.n" [file join [lindex $argv 1] "mann"]

