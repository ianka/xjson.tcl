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
					[format $format [string cat [string map $::xjson::stringmap $key] "\":"]] \
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
			## Append recoded string.
			append result "\"" [string map $::xjson::stringmap $value] "\""
		}
		"number" {
			## Attempt to normalize the number to comply with the JSON standard.
			regsub {^[\f\n\r\t\v ]+} $value  {}      rvalue ;# Strip leading space.
			regsub {[\f\n\r\t\v ]+$} $rvalue {}      rvalue ;# Strip trailing space.
			regsub {^\+(?=[\d.])}    $rvalue {}      rvalue ;# Strip leading plus.
			regsub {^(-?)0+(?=\d)}   $rvalue {\1}    rvalue ;# Strip leading zeroes.
			regsub {(\.\d*[1-9])0+}  $rvalue {\1}    rvalue ;# Strip trailing zeroes.
			regsub {E}               $rvalue {e}     rvalue ;# Normalize exponent, 1.
			regsub {^(-?\d+)e}       $rvalue {\1.0e} rvalue ;# Normalize exponent, 2.
			regsub {\.e}             $rvalue {.0e}   rvalue ;# Normalize exponent, 3.
			regsub {e(\d)}           $rvalue {e+\1}  rvalue ;# Normalize exponent, 4.
			regsub {(^|-)\.(?=\d)}   $rvalue {\10.}  rvalue ;# Prefix leading dot.
			regsub {(\d)\.(?=\D|$)}  $rvalue {\1.0}  rvalue ;# Suffix trailing dot.
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
				[string cat "invalid JSON type \"" $type "\": must be array, object, string, number, " \
					"literal, encoded, decoded."]
		}
	}

	## Return result.
	return $result
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
