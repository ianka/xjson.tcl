##
## xjson - extended JSON functions for tcl
##
## JSON diff function.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2022 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Create a diff between two decoded JSON structures.
proc ::xjson::diff {oldDecodedJson newDecodedJson} {
	## Fail if the arguments aren't valid.
	foreach data [list $oldDecodedJson $newDecodedJson] {
		## Skip tests if empty.
		if {$data eq {}} continue

		## Check list lengths.
		if {[llength $data] != 2} {
			return -code error -errorcode {XJSON DIFF DATA_FORMAT} \
				"invalid decoded JSON data: must be two two-element lists consisting of type and value, or empty."
		}

		## Check type.
		if {[lindex $data 0] ni {literal number string object array}} {
			 ## Invalid type.
			return -code error -errorcode {XJSON DIFF UNKNOWN_TYPE} \
				[string cat "invalid JSON type \"" [lindex $data 0] "\": must be array, object, string, number, literal." ]
		}

		## The values aren't checked by this function.
	}

	## Break recursion if old and new are identical.
	if {$oldDecodedJson eq $newDecodedJson} return

	## Setup vars.
	lassign $oldDecodedJson oldType oldValue
	lassign $newDecodedJson newType newValue

	## Return replace action if the items are at not even of the same type.
	if {$oldType ne $newType} {
		return [list "replace" $oldDecodedJson $newDecodedJson]
	}

	## Switch by type.
	switch -- $oldType {
		"literal" - "number" - "string" {
			## Return replace action for simple types.
			return [list "replace" $oldDecodedJson $newDecodedJson]
		}
		"object" {
			## Handle object type.
			## Manage the actions as a dict by object key.
			set actions [dict create]

			## Find the object keys that are in both lists, deleted, or added.
			lassign [::struct::set intersect3 [dict keys $oldValue] [dict keys $newValue]] both deleted added

			## Add actions for keys that are deleted.
			foreach key $deleted {
				dict set actions $key [list "delete" [dict get $oldValue $key]]
			}

			## Add actions for keys that are added.
			foreach key $added {
				dict set actions $key [list "add" [dict get $newValue $key]]
			}

			## Add actions for keys that are in both lists but with different data.
			foreach key $both {
				## Get both the old and field value.
				set oldField [dict get $oldValue $key]
				set newField [dict get $newValue $key]

				## Skip this field if the values are identical.
				if {$oldField eq $newField} continue

				## Add action from downlevel diff.
				dict set actions $key [diff $oldField $newField]
			}

			## Return the dict of actions enveloped in a keys action.
			return [list "keys" $actions]
		}
		"array" {
			## Handle array type.
			## Manage the actions as a list by array index.
			set actions {}

			## Run through the array elements that are in both lists, deleted, or added.
			set correction 0
			foreach element [::struct::list lcsInvert [::struct::list longestCommonSubsequence $oldValue $newValue] [llength $oldValue] [llength $newValue]] {
				lassign $element contrast oldindices newindices
				lassign $oldindices oldStart oldEnd
				lassign $newindices newStart newEnd

				## Switch by contrast.
				switch -- $contrast {
					"deleted" {
						## Get deleted data.
						set data [lrange $oldValue $oldStart $oldEnd]

						## Add action for indices that are deleted.
						lappend actions [expr {$oldStart+$correction}] [list "remove" $data]

						## Correct insert index.
						incr correction -[llength $data]
					}
					"added" {
						## Get added data.
						set data [lrange $newValue $newStart $newEnd]

						## Add action for indices that are added.
						lappend actions [expr {$oldStart+$correction+1}] [list "insert" $data]

						## Correct insert index.
						incr correction [llength $data]
					}
					"changed" {
						## Check whether the changed parts are the same in length.
						if {$oldEnd-$oldStart == $newEnd-$newStart} {
							## Yes. Add actions for indices that are in both lists but with different data.
							for {set oldIndex $oldStart ; set newIndex $newStart} {$oldIndex<=$oldEnd} {incr oldIndex ; incr newIndex} {
								## Get both the old and field value.
								set oldField [lindex $oldValue $oldIndex]
								set newField [lindex $newValue $newIndex]

								## Add action from downlevel diff.
								lappend actions [expr {$oldIndex+$correction}] [diff $oldField $newField]
							}
						} else {
							## No. Add both a remove and an insert action.
							## Get data.
							set oldData [lrange $oldValue $oldStart $oldEnd]
							set newData [lrange $newValue $newStart $newEnd]

							## Add action for indices that are deleted.
							lappend actions [expr {$oldStart+$correction}] [list "remove" $oldData]

							## Add action for indices that are added.
							lappend actions [expr {$oldStart+$correction}] [list "insert" $newData]

							## Correct insert index.
							set correction [expr {$correction-[llength $oldData]+[llength $newData]}]
						}
					}
				}
			}

			## Return the list of actions enveloped in an indices action.
			return [list "indices" $actions]
		}
	}

	## Never reached.
	return -code error -errorcode {XJSON DIFF ASSERTION_FAILED} \
		"diff fallthrough should never be reached."
}
