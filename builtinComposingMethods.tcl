##
## xjson - extended JSON functions for tcl
##
## Builin composing functions for JSON composer classes.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2021 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Builtin composing methods.


## Allof, oneof operator composing methods.
dict set ::xjson::builtinComposingMethods allof {
	allof schemaList{_}
	anyof schemaList{_}
	oneof schemaList{_}
{
	## Run through the alternative schemas.
	set index 0
	set matches 0
	set errors {}
	foreach alternativeschema [dict get $schema arguments schemaList] {
		## Compose value from data according to schema.
		if {[catch {_compose $data $alternativeschema [string cat $path [dict get $schema method] "." $index "/"] $interpreter {}} composed]} {
			## Check for null.
			if {$::errorCode eq {XJSON COMPOSER OBJECT IS_NULL}} {
				## Increment number of matches.
				incr matches
			}

			## Remember error messages.
			lappend errors $composed
		} else {
			## Increment number of matches.
			incr matches

			## Remember the valid result if none was stored yet.
			if {![info exists result]} {
				set result $composed
			}
		}

		## Next alternative.
		incr index
	}

	## Return null if all matches have been null.
	if {![info exists result] && $matches == [llength [dict get $schema arguments schemaList]] } {
		return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
			[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Check the number of matches.
	switch -- [dict get $schema method] {
		allof {
			if {$matches != [llength [dict get $schema arguments schemaList]]} {
				return -code error -errorcode {XJSON COMPOSER OBJECT ALTERNATIVES_MISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not match all of the listed subschemas:" [_printErrors $errors]]
			}
		}
		anyof {
			if {![info exists result]} {
				return -code error -errorcode {XJSON COMPOSER OBJECT ALTERNATIVES_MISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not match any of the listed subschemas:" [_printErrors $errors]]
			}
		}
		oneof {
			if {![info exists result]} {
				return -code error -errorcode {XJSON COMPOSER OBJECT ALTERNATIVES_MISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not match any of the listed subschemas:" [_printErrors $errors]]
			}

			if {$matches > 1} {
				return -code error -errorcode {XJSON COMPOSER OBJECT ALTERNATIVES_MISMATCH} \
					[string cat "decoded JSON data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not match more than one of the listed subschemas."]
			}
		}
	}

	## Otherwise return the last valid result.
	return $result
}}


## Apply operator composing method.
dict set ::xjson::builtinComposingMethods apply {
	apply {args body! schema{} -isolate}
	expr  {args expr! schema{} -isolate}
	lmap  {args body! schema{} -isolate}
{
	## Setup script to evaluate.
	set argc [llength [dict get $schema arguments args]]
	switch -- [dict get $schema method] {
		"apply" {
			set script [list apply [list [dict get $schema arguments args] \
				[dict get $schema arguments body]] \
				{*}[lrange $data 0 $argc-2] [lrange $data $argc-1 end]]
		}
		"expr"  {
			set script [list apply [list [dict get $schema arguments args] \
				[list expr [dict get $schema arguments expr]]] \
				{*}[lrange $data 0 $argc-2] [lrange $data $argc-1 end]]
		}
		"lmap"  {
			set script [list lmap [dict get $schema arguments args] \
				$data \
				[dict get $schema arguments body]]
		}
	}

	## Compose value from sandbox operation according to schema.
	_compose \
		[_sandbox $data $schema $path $interpreter $script [dict exists $schema options -isolate]] \
		[dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## Array type composing method.
dict set ::xjson::builtinComposingMethods array {
	array  {schema{}      -null= -isolate -test! -max>=0 -xmax>=0 -min>=0 -xmin>=0 -multipleof>0}
	tuples {schemaList{_} -null= -isolate -test! -max>=0 -xmax>=0 -min>=0 -xmin>=0 -multipleof>0 -flat}
	tuple  {schemaList{_} -null=}
	duples {schemaDict{:} -null= -isolate -test! -max>=0 -xmax>=0 -min>=0 -xmin>=0 -multipleof>0}
	duple  {schemaDict{:} -null=}
{
	## Save schema for error messages.
	set sschema $schema

	## Sort out null.
	if {[dict exists $schema options -null] && $data eq [dict get $schema options -null]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
			[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $sschema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Setup the length name for error messages.
	if {[dict get $schema method] eq "array"} {
		set lengthName "array length"
	} else {
		set lengthName "tuples count"
	}

	## Setup the options for the shortcut composing methods.
	switch -- [dict get $schema method] {
		"array"           {dict set schema options -flat true}
		"tuple" - "duple" {dict set schema options {-flat true -min 1 -max 1}}
	}

	## Prepare fields from data.
	switch -- [dict get $schema method] {
		"array" {
			## Remember tuple length.
			set tupleLength 1

			## For arrays, the data is already fields.
			set fields $data
		}
		"tuples" - "tuple" {
			## Fix empty schema list.
			if {[dict get $schema arguments schemaList] eq {}} {
				dict set schema arguments schemaList {{}}
			}

			## Remember tuple length.
			set tupleLength [llength [dict get $schema arguments schemaList]]

			## For flat tuples, the data is already fields.
			## For structured tuples, the data must be flattened.
			set fields [expr {[dict exists $schema options -flat]?$data:[concat {*}$data]}]
		}
		"duple" - "duples" {
			## Fix empty schema dict.
			if {[dict get $schema arguments schemaDict] eq {}} {
				dict set schema arguments schemaDict {{} {}}
			}

			## Remember tuple length.
			set tupleLength [dict size [dict get $schema arguments schemaDict]]

			## Single duples are flat and need to be put in a extra list for further processing.
			if {[dict get $schema method] eq "duple"} {
				set data [list $data]
			}

			## Run through all elements.
			set fields {}
			foreach element $data {
				## Run through key-value pairs.
				set fdict [dict create]
				foreach {key value} $element {
					## Fail on fields listed multiple times.
					if {[dict exists $fdict $key]} {
						return -code error -errorcode {XJSON COMPOSER OBJECT AMBIGUOUS_FIELD} \
							[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
								"Duple key " [_printValue $key] " is listed multiple times."]
					}

					## Fail if the field is unknown in the schema dict.
					if {![dict exists [dict get $schema arguments schemaDict] $key]} {
						return -code error -errorcode {XJSON COMPOSER OBJECT UNKNOWN_FIELD} \
							[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
								"Duple key " [_printValue $key] " is unknown."]
					}

					## Remember key and value.
					dict set fdict $key $value
				}

				## Reorder fields as put in the schema.
				foreach key [dict keys [dict get $schema arguments schemaDict]] {
					if {[dict exists $fdict $key]} {
						lappend fields [dict get $fdict $key]
					}
				}
			}
		}
	}

	## Run through the array.
	set arrayIndex 0
	set tupleIndex 0
	set tupleSubIndex 0
	set result {}
	foreach {value} $fields {
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

		## Compose value from data according to schema.
		if {[catch {_compose $value $subschema [string cat $path [dict get $schema method] "#" $arrayPath "/"] $interpreter {}} composed]} {
			## Check error code.
			switch -- $::errorCode {
				{XJSON COMPOSER OBJECT IS_NULL} {
					## Do nothing. This field is just not set.
				}
				{XJSON COMPOSER OBJECT IS_EXPLICIT_NULL} {
					## Note this field as a literal null.
					lappend result [list literal null]
				}
				default {
					## Escalate the error if not null.
					return -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed
				}
			}
		} else {
			## Otherwise remember the composed value for the tuple.
			lappend result $composed

			## Next tuple subindex.
			incr tupleSubIndex
		}

		## Check if we are at the start of the next tuple.
		if {$tupleSubIndex == $tupleLength} {
			## Yes. Next tuple.
			incr tupleIndex
			set tupleSubIndex 0
		}

		## Next array index.
		incr arrayIndex
	}

	## Fail if the last tuple was incomplete.
	if {$tupleSubIndex != 0} {
		return -code error -errorcode {XJSON COMPOSER OBJECT INCOMPLETE_TUPLE} \
			[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
				"The last tuple " [_printValue [lrange $fields end-[expr {[llength $fields]%$tupleLength-1}] end]] " is incomplete."]
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
					return -code error -errorcode {XJSON COMPOSER OBJECT OUT_OF_RANGE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
							"Resulting " $lengthName " " [_printValue $tupleIndex] " is " $comparison [_printValue $optionvalue] "."]
				}
			}
			-multipleof {
				## Do the divider check against the tuple count.
				if {$tupleIndex % $optionvalue != 0} {
					return -code error -errorcode {XJSON COMPOSER OBJECT NOT_A_MULTIPLE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
							"Resulting " $lengthName " " [_printValue $tupleIndex] " is not a multiple of " [_printValue $optionvalue] "."]
				}
			}
			-test {
				## Pass expression into sandbox method and fail if the result isn't true.
				if {![_sandbox $data $schema $path $interpreter [list apply [list x [list expr $optionvalue]] $tupleIndex] [dict exists $schema options -isolate]]} {
					return -code error -errorcode {XJSON COMPOSER OBJECT TEST_FAILED} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $sschema] " at " $path "\n" \
							"Resulting " $lengthName " " [_printValue $tupleIndex] " does not pass the test " [_printValue $optionvalue] "."]
				}
			}
		}
	}

	## Return result.
	list array $result
}}


## Boolean type composing method.
dict set ::xjson::builtinComposingMethods boolean {-- -null= {
	## Sort out null.
	if {[dict exists $schema options -null] && $data eq [dict get $schema options -null]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
			[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Fail if not a boolean value.
	if {![string is boolean -strict $data]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT TYPE_MISMATCH} \
			[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not a " [_printValue [dict get $schema method]] "."]
	}

	## Return value.
	list literal [expr {$data?"true":"false"}]
}}


## Const operator composing method.
dict set ::xjson::builtinComposingMethods const {{type value} {
	## Return the type and value arguments.
	list [dict get $schema arguments type] [dict get $schema arguments value]
}}


## Datetime operator composing method.
dict set ::xjson::builtinComposingMethods datetime {{schema{} -format= -timezone' -locale=} {
	## Feed the data into clock format.
	if {[catch {clock format $data {*}[dict get $schema options]} value]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT CLOCK_VALUE} \
			[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not a Tcl timeVal."]
	}

	## Compose value from values according to schema.
	_compose $value [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## Decoded/encoded type composing method.
dict set ::xjson::builtinComposingMethods decoded {
	decoded -null=
	encoded -null=
{
	## Sort out null.
	if {[dict exists $schema options -null] && $data eq [dict get $schema options -null]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
			[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Fail if not a a decoded/encoded value.
	if {[catch {::xjson::[expr {[dict get $schema method] eq "decoded"?"encode":"decode"}] $data} result]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT TYPE_MISMATCH} \
			[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not " [dict get $schema method] " JSON data:\n" $result]
	}

	## Return value.
	list [dict get $schema method] $data
}}


## Default operator composing method.
dict set ::xjson::builtinComposingMethods default {{type value schema{}} {
	## Compose value from data according to schema.
	if {[catch {_compose $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}} composed]} {
		## Escalate the error if not null.
		if {$::errorCode ne {XJSON COMPOSER OBJECT IS_NULL}} {
			return -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed
		}

		## Return the type and value arguments as the composed value if null.
		list [dict get $schema arguments type] [dict get $schema arguments value]
	} else {
		## Return composed value.
		return $composed
	}
}}


## Dictby operator composing method.
dict set ::xjson::builtinComposingMethods dictby {{by schema{}} {
	## Arrange name, key, and subdict value as one list element.
	set values {}
	set names [dict get $schema arguments by]
	foreach {keys subdict} $data {
		set prefixes {}
		foreach name $names key [expr {[llength $names]>1?$keys:[list $keys]}] {
			lappend prefixes $name $key
		}
		lappend values [list {*}$prefixes {*}$subdict]
	}

	## Feed values into the schema argument.
	_compose $values [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## Dictbyindex operator composing method.
dict set ::xjson::builtinComposingMethods dictbyindex {{by## schema{}} {
	## Insert keys into the sublist.
	set values {}
	set indices [dict get $schema arguments by]
	foreach {keys sublist} $data {
		set newlist $sublist
		foreach index $indices key [expr {[llength $indices]>1?$keys:[list $keys]}] {
			set newlist [linsert $newlist $index $key]
		}
		lappend values $newlist
	}

	## Feed values into the schema argument.
	_compose $values [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## Discard operator composing method.
dict set ::xjson::builtinComposingMethods discard {{} {
	## Return null.
	return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
		[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
			"But it is discarded and reported as null."]
}}


## Dubious operator composing method.
dict set ::xjson::builtinComposingMethods dubious {-dubious schema{} {
	## Compose supplied dubious schema.
	_compose $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## Escalate operator composing method.
dict set ::xjson::builtinComposingMethods escalate {{} {
	## Fail if there was no previous result or the previous result wasn't an error.
	if {[llength $previous] < 2} {
		return -code error -errorcode {XJSON COMPOSER OBJECT CANNOT_ESCALATE} \
			[string cat "Nothing to be escalated at " $path "."]
	}

	## Otherwise return with previous error.
	return -options [lrange $previous 0 end-1] [lindex $previous end]
}}


## Format operator composing method.
dict set ::xjson::builtinComposingMethods format {{format% schema{}} {
	## Feed the data into format.
	if {[catch {format [dict get $schema arguments format] {*}$data} values]} {
		switch -- $::errorCode {
			{TCL FORMAT FIELDVARMISMATCH} {
				return -code error -errorcode {XJSON COMPOSER OBJECT FORMAT_FIELDVARMISMATCH} \
					[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It has too few elements for the format " [_printValue [dict get $schema arguments format]] ": " $values "."]
			}
			default {
				return -code error -errorcode {XJSON COMPOSER OBJECT FORMAT_VALUE} \
					[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"It does not fit the format " [_printValue [dict get $schema arguments format]] ": " $values "."]
			}
		}
	}

	## Compose value from values according to schema.
	_compose $values [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## If operator composing method.
dict set ::xjson::builtinComposingMethods if {{test{} then{} else{} null{}} {
	## Evaluate the data by the test argument schema.
	if {[catch {_compose $data [dict get $schema arguments test] [string cat $path [dict get $schema method] ":test/"] $interpreter {}} composed]} {
		## Check for null.
		if {$::errorCode eq {XJSON COMPOSER OBJECT IS_NULL}} {
			## Evaluate the null schema with the previous result if null.
			_compose $data [dict get $schema arguments null] [string cat $path [dict get $schema method] ":null/"] $interpreter \
				[list -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed]
		} else {
			## Otherwise evaluate the else schema with the previous result.
			_compose $data [dict get $schema arguments else] [string cat $path [dict get $schema method] ":else/"] $interpreter \
				[list -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed]
		}
	} else {
		## Evaluate the the schema with the previous result.
		_compose $data [dict get $schema arguments then] [string cat $path [dict get $schema method] ":then/"] $interpreter \
			[list $composed]
	}
}}


## Mark operator composing method.
dict set ::xjson::builtinComposingMethods mark {{mark schema{}} {
	## Fail if the mark does not match.
	if {[lindex $data 0] ne [dict get $schema arguments mark]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT MARK_MISMATCH} \
			[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"It is not marked properly."]
	}

	## Compose value from data according to schema.
	_compose [lindex $data 1] [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## Nest operator composing method.
dict set ::xjson::builtinComposingMethods nest {composer {
	## Fail if the nested composer name is unknown.
	if {![dict exists $_nestedComposers [dict get $schema arguments composer]]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT SCHEMA UNKNOWN_COMPOSER} \
			[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
				"The composer " [_printValue [dict get $schema arguments composer]] " " \
				"is unknown to the composer object " [_printValue $this] "."]
	}

	## Get nested composer object.
	set nestedComposer [dict get $_nestedComposers [dict get $schema arguments composer]]

	## Delegate the work to the nested composer.
	if {[catch {$nestedComposer compose $data [string cat $path [dict get $schema method] ":" [dict get $schema arguments composer] "/"]} composed]} {
		## Escalate the error in verbatim if a compose error, otherwise add an explanatory message.
		if {[string match {XJSON COMPOSER OBJECT *} $::errorCode]} {
			return -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed
		} else {
			return -code error -errorcode $::errorCode -errorinfo \
				[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"The operator " [_printValue [dict get $schema method]] " returned an error:\n\t" $::errorInfo] $composed
		}
	}

	## Return composed data.
	return $composed
}}


## Null type composing method.
dict set ::xjson::builtinComposingMethods null {-- {-null=} {
	## Sort out null.
	if {[dict exists $schema options -null] && $data eq [dict get $schema options -null]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
			[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Otherwise fail.
	return -code error -errorcode {XJSON COMPOSER OBJECT TYPE_MISMATCH} \
		[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
			"It is not null."]
}}


## Number type composing method.
dict set ::xjson::builtinComposingMethods number {
	integer {-null= -isolate -test! -max# -xmax# -min# -xmin# -multipleof>0}
	number  {-null= -isolate -test! -max/ -xmax/ -min/ -xmin/}
{
	## Sort out null.
	if {[dict exists $schema options -null] && $data eq [dict get $schema options -null]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
			[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Check for integer or double.
	if {![string is [expr {[dict get $schema method] eq "integer"?"entier":"double"}] -strict $data]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT TYPE_MISMATCH} \
			[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
				if [subst {\$data $comparison \$optionvalue}] {
					return -code error -errorcode {XJSON COMPOSER OBJECT OUT_OF_RANGE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The value " [_printValue $data] " is " $comparison [_printValue $optionvalue] "."]
				}
			}
			-multipleof {
				## Do the divider check against the value itself.
				if {$data % $optionvalue != 0} {
					return -code error -errorcode {XJSON COMPOSER OBJECT NOT_A_MULTIPLE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The value is " [_printValue $data] ", which is not a multiple of " [_printValue $optionvalue] "."]
				}
			}
			-test {
				## Pass expression into sandbox method and fail if the result isn't true.
				if {![_sandbox $data $schema $path $interpreter [list apply [list x [list expr $optionvalue]] $data] [dict exists $schema options -isolate]]} {
					return -code error -errorcode {XJSON COMPOSER OBJECT TEST_FAILED} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The value " [_printValue $data] " does not pass the test " [_printValue $optionvalue] "."]
				}
			}
		}
	}

	## Return value.
	list number $data
}}


## Object type composing method.
dict set ::xjson::builtinComposingMethods object {{schemaDict{:} -null= -missing= -values} {
	## Sort out null.
	if {[dict exists $schema options -null] && $data eq [dict get $schema options -null]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
			[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Run through the data.
	## This works different depending on the -values switch.
	if {[dict exists $schema options -values]} {
		## Run through values.
		set index 0
		foreach value $data {
			## Fail if we are beyond the number of fields listed in the schema
			if {$index >= [dict size [dict get $schema arguments schemaDict]]} {
				return -code error -errorcode {XJSON COMPOSER OBJECT OVERFLOW_FIELD} \
					[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"Object value " [_printValue $value] " is beyond the known fields."]
			}

			## Remember field and value.
			dict set fields [lindex [dict keys [dict get $schema arguments schemaDict]] $index] $value

			## Next field.
			incr index
		}
	} else {
		## Run through key-value pairs.
		set fields [dict create]
		foreach {field value} $data {
			## Fail on fields listed multiple times.
			if {[dict exists $fields $field]} {
				return -code error -errorcode {XJSON COMPOSER OBJECT AMBIGUOUS_FIELD} \
					[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"Object field " [_printValue $field] " is listed multiple times."]
			}

			## Fail if the field is unknown in the schema dict.
			if {![dict exists [dict get $schema arguments schemaDict] $field]} {
				return -code error -errorcode {XJSON COMPOSER OBJECT UNKNOWN_FIELD} \
					[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"Object field " [_printValue $field] " is unknown."]
			}

			## Remember field and value.
			dict set fields $field $value
		}
	}

	## Run through the schema dict.
	set result [dict create]
	foreach {field subschema} [dict get $schema arguments schemaDict] {
		## Check for existing field.
		if {[dict exists $fields $field]} {
			## Compose value for existing field. Remember error state.
			set error [catch {_compose [dict get $fields $field] $subschema [string cat $path [dict get $schema method] ":" $field "/"] $interpreter {}} composed]
		} else {
			## Field is missing. Check if we should supply a value.
			if {[dict exists $schema options -missing]} {
				## Yes. Fill in missing fields with their defaults. Remember error state.
				set error [catch {_compose [dict get $schema options -missing] $subschema [string cat $path [dict get $schema method] ":" $field "/"] $interpreter {}} composed]
			} else {
				## No. Fail with missing field error.
				return -code error -errorcode {XJSON COMPOSER OBJECT MISSING_FIELD} \
					[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
						"Object field " [_printValue $field] " is missing."]
			}
		}

		## Check for errors.
		if {$error} {
			## Switch by error code.
			switch -- $::errorCode {
				{XJSON COMPOSER OBJECT IS_NULL} {
					## Fail with missing field error if null.
					return -code error -errorcode {XJSON COMPOSER OBJECT MISSING_FIELD} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"Object field " [_printValue $field] " is missing."]
				}
				{XJSON COMPOSER OBJECT IS_OPTIONAL} {
					## Do nothing. This field is just not set.
				}
				{XJSON COMPOSER OBJECT IS_EXPLICIT_NULL} {
					## Note this field as a literal null.
					dict set result $field [list literal null]
				}
				default {
					## Escalate the error.
					return -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed
				}
			}
		} else {
			## Otherwise remember the composed value for the result.
			dict set result $field $composed
		}
	}

	## Return the result.
	list object $result
}}


## Optional operator composing method.
dict set ::xjson::builtinComposingMethods optional {{schema{} -emitnull} {
	## Compose value from data according to schema argument.
	if {[catch {_compose $data [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}} composed]} {
		## Escalate the error if not null.
		if {$::errorCode ne {XJSON COMPOSER OBJECT IS_NULL}} {
			return -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed
		}

		## Return null as optional.
		if {[dict exists $schema options -emitnull]} {
			return -code error -errorcode {XJSON COMPOSER OBJECT IS_EXPLICIT_NULL} \
				[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"But it is declared optional, and should be noted as an explicit null uplevel."]
		} else {
			return -code error -errorcode {XJSON COMPOSER OBJECT IS_OPTIONAL} \
				[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"But it is declared optional, so it is allowed to be missing uplevel."]
		}
	}

	## Return composed value.
	return $composed
}}


## Otherwise operator composing method.
dict set ::xjson::builtinComposingMethods otherwise {{} {
	## Report otherwise catchall.
	return -code error -errorcode {XJSON COMPOSER OBJECT IS_OTHERWISE} \
		[string cat "Otherwise hit at " $path "."]
}}


## Pass operator composing method.
dict set ::xjson::builtinComposingMethods pass {{} {
	## Fail if there was no previous result or the previous result was an error.
	if {[llength $previous] != 1} {
		return -code error -errorcode {XJSON COMPOSER OBJECT CANNOT_PASS} \
			[string cat "Nothing to be passed through at " $path "."]
	}

	## Otherwise return with previous result.
	lindex $previous 0
}}


## Regsub operator composing method.
dict set ::xjson::builtinComposingMethods regsub {{regexp~ replacement schema{} -all -nocase -start.} {
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

	## Compose value from regsubed data according to schema.
	_compose \
		[regsub {*}$nocase {*}$all -start $start -- [dict get $schema arguments regexp] $data [dict get $schema arguments replacement]] \
		[dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## String type composing method.
dict set ::xjson::builtinComposingMethods string {-- {
		-null=
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
	if {[dict exists $schema options -null] && $data eq [dict get $schema options -null]} {
		return -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
			[string cat "Tcl data " [_printData $data] " does match schema " [_printSchema $schema] " at " $path "\n" \
				"But it is null and reported as such."]
	}

	## Set default values for the test string, the needle position, and some options.
	set teststring $data
	set position -1
	set nocase {}
	set clength {}
	set startpos {}

	## Run through all listed options in their order of appearance.
	foreach {option optionvalue} [dict get $schema options] {
		switch -- $option {
			-and {
				## Resets the test string for further tests.
				set teststring $data
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
					return -code error -errorcode {XJSON COMPOSER OBJECT OUT_OF_RANGE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
					return -code error -errorcode {XJSON COMPOSER OBJECT OUT_OF_RANGE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
					return -code error -errorcode {XJSON COMPOSER OBJECT TYPE_MISMATCH} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
					return -code error -errorcode {XJSON COMPOSER OBJECT NO_MATCH} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
					return -code error -errorcode {XJSON COMPOSER OBJECT OUT_OF_RANGE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
					return -code error -errorcode {XJSON COMPOSER OBJECT OUT_OF_RANGE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"needle position " [_printValue $position] " is " $comparison [_printValue $optionvalue] "."]
				}
			}
			-multipleof {
				## Do the divider check against the string length.
				if {[string length $teststring] % $optionvalue != 0} {
					return -code error -errorcode {XJSON COMPOSER OBJECT NOT_A_MULTIPLE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The test string " [_printValue $teststring] " " \
							"length " [_printValue [string length $teststring]] " is not a multiple of " [_printValue $optionvalue] "."]
				}
			}
			-multipleofpos {
				## Do the divider check against the needle position.
				if {$position % $optionvalue != 0} {
					return -code error -errorcode {XJSON COMPOSER OBJECT NOT_A_MULTIPLE} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
					return -code error -errorcode {XJSON COMPOSER OBJECT NO_MATCH} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
					return -code error -errorcode {XJSON COMPOSER OBJECT TEST_FAILED} \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
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
	list string $data
}}


## Stringop operator composing method.
dict set ::xjson::builtinComposingMethods stringop {{schema{}
		-nocase -case
		-map|
		-range- -tolower- -totitle- -toupper-
		-trim= -trimleft= -trimright=
	} {
	## Set default values for the nocase option.
	set nocase {}

	## Set value.
	set value $data

	## Run through all listed options in their order of appearance.
	foreach {option optionvalue} [dict get $schema options] {
		switch -- $option {
			-case {
				## Switch to case-sensitive matching.
				set nocase {}
			}
			-map {
				## Manipulate the string according to the option.
				set value [string map {*}$nocase $optionvalue $value]
			}
			-nocase {
				## Switch to case-insensitive matching.
				set nocase "-nocase"
			}
			-range - -tolower - -totitle - -toupper {
				## Manipulate the string according to the option.
				set value [string [string range $option 1 end] $value [lindex $optionvalue 0] [lindex $optionvalue end]]
			}
			-trim - -trimleft - -trimright {
				## Manipulate the string according to the option.
				set value [string [string range $option 1 end] $value {*}$optionvalue]
			}
		}
	}

	## Compose value from data according to schema.
	_compose $value [dict get $schema arguments schema] [string cat $path [dict get $schema method] "/"] $interpreter {}
}}


## Switch operator composing method.
dict set ::xjson::builtinComposingMethods switch {{schemas{|} else{} null{}} {
	## Run through the alternative schemas.
	set errors {}
	set nulls 0
	set index 0
	foreach {test then} [dict get $schema arguments schemas] {
		## Evaluate the data by the test schema.
		if {![catch {_compose $data $test [string cat $path [dict get $schema method] ":test#" $index "/"] $interpreter {}} composed]} {
			## No error. Evaluate the then schema with the previous result.
			if {[catch {_compose $data $then [string cat $path [dict get $schema method] ":then#" $index "/"] $interpreter [list $composed]} composed]} {
				## Escalate the error, if any.
				return -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed
			}

			## Otherwise return the result.
			return $composed
		}

		## Remember error messages.
		lappend errors $composed

		## Check for null.
		if {$::errorCode eq {XJSON COMPOSER OBJECT IS_NULL}} {
			## Increase the number of nulls found.
			incr nulls
		}

		## Next pair.
		incr index
	}

	## Check if all test schemas returned null.
	if {$nulls == $index} {
		## Yes. Evaluate the null schema.
		_compose $data [dict get $schema arguments null] [string cat $path [dict get $schema method] ":null/"] $interpreter \
			[list -code error -errorcode {XJSON COMPOSER OBJECT IS_NULL} \
				[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"Null is reported by all of the listed subschemas:" [_printErrors $errors]]]
	} else {
		## No. Evaluate the else schema.
		_compose $data [dict get $schema arguments else] [string cat $path [dict get $schema method] ":else/"] $interpreter \
			[list -code error -errorcode {XJSON COMPOSER OBJECT ALTERNATIVES_MISMATCH} \
				[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
					"It does not match any of the listed subschemas:" [_printErrors $errors]]]
	}
}}
