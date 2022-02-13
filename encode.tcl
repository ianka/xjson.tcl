##
## xjson - extended JSON functions for tcl
##
## JSON encoder function.
##
## This script is based on the code of “Alternative JSON” written
## found at https://wiki.tcl-lang.org/page/Alternative+JSON
##
## Written Andrew Michael Goth <andrew.m.goth@gmail.com>
## Reworked by Jan Kandziora <jjj@gmx.de>
## Jan also added a pretty printer for the JSON output.
##
## Andrew had put his code in the public domain.
##
## (C)2021 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Encode and pretty print data in the JSON format.
proc ::xjson::encode {data {indent 0} {tabulator "\t"} {nest 0}} {
	## Extract type and value from data argument.
	if {[llength $data] != 2} {
		return -code error -errorcode {XJSON ENCODE DATA_FORMAT} \
			"invalid decoded JSON data: must be a two-element list consisting of type and value"
	}
	lassign $data type value

	## Indent if not nested.
	if {$nest == 0} {
		set result [string repeat $tabulator $indent]
	}

	## Perform type-specific JSON encoding.
	switch -- $type {
		"array" {
			## Recursively encode each array element.
			## Format the lines of the array.
			set lines {}
			foreach element $value {
				lappend lines [string cat [string repeat $tabulator [expr {$indent+1}]] [encode $element [expr {$indent+1}] $tabulator [expr {$nest+1}]]]
			}

			## Append the array.
			if {$tabulator ne {} && $lines ne {}} {
				## Pretty printed output.
				append result "\[\n" [join $lines ",\n"] "\n" [string repeat $tabulator $indent] "\]"
			} else {
				## Plain output.
				append result "\[" [join $lines ","] "\]"
			}
		}
		"object" {
			## Recursively encode each object key and element.
			## Get object key format.
			if {$tabulator ne {}} {
				## Pretty printed output.
				## Get the length of the longest key string for value indentation.
				set keylength [::tcl::mathfunc::max 0 {*}[lmap {key element} $value {string length $key}]]
				incr keylength +3
				set format "%-${keylength}s"
			} else {
				## Plain output.
				set format "%s"
			}

			## Format the lines of the object.
			set lines {}
			dict for {key element} $value {
				lappend lines [string cat [string repeat $tabulator [expr {$indent+1}]] "\"" \
					[format $format [string cat [_encodeString $key] "\":"]] \
					[encode $element [expr {$indent+1}] $tabulator [expr {$nest+1}]]]
			}

			## Append the object.
			if {$tabulator ne {} && $lines ne {}} {
				## Pretty printed output
				append result "{\n" [join $lines ",\n"] "\n" [string repeat $tabulator $indent] "}"
			} else {
				## Plain output.
				append result "{" [join $lines ","] "}"
			}
		}
		"string" {
			## Append encoded string.
			append result "\"" [_encodeString $value] "\""
		}
		"number" {
			## Attempt to normalize the number to comply with the JSON standard.
			set rvalue [_encodeNumber $value]
			if {![regexp {^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][-+]?\d+)?$} $rvalue]} {
				return -code error -errorcode {XJSON ENCODE INVALID_NUMBER} \
					[string cat "invalid JSON number \"" $value "\": see https://tools.ietf.org/html/rfc7159#section-6 ."]
			}

			## Append result value.
			append result $rvalue
		}
		"literal" {
			## The only valid literals are false, null, and true.
			if {$value ni {false null true}} {
				return -code error -errorcode {XJSON ENCODE INVALID_LITERAL} \
					[string cat "invalid JSON literal \"" $value "\": must be false, null, or true."]
			}

			## Append value.
			append result $value
		}
		"encoded" {
			## Append raw data. The caller must supply correctly formatted JSON.
			append result $value
		}
		"decoded" {
			## Append encoded nested decoded data.
			append result [encode $value $indent $tabulator [expr {$nest+1}]]
		}
		default {
			## Invalid type.
			return -code error -errorcode {XJSON ENCODE UNKNOWN_TYPE} \
				[string cat "invalid JSON type \"" $type "\": must be array, object, string, number, literal, encoded, decoded."]
		}
	}

	## Return result.
	return $result
}


## Encode a string with the mapping.
proc ::xjson::_encodeString {s} {
	string map $::xjson::stringmap $s
}


## Encode a number to comply with the JSON standard.
proc ::xjson::_encodeNumber {n} {
	regsub {^[\f\n\r\t\v ]+} $n {}      n ;# Strip leading space.
	regsub {[\f\n\r\t\v ]+$} $n {}      n ;# Strip trailing space.
	regsub {^\+(?=[\d.])}    $n {}      n ;# Strip leading plus.
	regsub {^(-?)0+(?=\d)}   $n {\1}    n ;# Strip leading zeroes.
	regsub {(\.\d*[1-9])0+}  $n {\1}    n ;# Strip trailing zeroes.
	regsub {E}               $n {e}     n ;# Normalize exponent, 1.
	regsub {^(-?\d+)e}       $n {\1.0e} n ;# Normalize exponent, 2.
	regsub {\.e}             $n {.0e}   n ;# Normalize exponent, 3.
	regsub {e(\d)}           $n {e+\1}  n ;# Normalize exponent, 4.
	regsub {(^|-)\.(?=\d)}   $n {\10.}  n ;# Prefix leading dot.
	regsub {(\d)\.(?=\D|$)}  $n {\1.0}  n ;# Suffix trailing dot.
	return $n
}


## Populate string recoding map.
namespace eval ::xjson {
	variable stringmap [dict create \\ \\\\ \" \\\"]
	for {set i 0} {$i<32} {incr i} {
		dict set stringmap [binary format "c" $i] [format "\\u%04x" $i]
	}
	dict set stringmap \b \\b
	dict set stringmap \f \\f
	dict set stringmap \n \\n
	dict set stringmap \r \\r
	dict set stringmap \t \\t
}
