##
## xjson - extended JSON functions for tcl
##
## JSON decoder function.
##
## This script is based on the code of “Alternative JSON” written
## found at https://wiki.tcl-lang.org/page/Alternative+JSON
##
## Written Andrew Michael Goth <andrew.m.goth@gmail.com>
## Reworked by Jan Kandziora <jjj@gmx.de>
##
## Andrew had put his code in the public domain.
##
## (C)2021 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Decode data from the JSON format to xjson's internal format.
proc ::xjson::decode {json {indexVar {}}} {
	## Link to the caller's index variable.
	if {$indexVar ne {}} {
		upvar 1 $indexVar index
	}

	## By default, start decoding at the start of the input.
	if {![info exists index]} {
		set index 0
	}

	## Skip leading whitespace. Return empty at end of input.
	if {![regexp -indices -start $index {[^\t\n\r ]} $json range]} {
		return
	}
	set index [lindex $range 0]

	## The first character determines the JSON element type.
	switch -- [string index $json $index] {
		"\"" {
			## JSON strings start with double quote.
			set type string

			## The value is the text between matching double quotes.
			if {![regexp -indices -start $index {\A\"((?:[^"\\]|\\.)*)\"} $json range sub]} {#"
				return -code error -errorcode {XJSON DECODE INVALID_STRING} \
					[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
						"strings must end with a close quote."]
			}

			## Process all backslash substitutions in the value.
			set value [_decodeString [string range $json {*}$sub]]
		}
		"\{" - "\[" {
			## JSON objects/arrays start with open brace/bracket.
			if {[string index $json $index] eq "\{"} {
				set type object
				set endRe {\A[\t\n\r ]*\}}
				set charName brace
			} else {
				set type array
				set endRe {\A[\t\n\r ]*\]}
				set charName bracket
			}
			set value {}
			incr index

			## Loop until close brace/bracket is encountered.
			while {![regexp -indices -start $index $endRe $json range]} {
				## Each element other than the first is preceded by comma.
				if {[llength $value]} {
					if {![regexp -indices -start $index {\A[\t\n\r ]*,} $json range]} {
						return -code error -errorcode [list XJSON DECODE INVALID_[string toupper $type]] \
							[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
								$type "s must end with a close " $charName "."]
					}
					set index [expr {[lindex $range 1]+1}]
				}

				## For objects, get key and confirm it is followed by colon.
				if {$type eq "object"} {
					set key [decode $json index]
					if {![llength $key]} {
						return -code error -errorcode {XJSON DECODE INVALID_OBJECT} \
							[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
								"objects must end with a close " $charName "."]
					} elseif {[lindex $key 0] ne "string"} {
						return -code error -errorcode {XJSON DECODE INVALID_OBJECT} \
							[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
								"object key is a " [lindex $key 0] ", but they must be strings."]
					} elseif {![regexp -indices -start $index {\A[\t\n\r ]*:} $json range]} {
						return -code error -errorcode {XJSON DECODE INVALID_OBJECT} \
							[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
								"object key is not followed by a colon."]
					}
					set index [expr {[lindex $range 1]+1}]
					lappend value [lindex $key 1]
				}

				## Get element value.
				lappend value [decode $json index]
			}
		}
		"t" - "f" - "n" {
			## JSON literals are true, false, and null.
			set type literal
			if {![regexp -indices -start $index {(?:true|false|null)\M} $json range]} {
				return -code error -errorcode {XJSON DECODE INVALID_LITERAL} \
					[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
						"valid literals are true, false, and null."]
			}
			set value [string range $json {*}$range]
		}
		"-" - "+" - "0" - "1" - "2" - "3" - "4" - "5" - "6" - "7" - "8" - "9" - "." {
			## JSON numbers are integers or real numbers.
			set type number
			if {![regexp -indices -start $index -- {\A-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][-+]?\d+)?\M} $json range]} {
				return -code error -errorcode {XJSON DECODE INVALID_NUMBER} \
					[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
						"not a valid number."]
			}
			set value [_decodeNumber [string range $json {*}$range]]
		}
		default {
			## JSON allows only the above-listed types.
			return -code error -errorcode {XJSON DECODE INVALID_LITERAL} \
				[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
					"valid literals are true, false, and null."]
		}
	}

	## Continue decoding after the last character matched above.
	set index [expr {[lindex $range 1]+1}]

	## When performing a full decode, ensure only whitespace appears at end.
	if {$indexVar eq {} && [regexp -start $index {[^\t\n\r\ ]} $json]} {
		return -code error -errorcode {XJSON DECODE JUNK_AT_END} \
			[string cat "invalid JSON ..." [string trim [string range $json $index-20 $index+60]] "... at index " $index ": " \
				"junk at end of JSON."]
	}

	## Return the type and value.
	list $type $value
}


## Decode a string.
proc ::xjson::_decodeString {s} {
	set start 0
	while {[regexp -indices -start $start {\\u[[:xdigit:]]{4}|\\[^u]} $s sub]} {
		set char [string index $s [expr {[lindex $sub 0]+1}]]
		switch -- $char {
			u {set char [subst [string range $s {*}$sub]]}
			b {set char \b} f {set char \f} n {set char \n}
			r {set char \r} t {set char \t}
		}
		set s [string replace $s {*}$sub $char]
		set start [expr {[lindex $sub 0]+1}]
	}

	return $s
}


## Decode a number
proc ::xjson::_decodeNumber {n} {
	expr {$n}
}
