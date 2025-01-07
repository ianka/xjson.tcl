##
## xjson - extended JSON functions for tcl
##
## JSON patch function.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2022 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Patch a JSON tree.
proc ::xjson::patch {decodedJson patch} {
	## Only test data if not empty.
	if {$decodedJson ne {}} {
		## Check list lengths.
		if {[llength $decodedJson] != 2} {
			return -code error -errorcode {XJSON PATCH DATA_FORMAT} \
				"invalid decoded JSON data: must be two two-element lists consisting of type and value, or empty."
		}

		## Check type.
		if {[lindex $decodedJson 0] ni {literal number string object array}} {
			 ## Invalid type.
			return -code error -errorcode {XJSON PATCH UNKNOWN_TYPE} \
				[string cat "invalid JSON type \"" [lindex $decodedJson 0] "\": must be array, object, string, number, literal." ]
		}
	}

	## Return original data if the patch is empty.
	if {$patch eq {}} {
		return $decodedJson
	}

	## Extract type and value from decodedJson argument.
	lassign $decodedJson type value

	## Extract patch action and parameters.
	lassign $patch patchAction patchParam1 patchParam2

	## Switch by patch action.
	switch -- $patchAction {
		"replace" {
			## Fail if the old patch data does not match the original data.
			if {$patchParam1 ne $decodedJson} {
				return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
					[string cat "patch " $patch " does not match data " $decodedJson "." \
						"The data to be patched does not match."]
			}

			## Return new data from patch.
			return $patchParam2
		}
		"keys" {
			## Fail if the data isn't an object.
			if {$type ne "object"} {
				return -code error -errorcode {XJSON PATCH TYPE_MISMATCH} \
					[string cat "patch " $patch " does not match data " $decodedJson "." \
						"It isn't an object."]
			}

			## Walk through the patch data.
			dict for {key element} $patchParam1 {
				## Extract element action and parameter.
				lassign $element elementAction elementParam

				## Switch by element action.
				switch -- $elementAction {
					"delete" {
						## Fail if the key is unknown in the data dict.
						if {![dict exists $value $key]} {
							return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
								[string cat "patch " $patch " does not match data " $decodedJson "." \
									"Cannot delete key \"" $key "\". It's not present."]
						}

						## Fail if the element parameter does not match the original data.
						if {$elementParam ne [dict get $value $key]} {
							return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
								[string cat "patch " $patch " does not match data " $decodedJson "." \
									"Cannot delete key \"" $key "\". The data to be patched does not match."]
						}

						## Delete key.
						dict unset value $key
					}
					"add" {
						## Fail if the key is already known in the data dict.
						if {[dict exists $value $key]} {
							return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
								[string cat "patch " $patch " does not match data " $decodedJson "." \
									"Cannot add key \"" $key "\". It's already present."]
						}

						## Add key.
						dict set value $key $elementParam
					}
					default {
						## Fail if the key is unknown in the data dict.
						if {![dict exists $value $key]} {
							return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
								[string cat "patch " $patch " does not match data " $decodedJson "." \
									"Cannot change key \"" $key "\" data. It's not present."]
						}

						## All other actions are nested.
						dict set value $key [patch [dict get $value $key] $element]
					}
				}
			}

			## Return object with new value.
			return [list "object" $value]
		}
		"indices" {
			## Fail if the data isn't an array.
			if {$type ne "array"} {
				return -code error -errorcode {XJSON PATCH TYPE_MISMATCH} \
					[string cat "patch " $patch " does not match data " $decodedJson "." \
						"It isn't an array."]
			}

			## Walk through the patch data.
			foreach {index element} $patchParam1 {
				## Extract element action and parameter.
				lassign $element elementAction elementParam

				## Switch by element action.
				switch -- $elementAction {
					"remove" {
						## Fail if the index is beyond the array length.
						if {$index >= [llength $value]} {
							return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
								[string cat "patch " $patch " does not match data " $decodedJson "." \
									"Cannot remove index \"" $index "\". It's beyond the array length."]
						}

						## Calculate end index.
						set end [expr {$index+[llength $elementParam]-1}]

						## Fail if the element parameter does not match the original data.
						if {$elementParam ne [lrange $value $index $end]} {
							return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
								[string cat "patch " $patch " does not match data " $decodedJson "." \
									"Cannot remove index \"" $index "\". The data to be patched does not match."]
						}

						## Delete indices.
						set value [lreplace $value $index $end]
					}
					"insert" {
						## Fail if the index is beyond the array length plus one.
						if {$index > [llength $value]} {
							return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
								[string cat "patch " $patch " does not match data " $decodedJson "." \
									"Cannot add index \"" $index "\". It's beyond the array length."]
						}

						## Add indices.
						set value [linsert $value $index {*}$elementParam]
					}
					default {
						## Fail if the index is beyond the array length.
						if {$index >= [llength $value]} {
							return -code error -errorcode {XJSON PATCH DATA_MISMATCH} \
								[string cat "patch " $patch " does not match data " $decodedJson "." \
									"Cannot change index \"" $index "\". It's beyond the array length."]
						}

						## All other actions are nested.
						set value [lreplace $value $index $index [patch [lindex $value $index] $element]]
					}
				}
			}

			## Return array with new value.
			return [list "array" $value]
		}
		default {
			## No such action.
			return -code error -errorcode {XJSON PATCH MALFORMED_PATCH} \
				[string cat "malformed patch format " $patch ": action must be either replace, keys, or indices and its parameters."]
		}
	}
}


## Reverse patch a JSON tree.
proc ::xjson::rpatch {decodedJson patch} {
	## Only test data if not empty.
	if {$decodedJson ne {}} {
		## Check list lengths.
		if {[llength $decodedJson] != 2} {
			return -code error -errorcode {XJSON RPATCH DATA_FORMAT} \
				"invalid decoded JSON data: must be two two-element lists consisting of type and value, or empty."
		}

		## Check type.
		if {[lindex $decodedJson 0] ni {literal number string object array}} {
			 ## Invalid type.
			return -code error -errorcode {XJSON RPATCH UNKNOWN_TYPE} \
				[string cat "invalid JSON type \"" [lindex $decodedJson 0] "\": must be array, object, string, number, literal." ]
		}
	}

	## Return original data if the patch is empty.
	if {$patch eq {}} {
		return $decodedJson
	}

	## Extract type and value from decodedJson argument.
	lassign $decodedJson type value

	## Extract patch action and parameters.
	lassign $patch patchAction patchParam1 patchParam2

	## Switch by patch action.
	switch -- $patchAction {
		"replace" {
			## Fail if the new patch data does not match the original data.
			if {$patchParam2 ne $decodedJson} {
				return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
					[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
						"The data to be patched does not match."]
			}

			## Return old data from patch.
			return $patchParam1
		}
		"keys" {
			## Fail if the data isn't an object.
			if {$type ne "object"} {
				return -code error -errorcode {XJSON RPATCH TYPE_MISMATCH} \
					[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
						"It isn't an object."]
			}

			## Walk through the patch data.
			dict for {key element} $patchParam1 {
				## Extract element action and parameter.
				lassign $element elementAction elementParam

				## Switch by element action.
				switch -- $elementAction {
					"add" {
						## Do the reverse action.
						## Fail if the key is unknown in the data dict.
						if {![dict exists $value $key]} {
							return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
								[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
									"Cannot delete key \"" $key "\". It's not present."]
						}

						## Fail if the element parameter does not match the original data.
						if {$elementParam ne [dict get $value $key]} {
							return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
								[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
									"Cannot delete key \"" $key "\". The data to be patched does not match."]
						}

						## Delete key.
						dict unset value $key
					}
					"delete" {
						## Do the reverse action.
						## Fail if the key is already known in the data dict.
						if {[dict exists $value $key]} {
							return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
								[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
									"Cannot add key \"" $key "\". It's already present."]
						}

						## Add key.
						dict set value $key $elementParam
					}
					default {
						## Fail if the key is unknown in the data dict.
						if {![dict exists $value $key]} {
							return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
								[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
									"Cannot change key \"" $key "\" data. It's not present."]
						}

						## All other actions are nested.
						dict set value $key [rpatch [dict get $value $key] $element]
					}
				}
			}

			## Return object with new value.
			return [list "object" $value]
		}
		"indices" {
			## Fail if the data isn't an array.
			if {$type ne "array"} {
				return -code error -errorcode {XJSON RPATCH TYPE_MISMATCH} \
					[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
						"It isn't an array."]
			}

			## Walk through the patch data in reverse order so the indices match.
			foreach {element index} [lreverse $patchParam1] {
				## Extract element action and parameter.
				lassign $element elementAction elementParam

				## Switch by element action.
				switch -- $elementAction {
					"insert" {
						## Do the reverse action.
						## Fail if the index is beyond the array length.
						if {$index >= [llength $value]} {
							return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
								[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
									"Cannot remove index \"" $index "\". It's beyond the array length."]
						}

						## Calculate end index.
						set end [expr {$index+[llength $elementParam]-1}]

						## Fail if the element parameter does not match the original data.
						if {$elementParam ne [lrange $value $index $end]} {
							return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
								[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
									"Cannot remove index \"" $index "\". The data to be patched does not match."]
						}

						## Delete indices.
						set value [lreplace $value $index $end]
					}
					"remove" {
						## Do the reverse action.
						## Fail if the index is beyond the array length plus one.
						if {$index > [llength $value]} {
							return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
								[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
									"Cannot add index \"" $index "\". It's beyond the array length."]
						}

						## Add indices.
						set value [linsert $value $index {*}$elementParam]
					}
					default {
						## Fail if the index is beyond the array length.
						if {$index >= [llength $value]} {
							return -code error -errorcode {XJSON RPATCH DATA_MISMATCH} \
								[string cat "reverse patch " $patch " does not match data " $decodedJson "." \
									"Cannot change index \"" $index "\". It's beyond the array length."]
						}

						## All other actions are nested.
						set value [lreplace $value $index $index [rpatch [lindex $value $index] $element]]
					}
				}
			}

			## Return array with new value.
			return [list "array" $value]
		}
		default {
			## No such action.
			return -code error -errorcode {XJSON RPATCH MALFORMED_PATCH} \
				[string cat "malformed patch format " $patch ": action must be either replace, keys, or indices and its parameters."]
		}
	}
}
