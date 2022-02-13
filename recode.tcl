##
## xjson - extended JSON functions for tcl
##
## JSON recode function.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2022 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Get rid of the "encoded" and "decoded" types that aren't understood
## by any function but this one and ::xjson::encode. Also recode other
## values as if they had been decoded from JSON.
proc ::xjson::recode {data} {
	## Extract type and value from data argument.
	if {[llength $data] != 2} {
		return -code error -errorcode {XJSON RECODE DATA_FORMAT} \
			"invalid decoded JSON data: must be a two-element list consisting of type and value"
	}
	lassign $data type value

	## Perform type-specific recoding.
	switch -- $type {
		"array" {
			## Recode array values.
			set result [list $type [lmap v $value {recode $v}]]
		}
		"object" {
			## Recode object fields.
			set result [list $type [concat {*}[lmap {k v} $value {list [_recodeString $k] [recode $v]}]]]
		}
		"string" {
			## Recode string.
			set result [list $type [_recodeString $value]]
		}
		"number" {
			## Attempt to normalize the number to comply with the JSON standard.
			set rvalue [_encodeNumber $value]
			if {![regexp {^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][-+]?\d+)?$} $rvalue]} {
				return -code error -errorcode {XJSON RECODE INVALID_NUMBER} \
					[string cat "invalid JSON number \"" $value "\": see https://tools.ietf.org/html/rfc7159#section-6 ."]
			}

			## Return recoded number.
			set result [list $type [_decodeNumber $rvalue]]
		}
		"literal" {
			## Recode literal.
			## The only valid literals are false, null, and true.
			if {$value ni {false null true}} {
				return -code error -errorcode {XJSON RECODE INVALID_LITERAL} \
					[string cat "invalid JSON literal \"" $value "\": must be false, null, or true."]
			}

			## Return data.
			set result $data
		}
		"encoded" {
			## Decode encoded data.
			if {[catch {decode $value} result]} {
				## Escalate the error.
				return -code error -errorcode [lreplace $::errorCode 1 1 RECODE] -errorinfo $::errorInfo $result
			}
		}
 		"decoded" {
			## Recode decoded data.
			if {[catch {decode [encode $value 0 {}]} result]} {
				## Escalate the error.
				return -code error -errorcode [lreplace $::errorCode 1 1 RECODE] -errorinfo $::errorInfo $result
			}
		}
		default {
			## Invalid type.
			return -code error -errorcode {XJSON RECODE UNKNOWN_TYPE} \
				[string cat "invalid JSON type \"" $type "\": must be array, object, string, number, literal, encoded, decoded."]
		}
	}

	## Return result.
	return $result
}


## Recode a string.
proc ::xjson::_recodeString {s} {
	_decodeString [_encodeString $s]
}
