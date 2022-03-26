##
## xjson - extended JSON functions for tcl
##
## Builin collecting functions for JSON validator and data collector classes.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2021 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Builtin collecting methods.


## Allof, oneof operator collecting methods.
dict set ::xjson::builtinCollectingMethods allof {
	allof schemaList{_}
	anyof schemaList{_}
	oneof schemaList{_}
{
	## Run through the alternative schemas.
	set index 0
	set matches 0
	set errors {}
	foreach alternativeschema [dict get $schema arguments schemaList] {
		## Collect value from data according to schema.
		if {[catch {_collect $data $alternativeschema [string cat $path [dict get $schema method] "." $index "/"] $interpreter {}} collected]} {
			## Check for null.
			if {$::errorCode eq {XJSON COLLECTOR OBJECT IS_NULL}} {
				## Increment number of matches.
				incr matches
			}

			## Remember error messages.
			lappend errors $collected
		} else {
			## Increment number of matches.
			incr matches

			## Remember the valid result if none was stored yet.
			if {![info exists result]} {
				set result $collected
			}
		}

		## Next alternative.
		incr index
	}

	## Return null if all matches have been null.
	if {![info exists result] && $matches == [llength [dict get $schema arguments schemaList]] } {
		return -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
			[string cat "decoded JSON data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Check the number of matches.
	switch -- [dict get $schema method] {
		allof {
			if {$matches != [llength [dict get $schema arguments schemaList]]} {
				return -code error -errorcode {XJSON COLLECTOR OBJECT ALTERNATIVES_MISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not match all of the listed subschemas:" [_printErrors $errors]]
			}
		}
		anyof {
			if {![info exists result]} {
				return -code error -errorcode {XJSON COLLECTOR OBJECT ALTERNATIVES_MISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not match any of the listed subschemas:" [_printErrors $errors]]
			}
		}
		oneof {
			if {![info exists result]} {
				return -code error -errorcode {XJSON COLLECTOR OBJECT ALTERNATIVES_MISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not match any of the listed subschemas:" [_printErrors $errors]]
			}

			if {$matches > 1} {
				return -code error -errorcode {XJSON COLLECTOR OBJECT ALTERNATIVES_MISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not match more than one of the listed subschemas."]
			}
		}
	}

	## Otherwise return the last valid result.
	return $result
}}


## Apply operator collecting method.
dict set ::xjson::builtinCollectingMethods apply {
	apply {args body! schema{} -isolate}
	expr  {args expr! schema{} -isolate}
	lmap  {args body! schema{} -isolate}
{
	## Collect value from data according to schema.
	set collected [_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}]

	## Setup script to evaluate.
	set argc [llength [dict get $schema arguments args]]
	switch -- [dict get $schema method] {
		"apply" {
			set script [list apply [list [dict get $schema arguments args] \
				[dict get $schema arguments body]] \
				{*}[lrange $collected 0 $argc-2] [lrange $collected $argc-1 end]]
		}
		"expr"  {
			set script [list apply [list [dict get $schema arguments args] \
				[list expr [dict get $schema arguments expr]]] \
				{*}[lrange $collected 0 $argc-2] [lrange $collected $argc-1 end]]
		}
		"lmap"  {
			set script [list lmap [dict get $schema arguments args] \
				$collected \
				[dict get $schema arguments body]]
		}
	}

	## Pass into sandbox method and return the result.
	_sandbox $data $schema $path $interpreter $script [dict exists $schema options -isolate]
}}


## Array type collecting method.
dict set ::xjson::builtinCollectingMethods array {
	array  {schema{}      -isolate -test! -max>=0 -xmax>=0 -min>=0 -xmin>=0 -multipleof>0}
	tuples {schemaList{_} -isolate -test! -max>=0 -xmax>=0 -min>=0 -xmin>=0 -multipleof>0 -flat}
	tuple  {schemaList{_}}
	duples {schemaDict{:} -isolate -test! -max>=0 -xmax>=0 -min>=0 -xmin>=0 -multipleof>0}
	duple  {schemaDict{:}}
{
	## Save schema for error messages.
	set sschema $schema

	## Sort out null.
	if {$data eq {literal null}} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
			[string cat "decoded JSON data " [_printData $data] " does match schema " [_printSchema $sschema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Assign data type and values.
	lassign $data type values

	## Fail if not an array.
	if {$type ne "array"} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT TYPE_MISMATCH} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
				"It is not a " [_printValue [dict get $schema method]] "."]
	}

	## Setup the length name for error messages.
	if {[dict get $schema method] eq "array"} {
		set lengthName "array length"
	} else {
		set lengthName "tuples count"
	}

	## Setup the options for the shortcut collecting methods.
	switch -- [dict get $schema method] {
		"array"           {dict set schema options -flat true}
		"tuple" - "duple" {dict set schema options {-flat true -min 1 -max 1}}
	}

	## Remember tuple length.
	switch -- [dict get $schema method] {
		"array" {
			set tupleLength 1
		}
		"tuples" - "tuple" {
			## Fix empty schema list.
			if {[dict get $schema arguments schemaList] eq {}} {
				dict set schema arguments schemaList {{}}
			}

			set tupleLength [llength [dict get $schema arguments schemaList]]
		}
		"duples" - "duple" {
			## Fix empty schema dict.
			if {[dict get $schema arguments schemaDict] eq {}} {
				dict set schema arguments schemaDict {{} {}}
			}

			set tupleLength [dict size [dict get $schema arguments schemaDict]]
		}
	}

	## Run through the array.
	set arrayIndex 0
	set tuple {}
	set tupleIndex 0
	set tupleSubIndex 0
	set result {}
	foreach {value} $values {
		## Get key and subschema to consider.
		switch -- [dict get $schema method] {
			"array" {
				## Array elements.
				set arrayPath $arrayIndex
				set subschema [dict get $schema arguments schema]
			}
			"tuples" - "tuple" {
				## Plain tuples.
				set arrayPath [string cat $arrayIndex "=" $tupleIndex "." $tupleSubIndex]
				set subschema [lindex [dict get $schema arguments schemaList] $tupleSubIndex]
			}
			"duples" - "duple" {
				## Tuples as dicts.
				set tupleKey [lindex [dict keys [dict get $schema arguments schemaDict]] $tupleSubIndex]
				set arrayPath [string cat $arrayIndex "=" $tupleIndex "." $tupleKey]
				set subschema [lindex [dict values [dict get $schema arguments schemaDict]] $tupleSubIndex]
			}
		}

		## Collect value from data according to schema.
		if {[catch {_collect $value $subschema [string cat $path [dict get $schema method] "#" $arrayPath "/"] $interpreter {}} collected]} {
			## Ignore null fields. Escalate the error if not null.
			if {$::errorCode ne {XJSON COLLECTOR OBJECT IS_NULL}} {
				return -code error -errorcode $::errorCode -errorinfo $::errorInfo $collected
			}
		} else {
			## Otherwise remember the collected value for the tuple.
			switch -- [dict get $schema method] {
				"array" - "tuples" - "tuple" {lappend tuple $collected}
				"duples" - "duple" {lappend tuple $tupleKey $collected}
			}

			## Next tuple subindex.
			incr tupleSubIndex
		}

		## Check if we are at the start of the next tuple.
		if {$tupleSubIndex == $tupleLength} {
			## Yes. Append the tuple to the result.
			if {[dict exists $schema options -flat]} {
				## Append flat.
				lappend result {*}$tuple
			} else {
				## Append as a list.
				lappend result $tuple
			}

			## Next tuple.
			set tuple {}
			incr tupleIndex
			set tupleSubIndex 0
		}

		## Next array index.
		incr arrayIndex
	}

	## Fail if the last tuple was incomplete.
	if {$tupleSubIndex != 0} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT INCOMPLETE_TUPLE} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
				"The last tuple " [_printValue $tuple] " is incomplete."]
	}

	## Run through all listed options in their order of appearance.
	foreach {option optionvalue} [dict get $schema options] {
		switch -- $option {
			-max - -xmax - -min - -xmin {
				## Do range checks against the tuple count.
				set comparison [dict get [dict create {*}{
					-max  >
					-xmax >=
					-min  <
					-xmin <=
				}] $option]
				if [subst {\$tupleIndex $comparison \$optionvalue}] {
					return -code error -errorcode {XJSON COLLECTOR OBJECT OUT_OF_RANGE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
							"Resulting " $lengthName " " [_printValue $tupleIndex] " is " $comparison [_printValue $optionvalue] "."]
				}
			}
			-multipleof {
				## Do the divider check against the tuple count.
				if {$tupleIndex % $optionvalue != 0} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT NOT_A_MULTIPLE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
							"Resulting " $lengthName " " [_printValue $tupleIndex] " is not a multiple of " [_printValue $optionvalue] "."]
				}
			}
			-test {
				## Pass expression into sandbox method and fail if the result isn't true.
				if {![_sandbox $data $schema $path $interpreter [list apply [list x [list expr $optionvalue]] $tupleIndex] [dict exists $schema options -isolate]]} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT TEST_FAILED} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
							"Resulting " $lengthName " " [_printValue $tupleIndex] " does not pass the test " [_printValue $optionvalue] "."]
				}
			}
		}
	}

	## Return result.
	return $result
}}


## Boolean type collecting method.
dict set ::xjson::builtinCollectingMethods boolean {{} {
	## Sort out null.
	if {$data eq {literal null}} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
			[string cat "decoded JSON data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Fail if not a literal or not a boolean value.
	if {[lindex $data 0] ne "literal" || ![string is boolean -strict [lindex $data 1]]} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT TYPE_MISMATCH} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not a " [_printValue [dict get $schema method]] "."]
	}

	## Return value.
	lindex $data 1
}}


## Const operator collecting method.
dict set ::xjson::builtinCollectingMethods const {value {
	## Return the value argument value as the collected value.
	dict get $schema arguments value
}}


## Datetime operator collecting method.
dict set ::xjson::builtinCollectingMethods datetime {{schema{} -format= -timezone' -locale=} {
	## Collect value from data according to schema.
	set collected [_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}]

	## Feed it into clock scan.
	if {[catch {clock scan $collected {*}[dict get $schema options]} result]} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT CLOCK_VALUE} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not a parseable time."]
	}

	## Return the result.
	return $result
}}


## Default operator collecting method.
dict set ::xjson::builtinCollectingMethods default {{value schema{}} {
	## Collect value from data according to schema.
	if {[catch {_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}} collected]} {
		## Escalate the error if not null.
		if {$::errorCode ne {XJSON COLLECTOR OBJECT IS_NULL}} {
			return -code error -errorcode $::errorCode -errorinfo $::errorInfo $collected
		}

		## Return the value argument value as the collected value if null.
		dict get $schema arguments value
	} else {
		## Return collected value.
		return $collected
	}
}}


## Dictby operator collecting method.
dict set ::xjson::builtinCollectingMethods dictby {{by schema{}} {
	## Run through the result elements of the schema argument.
	## Treat each element as a dict.
	set result [dict create]
	foreach element [_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}] {
		## Get key fields.
		set key {}
		foreach field [dict get $schema arguments by] {
			## Fail if the required key field is not present.
			if {![dict exists $element $field]} {
				return -code error -errorcode {XJSON COLLECTOR OBJECT UNKNOWN_FIELD} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"The object field " [_printValue $field] " specified as part of the dict key " [_printValue [dict get $schema arguments by]] \
						"is unknown in the downlevel result."]
			}

			## Remember key field value.
			lappend key [dict get $element $field]
		}

		## Fail on keys that are listed multiple times.
		if {$key in [dict keys $result]} {
			return -code error -errorcode {XJSON COLLECTOR OBJECT AMBIGUOUS_FIELD} \
				[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"The array of objects/duples fields " [_printValue [dict get $schema arguments by]] " has multiple instances of the same key " [_printValue $key] "."]
		}

		## Set the result for this key by removing the fields that are used as the dict index.
		dict set result $key [dict remove $element {*}[dict get $schema arguments by]]
	}

	## Return result.
	return $result
}}


## Dictbyindex operator collecting method.
dict set ::xjson::builtinCollectingMethods dictbyindex {{by## schema{}} {
	## Run through the result elements of the schema argument.
	## Treat each element as a dict.
	set result [dict create]
	foreach element [_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}] {
		## Get key fields.
		set key {}
		foreach field [dict get $schema arguments by] {
			## By field index.
			if {$field >= [llength $element]} {
				return -code error -errorcode {XJSON COLLECTOR OBJECT UNKNOWN_FIELD} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"The array index " [_printValue $field] " specified as part of the dict key " [_printValue [dict get $schema arguments by]] \
						"is beyong the length of the downlevel result."]
			}

			## Remember key field value.
			lappend key [lindex $element $field]
		}

		## Fail on keys that are listed multiple times.
		if {$key in [dict keys $result]} {
			return -code error -errorcode {XJSON COLLECTOR OBJECT AMBIGUOUS_FIELD} \
				[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"The array of objects/duples fields " [_printValue [dict get $schema arguments by]] " has multiple instances of the same key " [_printValue $key] "."]
		}

		## Set the result for this key by removing the fields that are used as the dict index.
		set index 0
		foreach value $element {
			if {$index ni [dict get $schema arguments by]} {
				dict lappend result $key $value
			}
			incr index
		}
	}

	## Return result.
	return $result
}}


## Discard operator collecting method.
dict set ::xjson::builtinCollectingMethods discard {{} {
	## Return null.
	return -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
		[string cat "decoded JSON data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
			"But it is discarded and reported as null."]
}}


## Dubious operator collecting method.
dict set ::xjson::builtinCollectingMethods dubious {-dubious schema{} {
	## Collect supplied dubious schema.
	_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## Escalate operator collecting method.
dict set ::xjson::builtinCollectingMethods escalate {{} {
	## Fail if there was no previous result or the previous result wasn't an error.
	if {[llength $previous] < 2} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT CANNOT_ESCALATE} \
			[string cat "Nothing to be escalated at " $path "."]
	}

	## Otherwise return with previous error.
	return -options [lrange $previous 0 end-1] [lindex $previous end]
}}


## Format operator collecting method.
dict set ::xjson::builtinCollectingMethods format {{format% schema{}} {
	## Collect value from data according to schema.
	set collected [_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}]

	## Feed it into format.
	if {[catch {format [dict get $schema arguments format] {*}$collected} result]} {
		switch -- $::errorCode {
			{TCL FORMAT FIELDVARMISMATCH} {
				return -code error -errorcode {XJSON COLLECTOR OBJECT FORMAT_FIELDVARMISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It has too few elements for the format " [_printValue [dict get $schema arguments format]] ": " $result "."]
			}
			default {
				return -code error -errorcode {XJSON COLLECTOR OBJECT FORMAT_VALUE} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not fit the format " [_printValue [dict get $schema arguments format]] ": " $result "."]
			}
		}
	}

	## Return the result.
	return $result
}}


## If operator collecting method.
dict set ::xjson::builtinCollectingMethods if {{test{} then{} else{} null{}} {
	## Evaluate the data by the test argument schema.
	if {[catch {_collect $data [dict get $schema arguments test] [string cat $path [dict get $schema method] ":test/"] $interpreter {}} collected]} {
		## Check for null.
		if {$::errorCode eq {XJSON COLLECTOR OBJECT IS_NULL}} {
			## Evaluate the null schema with the previous result if null.
			_collect $data [dict get $schema arguments null] [string cat $path [dict get $schema method] ":null/"] $interpreter \
				[list -code error -errorcode $::errorCode -errorinfo $::errorInfo $collected]
		} else {
			## Otherwise evaluate the else schema with the previous result.
			_collect $data [dict get $schema arguments else] [string cat $path [dict get $schema method] ":else/"] $interpreter \
				[list -code error -errorcode $::errorCode -errorinfo $::errorInfo $collected]
		}
	} else {
		## Evaluate the the schema with the previous result.
		_collect $data [dict get $schema arguments then] [string cat $path [dict get $schema method] ":then/"] $interpreter \
			[list $collected]
	}
}}


## Mark operator collecting method.
dict set ::xjson::builtinCollectingMethods mark {{mark schema{}} {
	## Return a list of mark and value from data according to schema.
	list [dict get $schema arguments mark] [_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}]
}}


## Nest operator collecting method.
dict set ::xjson::builtinCollectingMethods nest {collector {
	## Fail if the nested collector name is unknown.
	if {![dict exists $_nestedCollectors [dict get $schema arguments collector]]} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT UNKNOWN_COLLECTOR} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"The collector " [_printValue [dict get $schema arguments collector]] " " \
				"is unknown to the collector object " [_printValue $this] "."]
	}

	## Get nested collector object.
	set nestedCollector [dict get $_nestedCollectors [dict get $schema arguments collector]]

	## Delegate the work to the nested collector.
	if {[catch {$nestedCollector collect $data [string cat $path [dict get $schema method] ":" [dict get $schema arguments collector] "/"]} collected]} {
		## Escalate the error in verbatim if a collect error, otherwise add an explanatory message.
		if {[string match {XJSON COLLECTOR OBJECT *} $::errorCode]} {
			return -code error -errorcode $::errorCode -errorinfo $::errorInfo $collected
		} else {
			return -code error -errorcode $::errorCode -errorinfo \
				[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"The operator " [_printValue [dict get $schema method]] " returned an error:\n\t" $::errorInfo] $collected
		}
	}

	## Return collected data.
	return $collected
}}


## Null type collecting method.
dict set ::xjson::builtinCollectingMethods null {{} {
	## Check for null.
	if {$data eq {literal null}} {
		## Return null.
		return -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
			[string cat "decoded JSON data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	} else {
		## Otherwise fail.
		return -code error -errorcode {XJSON COLLECTOR OBJECT TYPE_MISMATCH} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not null."]
	}
}}


## Number type collecting method.
dict set ::xjson::builtinCollectingMethods number {
	integer {-isolate -test! -max# -xmax# -min# -xmin# -multipleof>0}
	number  {-isolate -test! -max/ -xmax/ -min/ -xmin/}
{
	## Sort out null.
	if {$data eq {literal null}} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
			[string cat "decoded JSON data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Get value.
	set value [lindex $data 1]

	## Check for integer or double.
	if {[lindex $data 0] ne "number" || ![string is [expr {[dict get $schema method] eq "integer"?"entier":"double"}] -strict $value]} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT TYPE_MISMATCH} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not a " [_printValue [dict get $schema method]] "."]
	}

	## Run through all listed options in their order of appearance.
	foreach {option optionvalue} [dict get $schema options] {
		switch -- $option {
			-max - -xmax - -min - -xmin {
				## Do range checks on the value itself.
				set comparison [dict get [dict create {*}{
					-max  >
					-xmax >=
					-min  <
					-xmin <=
				}] $option]
				if [subst {\$value $comparison \$optionvalue}] {
					return -code error -errorcode {XJSON COLLECTOR OBJECT OUT_OF_RANGE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The value " [_printValue $value] " is " $comparison [_printValue $optionvalue] "."]
				}
			}
			-multipleof {
				## Do the divider check against the value itself.
				if {$value % $optionvalue != 0} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT NOT_A_MULTIPLE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The value is " [_printValue $value] ", which is not a multiple of " [_printValue $optionvalue] "."]
				}
			}
			-test {
				## Pass expression into sandbox method and fail if the result isn't true.
				if {![_sandbox $data $schema $path $interpreter [list apply [list x [list expr $optionvalue]] $value] [dict exists $schema options -isolate]]} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT TEST_FAILED} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The value " [_printValue $value] " does not pass the test " [_printValue $optionvalue] "."]
				}
			}
		}
	}

	## Return value.
	return $value
}}


## Object type collecting method.
dict set ::xjson::builtinCollectingMethods object {{schemaDict{:} -values} {
	## Sort out null.
	if {$data eq {literal null}} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
			[string cat "decoded JSON data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Fail if not an object.
	if {[lindex $data 0] ne "object"} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT TYPE_MISMATCH} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not a " [_printValue [dict get $schema method]] "."]
	}

	## Get values.
	set values [lindex $data 1]

	## Run through the object.
	set fields {}
	foreach {field value} $values {
		## Fail on fields listed multiple times.
		if {$field in $fields} {
			return -code error -errorcode {XJSON COLLECTOR OBJECT AMBIGUOUS_FIELD} \
				[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"Object field " [_printValue $field] " is listed multiple times."]
		}

		## Fail if the field is unknown in the schema dict.
		if {![dict exists [dict get $schema arguments schemaDict] $field]} {
			return -code error -errorcode {XJSON COLLECTOR OBJECT UNKNOWN_FIELD} \
				[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"Object field " [_printValue $field] " is unknown."]
		}

		## Remember field.
		lappend fields $field
	}

	## Run through the schema dict.
	set result [dict create]
	foreach {field subschema} [dict get $schema arguments schemaDict] {
		## Check for existing field.
		if {[dict exists $values $field]} {
			## Collect value for existing field. Remember error state.
			set error [catch {_collect [dict get $values $field] $subschema [string cat $path [dict get $schema method] ":" $field "/"] $interpreter {}} collected]
		} else {
			## Fill in missing fields with their defaults. Remember error state.
			set error [catch {_collect {} $subschema [string cat $path [dict get $schema method] ":" $field "/"] $interpreter {}} collected]
		}

		## Check for errors.
		if {$error} {
			## Switch by error code.
			switch -- $::errorCode {
				{XJSON COLLECTOR OBJECT IS_NULL} {
					## Fail with missing field error if null.
					return -code error -errorcode {XJSON COLLECTOR OBJECT MISSING_FIELD} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"Object field " [_printValue $field] " is missing."]
				}
				{XJSON COLLECTOR OBJECT IS_OPTIONAL} {
					## Do nothing. This field is just not set.
				}
				default {
					## Escalate the error.
					return -code error -errorcode $::errorCode -errorinfo $::errorInfo $collected
				}
			}
		} else {
			## Otherwise remember the collected value for the result.
			dict set result $field $collected
		}
	}

	## Check for the -values option.
	if {[dict exists [dict get $schema options] "-values"]} {
		## Only return values. This is useful for applying the format operator on an object.
		dict values $result
	} else {
		## Return keys and values.
		return $result
	}
}}


## Optional operator collecting method.
dict set ::xjson::builtinCollectingMethods optional {schema{} {
	## Collect value from data according to schema argument.
	if {[catch {_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}} collected]} {
		## Escalate the error if not null.
		if {$::errorCode ne {XJSON COLLECTOR OBJECT IS_NULL}} {
			return -code error -errorcode $::errorCode -errorinfo $::errorInfo $collected
		}

		## Return null as optional.
		return -code error -errorcode {XJSON COLLECTOR OBJECT IS_OPTIONAL} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is declared optional, so it is allowed to be missing uplevel."]
	}

	## Return collected value.
	return $collected
}}


## Otherwise operator composing method.
dict set ::xjson::builtinCollectingMethods otherwise {{} {
	## Report otherwise catchall.
	return -code error -errorcode {XJSON COLLECTOR OBJECT IS_OTHERWISE} \
		[string cat "Otherwise hit at " $path "."]
}}


## Pass operator collecting method.
dict set ::xjson::builtinCollectingMethods pass {{} {
	## Fail if there was no previous result or the previous result was an error.
	if {[llength $previous] != 1} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT CANNOT_PASS} \
			[string cat "Nothing to be passed through at " $path "."]
	}

	## Otherwise return with previous result.
	lindex $previous 0
}}


## Regsub operator collecting method.
dict set ::xjson::builtinCollectingMethods regsub {{regexp~ replacement schema{} -all -nocase -start.} {
	## Set default values for the start, all, and nocase options.
	set start 0
	set all {}
	set nocase {}

	## Run through all listed options in their order of appearance.
	foreach {option optionvalue} [dict get $schema options] {
		switch -- $option {
			-nocase - -all {
				## Those options have the value true when set. Otherwise they are unset.
				set [string range $option 1 end] $option
			}
			-start {
				## Remember the start position.
				set start $optionvalue
			}
		}
	}

	## Collect value from data according to schema.
	set collected [_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}]

	## Apply regexp substitution to collected value.
	regsub {*}$nocase {*}$all -start $start -- [dict get $schema arguments regexp] $collected [dict get $schema arguments replacement]
}}


## String type collecting method.
dict set ::xjson::builtinCollectingMethods string {{
		-and
		-is=alnum|alpha|ascii|boolean|control|digit|double|entier|false|graph|integer|list|lower|print|punct|space|true|upper|uuid|wideinteger|wordchar|xdigit
		-nocase -case
		-range- -tolower- -totitle- -toupper-
		-trim= -trimleft= -trimright=
		-max>=0 -xmax>=0 -min>=0 -xmin>=0 -multipleof>0
		-start. -first= -last=
		-maxpos>=0 -xmaxpos>=0 -minpos>=0 -xminpos>=0 -multipleofpos>0
		-reverse
		-match= -regexp~
		-clength>=0 -before= -xbefore= -behind= -xbehind= -equal=
		-map|
		-isolate -test! -transform!
	} {
	## Sort out null.
	if {$data eq {literal null}} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
			[string cat "decoded JSON data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Fail if not a string.
	if {[lindex $data 0] ne "string"} {
		return -code error -errorcode {XJSON COLLECTOR OBJECT TYPE_MISMATCH} \
			[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not a " [_printValue [dict get $schema method]] "."]
	}

	## Set default values for the test string, the needle position, and some options.
	set teststring [lindex $data 1]
	set position -1
	set nocase {}
	set clength {}
	set startpos {}

	## Run through all listed options in their order of appearance.
	foreach {option optionvalue} [dict get $schema options] {
		switch -- $option {
			-and {
				## Resets the test string for further tests.
				set teststring [lindex $data 1]
			}
			-before - -xbefore - -behind - -xbehind {
				## Do range checks against the lexical order.
				set comparison [dict get [dict create {*}{
					-before  >0
					-xbefore >=0
					-behind  <0
					-xbehind <=0
				}] $option]
				if [subst {\[string compare $nocase $clength \$teststring \$optionvalue] $comparison}] {
					return -code error -errorcode {XJSON COLLECTOR OBJECT OUT_OF_RANGE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " is not " \
							[expr {$nocase ne {}?"case-insensitively":""}] " lexically " [dict get [dict create {*}{
								-before  "before or equal"
								-xbefore "before"
								-behind  "behind or equal"
								-xbehind "behind"
							}] $option] " " [_printValue $optionvalue] \
							[expr {$clength ne {}?[string cat " in the first" [lindex $clength end] "characters"]:""}] "."]
				}
			}
			-case {
				## Switch to case-sensitive matching.
				set nocase {}
			}
			-clength {
				## Remember compare length.
				if {$optionvalue > 0} {
					set clength "-length $optionvalue"
				} else {
					set clength {}
				}
			}
			-equal {
				## Test if the strings is considered equal to the option value honoring -nocase and -clength.
				if {![string equal {*}$nocase {*}$clength $teststring $optionvalue]} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT OUT_OF_RANGE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " is not " \
							[expr {$nocase ne {}?"case-insensitively":""}] " lexically equal " [_printValue $optionvalue] \
							[expr {$clength ne {}?[string cat " in the first" [lindex $clength end] "characters"]:""}] "."]
				}
			}
			-first - -last {
				## Find the mentioned needle in the haystack and remember its position.
				set position [string [string range $option 1 end] $optionvalue $teststring {*}$startpos]
			}
			-is {
				## Fail if the result does not match.
				if {![::xjson::_stringis $optionvalue $teststring]} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT TYPE_MISMATCH} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"is not a " [_printValue $optionvalue] "."]
				}
			}
			-map {
				## Manipulate the test string according to the option.
				set teststring [string map {*}$nocase $optionvalue $teststring]
			}
			-match {
				## Fail if the string does not match.
				if {![string match {*}$nocase $optionvalue $teststring]} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT NO_MATCH} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"does not match the pattern " [_printValue $optionvalue] "."]
				}
			}
			-max - -xmax - -min - -xmin {
				## Do range checks against the string length.
				set comparison [dict get [dict create {*}{
					-max  >
					-xmax >=
					-min  <
					-xmin <=
				}] $option]
				if [subst {\[string length \$teststring] $comparison \$optionvalue}] {
					return -code error -errorcode {XJSON COLLECTOR OBJECT OUT_OF_RANGE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"length " [_printValue [string length $teststring]] " is " $comparison [_printValue $optionvalue] "."]
				}
			}
			-maxpos - -xmaxpos - -minpos - -xminpos {
				## Do range checks against the needle position.
				set comparison [dict get [dict create {*}{
					-maxpos  >
					-xmaxpos >=
					-minpos  <
					-xminpos <=
				}] $option]
				if [subst {\$position $comparison \$optionvalue}] {
					return -code error -errorcode {XJSON COLLECTOR OBJECT OUT_OF_RANGE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"needle position " [_printValue $position] " is " $comparison [_printValue $optionvalue] "."]
				}
			}
			-multipleof {
				## Do the divider check against the string length.
				if {[string length $teststring] % $optionvalue != 0} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT NOT_A_MULTIPLE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"length " [_printValue [string length $teststring]] " is not a multiple of " [_printValue $optionvalue] "."]
				}
			}
			-multipleofpos {
				## Do the divider check against the needle position.
				if {$position % $optionvalue != 0} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT NOT_A_MULTIPLE} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"needle position " [_printValue $position] " is not a multiple of " [_printValue $optionvalue] "."]
				}
			}
			-nocase {
				## Switch to case-insensitive matching.
				set nocase "-nocase"
			}
			-range - -tolower - -totitle - -toupper {
				## Manipulate the test string according to the option.
				set teststring [string [string range $option 1 end] $teststring [lindex $optionvalue 0] [lindex $optionvalue end]]
			}
			-regexp {
				## Fail if the string does not match.
				if {![regexp {*}$nocase {*}[expr {$startpos ne {}?"-start $startpos":""}] -- $optionvalue $teststring]} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT NO_MATCH} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"does not match the regular expression " [_printValue $optionvalue] "."]
				}
			}
			-reverse {
				## Reverse the test string back-front. Sometimes useful for matching and regexp processing.
				set teststring [string reverse $teststring]
			}
			-start {
				## Remember start position.
				set startpos $optionvalue
			}
			-test {
				## Pass expression into sandbox method and fail if the result isn't true.
				if {![_sandbox $data $schema $path $interpreter [list apply [list x [list expr $optionvalue]] $teststring] [dict exists $schema options -isolate]]} {
					return -code error -errorcode {XJSON COLLECTOR OBJECT TEST_FAILED} \
						[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"does not pass the test " [_printValue $optionvalue] "."]
				}
			}
			-transform {
				## Pass command into sandbox method and apply the result to the teststring.
				set teststring [_sandbox $data $schema $path $interpreter [list apply [list x $optionvalue] $teststring] [dict exists $schema options -isolate]]
			}
			-trim - -trimleft - -trimright {
				## Manipulate the test string according to the option.
				set teststring [string [string range $option 1 end] $teststring {*}$optionvalue]
			}
		}
	}

	## Return value.
	lindex $data 1
}}


## Stringop operator collecting method.
dict set ::xjson::builtinCollectingMethods stringop {{schema{}
		-nocase -case
		-map|
		-range- -tolower- -totitle- -toupper-
		-trim= -trimleft= -trimright=
	} {
	## Set default values for the nocase option.
	set nocase {}

	## Collect value from data according to schema.
	set collected [_collect $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}]

	## Run through all listed options in their order of appearance.
	foreach {option optionvalue} [dict get $schema options] {
		switch -- $option {
			-case {
				## Switch to case-sensitive matching.
				set nocase {}
			}
			-map {
				## Manipulate the string according to the option.
				set collected [string map {*}$nocase $optionvalue $collected]
			}
			-nocase {
				## Switch to case-insensitive matching.
				set nocase "-nocase"
			}
			-range - -tolower - -totitle - -toupper {
				## Manipulate the string according to the option.
				set collected [string [string range $option 1 end] $collected [lindex $optionvalue 0] [lindex $optionvalue end]]
			}
			-trim - -trimleft - -trimright {
				## Manipulate the string according to the option.
				set collected [string [string range $option 1 end] $collected {*}$optionvalue]
			}
		}
	}

	## Return value.
	return $collected
}}


## Switch operator collecting method.
dict set ::xjson::builtinCollectingMethods switch {{schemas{|} else{} null{}} {
	## Run through the alternative schemas.
	set errors {}
	set nulls 0
	set index 0
	foreach {test then} [dict get $schema arguments schemas] {
		## Evaluate the data by the test schema.
		if {![catch {_collect $data $test [string cat $path [dict get $schema method] ":test#" $index "/"] $interpreter {}} collected]} {
			## No error. Evaluate the then schema with the previous result.
			if {[catch {_collect $data $then [string cat $path [dict get $schema method] ":then#" $index "/"] $interpreter [list $collected]} collected]} {
				## Escalate the error, if any.
				return -code error -errorcode $::errorCode -errorinfo $::errorInfo $collected
			}

			## Otherwise return the result.
			return $collected
		}

		## Remember error messages.
		lappend errors $collected

		## Check for null.
		if {$::errorCode eq {XJSON COLLECTOR OBJECT IS_NULL}} {
			## Increase the number of nulls found.
			incr nulls
		}

		## Next pair.
		incr index
	}

	## Check if all test schemas returned null.
	if {$nulls == $index} {
		## Yes. Evaluate the null schema.
		_collect $data [dict get $schema arguments null] [string cat $path [dict get $schema method] ":null/"] $interpreter \
			[list -code error -errorcode {XJSON COLLECTOR OBJECT IS_NULL} \
				[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"Null is reported by all of the listed subschemas:" [_printErrors $errors]]]
	} else {
		## No. Evaluate the else schema.
		_collect $data [dict get $schema arguments else] [string cat $path [dict get $schema method] ":else/"] $interpreter \
			[list -code error -errorcode {XJSON COLLECTOR OBJECT ALTERNATIVES_MISMATCH} \
				[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"It does not match any of the listed subschemas:" [_printErrors $errors]]]
	}
}}
