##
## xjson - extended JSON functions for tcl
##
## Utility procedures.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2021 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Print an amount inside an error message.
proc ::xjson::_printAmount {value unit} {
	## Put single digits as words.
	if {[catch {dict get [dict create {*}{
			0 zero 1 one 2 two 3 three 4 four 5 five 6 six 7 seven 8 eight 9 nine 10 ten 11 eleven 12 twelve}] $value} name]} {
		set name $value
	}

	## Return name, unit, and plural ending if it applies.
	string cat $name " " $unit [expr {$value!=1?"s":""}]
}


## Print decoded JSON data inside an error message.
proc ::xjson::_printJsonData {data tabulator maxlines} {
	## Encode data for presentation.
	if {[catch {::xjson::encode $data 0 $tabulator 0} json]} {
		## Encoding failed. Use raw data instead.
		set json $data
	}

	## Split into lines.
	set lines [split $json "\n"]

	## Check output length, and if it should be shortened.
	if {[string is entier -strict $maxlines] && [llength $lines]>$maxlines} {
		## Yes. Join the first lines, a marker, and the last lines.
		string cat "\"" [join [concat \
			[lrange $lines 0 [expr {$maxlines/2}]] \
			"..." \
			[lrange $lines end-[expr {$maxlines/2}] end]] "\n" ] "\""
	} else {
		## No. Rejoin lines.
		string cat "\"" [join $lines "\n"] "\""
	}
}


## Print Tcl data inside an error message.
proc ::xjson::_printTclData {data tabulator maxlines} {
	## Split into lines.
	set lines [split $data "\n"]

	## Check output length, and if it should be shortened.
	if {[string is entier -strict $maxlines] && [llength $lines]>$maxlines} {
		## Yes. Join the first lines, a marker, and the last lines.
		join [concat \
			[lrange $lines 0 [expr {$maxlines/2}]] \
			"..." \
			[lrange $lines end-[expr {$maxlines/2}] end]] "\n"
	} else {
		## No. Print short data.
		::xjson::_printValue $data
	}
}



## Print a value inside an error message.
proc ::xjson::_printValue {value} {
	## Check if the value has to be marshalled the Tcl way.
	if {[list $value] ne $value} {
		## Yes. Return it marshalled.
		list $value
	} else {
		## No. Return it in verbatim if it is a number, otherwise in quotes.
		if {[string is entier -strict $value]
			|| [string is double -strict $value]} {
			set value
		} else {
			string cat "\"" $value "\""
		}
	}
}


## Print a raw schema left trimmed. This proc is called when printing
## error messages while parsing the raw schema.
proc ::xjson::_printLeftTrimmed {rawschema tabulator} {
	## Remove line breaks from the beginning and all whitespace from the end of the raw schema.
	set rs [string trimright [string trimleft $rawschema "\n"]]

	## Determine the whitespace at the beginning of first line.
	regexp -- {^[[:space:]]*} $rs cws

	## Run through all lines and format output.
	string cat "{" [join [lmap line [split $rs "\n"] {
		## Remove the common whitespace from each line.
		set l [regsub -- [string cat ^ $cws] $line {}]

		## Replace extra tabulators with configured tabulators.
		regexp -- {^\t*} $l tabs
		regsub -- [string cat ^ $tabs] $l [string repeat $tabulator [string length $tabs]]
	}] "\n"] "}"
}


## Print the parsed schema. This recursive proc is called
## when printing error messages data.
proc ::xjson::_printNestedSchema {parsedschema indent nest tabulator maxdepth maxweight maxldepth methods} {
	## Skip empty schema.
	if {$parsedschema eq {}} {
		return
	}

	## Get method from parsed schema.
	set method [dict get $parsedschema method]

	## Indent if not nested.
	if {$nest == 0} {
		set result [string repeat $tabulator $indent]
	}

	## Add method.
	append result $method

	## Add options.
	foreach {option optionvalue} [dict get $parsedschema options] {
		if {$option in [dict get $methods $method simpleOptions]} {
			## Add option.
			append result " " $option
		} else {
			## Add option with value.
			append result " " $option " " [::xjson::_printValue $optionvalue]
		}
	}

	## Add end of options marker if the first argument starts with a -.
	if {[string index [lindex [dict values [dict get $parsedschema arguments]] 0] 0] eq "-"} {
		append result " --"
	}

	## Append arguments.
	foreach {argname argvalue} [dict get $parsedschema arguments] {
		## Put a space in front of each argument.
		append result " "

		## Tell apart different kinds of arguments.
		if {$argname in [dict get $methods $method schemaArguments]} {
			## Single subschema argument.
			## Select output format by line depth.
			if {[string is entier -strict $maxldepth] && [dict get $parsedschema ldepth] > $maxldepth} {
				## High weight. Make it a multi-lined format.
				## Append the argument line.
				append result "{" "\n" [string repeat $tabulator [expr {$indent+1}]] \
					{*}[::xjson::_printNestedSchema $argvalue [expr {$indent+1}] [expr {$nest+1}] $tabulator $maxdepth $maxweight $maxldepth $methods] "}"
			} else {
				## Low weight. Append the argument line.
				append result [::xjson::_printNestedSchema $argvalue $indent [expr {$nest+1}] $tabulator $maxdepth $maxweight $maxldepth $methods]
			}
		} elseif {$argname in [dict get $methods $method schemaListArguments]} {
			## List of subschemas argument.
			## Select output format by weight.
			if {[string is entier -strict $maxweight] && [dict get $parsedschema weight] > $maxweight} {
				## High weight. Make it a multi-lined format.
				## Format the lines of the argument.
				set lines {}
				foreach element $argvalue {
					lappend lines [string cat [string repeat $tabulator [expr {$indent+1}]] \
						[::xjson::_printNestedSchema $element [expr {$indent+1}] [expr {$nest+1}] $tabulator $maxdepth $maxweight $maxldepth $methods]]
				}

				## Append the argument lines.
				append result "{" "\n" [join $lines "\n"] "\n" [string repeat $tabulator $indent] "}"
			} else {
				## Low weight. Put it all on one line.
				set line {}
				foreach element $argvalue {
					lappend line [::xjson::_printNestedSchema $element $indent [expr {$nest+1}] $tabulator $maxdepth $maxweight $maxldepth $methods]
				}

				## Append the argument line.
				append result "{" [join $line] "}"
			}
		} elseif {$argname in [dict get $methods $method schemaPairArguments]} {
			## Pairs of subschemas argument.
			## Format the lines of the argument.
			set lines {}
			foreach {lelement relement} $argvalue {
				lappend lines [string cat [string repeat $tabulator [expr {$indent+1}]] \
					[::xjson::_printNestedSchema $lelement [expr {$indent+1}] [expr {$nest+1}] $tabulator $maxdepth $maxweight $maxldepth $methods] " " \
					[::xjson::_printNestedSchema $relement [expr {$indent+1}] [expr {$nest+1}] $tabulator $maxdepth $maxweight $maxldepth $methods]]
			}

			## Append the argument lines.
			append result "{" "\n" [join $lines "\n"] "\n" [string repeat $tabulator $indent] "}"
		} elseif {$argname in [dict get $methods $method schemaDictArguments]} {
			## Dict of subschemas argument.
			## Get the length of the longest key string for value indentation.
			set keylength [::tcl::mathfunc::max 0 {*}[lmap {key element} $argvalue {string length $key}]]
			incr keylength +2

			## Format the lines of the argument.
			set lines {}
			dict for {key element} $argvalue {
				lappend lines [string cat [string repeat $tabulator [expr {$indent+1}]] "\"" \
					[format "%-${keylength}s" [string cat $key "\""]] \
					[::xjson::_printNestedSchema $element [expr {$indent+1}] [expr {$nest+1}] $tabulator $maxdepth $maxweight $maxldepth $methods]]
			}

			## Append the argument lines.
			append result "{" "\n" [join $lines "\n"] "\n" [string repeat $tabulator $indent] "}"
		} else {
			## Normal argument.
			append result [::xjson::_printValue $argvalue]
		}
	}

	## Return result.
	list $result
}


## Wrapper procedure for _printNestedSchema.
proc ::xjson::_printSchema {parsedschema indent tabulator maxdepth maxweight maxldepth methods} {
	set result [string cat [string repeat $tabulator $indent] [::xjson::_printNestedSchema $parsedschema $indent 1 $tabulator $maxdepth $maxweight $maxldepth $methods]]
	if {[list $result] eq $result} {
		string cat "\"" $result "\""
	} else {
		return $result
	}
}


## Throw an error on a failed constraint.
proc ::xjson::_failedMethodConstraint {schema path type name value tabulator constraint message} {
	return -code error -errorcode [list XJSON SCHEMA [string toupper $type] $constraint] \
		[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
			$type " " [::xjson::_printValue $name] " value " [::xjson::_printValue $value] " " \
			$message "."]
}


## Check some common constraints on the arguments and options of methods.
proc ::xjson::_checkMethodConstraints {method schema path dubious type name value tabulator methods} {
	## Check for integer constraint if there was one given.
	if {$name in [dict get $methods $method integer[string toupper $type 0]s]
		&& ![string is entier -strict $value]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				TYPE_MISMATCH "is not an integer"
	}

	## Check for list of integers constraint if there was one given.
	if {$name in [dict get $methods $method integerList[string toupper $type 0]s]} {
		foreach v $value {
			if {![string is entier -strict $v]} {
				::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
					TYPE_MISMATCH "is not a list of integers"
			}
		}
	}

	## Check for number constraint if there was one given.
	if {$name in [dict get $methods $method number[string toupper $type 0]s]
		&& ![string is double -strict $value]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				TYPE_MISMATCH "is not a number"
	}

	## Check for regexp constraint if there was one given.
	if {$name in [dict get $methods $method regexp[string toupper $type 0]s]
		&& [catch {regexp -- $value {}} result]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				TYPE_MISMATCH [string cat "is not a valid regexp: " $result]
	}

	## Check for format constraint if there was one given.
	if {$name in [dict get $methods $method format[string toupper $type 0]s]
		&& [catch {format $value {}} result]} {
			## Only throw an error on bad type specifiers.
			## Ignore other errors, as we don't have data yet.
			if {$::errorCode eq {TCL FORMAT BADTYPE}} {
				::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
					TYPE_MISMATCH [string cat "is not a valid format: " $result]
			}
	}

	## Check for boundary constraint if there was one given.
	if {[dict exists [dict get $methods $method compare[string toupper $type 0]s] $name]} {
		if [subst {$value [dict get [dict get $methods $method compare[string toupper $type 0]s] $name]}] {} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				BOUNDARY_MISMATCH [string cat "is not " [dict get [dict get $methods $method compare[string toupper $type 0]s] $name]]
		}
	}

	## Check for string index constraint if there was one given.
	if {$name in [dict get $methods $method index[string toupper $type 0]s]
		&& [catch {string index {} $value}]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				INDEX_MISMATCH "is not a valid string index"
	}

	## Check for string index range constraint if there was one given.
	if {$name in [dict get $methods $method range[string toupper $type 0]s]
		&& [catch {string toupper {} {*}$value}]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				RANGE_MISMATCH "is not a valid string index range"
	}

	## Check for balance constraint if there was one given.
	if {$name in [dict get $methods $method pair[string toupper $type 0]s]
		&& [llength $value]%2 != 0} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				PAIRS_MISMATCH "is not a balanced list"
	}

	## Check for dict constraint if there was one given.
	if {$name in [dict get $methods $method dict[string toupper $type 0]s]} {
		if {[catch {dict create {*}$value} result]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				DICT_MISMATCH "is not a dict"
		} elseif {[llength $optionvalue] ne [llength $result]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				DICT_MISMATCH "has non-unique keys"
		}
	}

	## Check for string against regexp constraint if there was one given.
	if {[dict exists [dict get $methods $method regexpTest[string toupper $type 0]s] $name]} {
		if {![regexp [dict get [dict get $methods $method regexpTest[string toupper $type 0]s] $name] $value]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				REGEXP_MISMATCH [string cat "does not match regular expression " \
					[::xjson::_printValue [dict get [dict get $methods $method regexpTest[string toupper $type 0]s] $name]]]]
		}
	}

	## Check for code constraint if there was one given.
	if {$dubious && $name in [dict get $methods $method code[string toupper $type 0]s]} {
		::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
			CODE_FORBIDDEN "specifies Tcl code, which is forbidden in this object"
	}

	## Check for timezone constraint if there was one given.
	if {$name in [dict get $methods $method timezone[string toupper $type 0]s]
		&& [catch {clock format 0 -timezone $value}]} {
			::xjson::_failedMethodConstraint $schema $path $type $name $value $tabulator \
				TIMEZONE_MISMATCH "is not a valid timezone"
	}
}


## Parse and test the schema before installing it. This recursive proc is called in the constructor.
proc ::xjson::_parseSchema {schema dubious path depth ldepth weight tabulator methods} {
	## Assume an empty schema to be a null schema.
	if {$schema eq {}} {
		set schema {null}
	}

	## Get method from schema.
	set method [lindex $schema 0]

	## Fail if this method isn't registered.
	if {![dict exists $methods $method]} {
		return -code error -errorcode {XJSON SCHEMA UNKNOWN_METHOD} \
			[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
				"method " [::xjson::_printValue $method] " is unknown to this class."]
	}

	## Forbid potentially harmful methods (e.g. those that can execute arbitrary Tcl code)
	## if the schema is from a dubious source.
	if {$dubious && "-unsafe" in [dict get $methods $method generalOptions]} {
		return -code error -errorcode {XJSON SCHEMA UNSAFE_METHOD} \
			[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
				"method " [::xjson::_printValue $method] " is forbidden for schemas from dubious sources."]
	}

	## Set dubious marker if this is an operator working on dubious schemas.
	if {"-dubious" in [dict get $methods $method generalOptions]} {
		set dubious true
	}

	## Get option and argument names from method definition.
	set argnames             [dict get $methods $method parameterArguments]
	set simpleOptionNames    [dict get $methods $method simpleOptions]
	set parameterOptionNames [dict get $methods $method parameterOptions]

	## Run through the schema and sort out the method's options and arguments.
	set options {}
	set argvalues {}
	for {set index 1} {$index < [llength $schema]} {incr index} {
		## Get element.
		set element [lindex $schema $index]

		## Check for end of option processing.
		if {$element eq "--"} {
			## All the remaining elements are arguments.
			lappend argvalues {*}[lrange $schema $index+1 end]
			break
		}

		## Check for a non-option.
		if {[string index $element 0] ne "-"} {
			## This and all the remaining elements are arguments.
			lappend argvalues {*}[lrange $schema $index end]
			break
		}

		## Remember element as an option with value true if it is in the list of simple options.
		if {$element in $simpleOptionNames} {
			lappend options $element true
			continue
		}

		## Remember element as an option with its given value if it is in the list of parameter options.
		if {$element in $parameterOptionNames} {
			## Move on to option parameter.
			incr index

			## Fail if the index is beyond the length of the schema.
			if {$index == [llength $schema]} {
				return -code error -errorcode {XJSON SCHEMA WRONGARGS} \
					[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
						"method " [::xjson::_printValue $method] " option " [::xjson::_printValue $element] " needs a parameter."]
			}

			## Remember.
			lappend options $element [lindex $schema $index]
			continue
		}

		## Fail.
		return -code error -errorcode {XJSON SCHEMA UNKNOWN_OPTION} \
			[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
				"method " [::xjson::_printValue $method] " does not take the option " [::xjson::_printValue $element] "."]
	}

	## Do additional checks on options.
	foreach {name value} $options {
		::xjson::_checkMethodConstraints $method $schema $path $dubious option $name $value $tabulator $methods
	}

	## Fail if the argument count doesn't match.
	if {[llength $argnames] != [llength $argvalues]} {
		return -code error -errorcode {XJSON SCHEMA WRONGARGS} \
			[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
				"specifies " [::xjson::_printAmount [llength $argvalues] "argument"] ", " \
				"when it should be " [::xjson::_printAmount [llength $argnames] "argument"] " meant as " [::xjson::_printValue $argnames] "."]
	}

	## Do additional checks on arguments.
	foreach name $argnames value $argvalues {
		::xjson::_checkMethodConstraints $method $schema $path $dubious argument $name $value $tabulator $methods
	}

	## Start with the inherited depth, ldepth, weight.
	set resultdepth $depth
	set resultldepth $ldepth
	set resultweight $weight

	## Run through all schema options and traverse the schema tree.
	## Calculate depth and weight from each level as well.
	foreach {name value} $options {
		if {$name in [dict get $methods $method schemaOptions]} {
			## Single subschema.
			set parsedschema [::xjson::_parseSchema $value $dubious [string cat $path $method "/"] $depth $ldepth $weight $tabulator $methods]
			dict set options $name $parsedschema

			## Adjust depth.
			set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

			## Adjust line depth.
			set resultldepth [::tcl::mathfunc::max $resultldepth [dict get $parsedschema ldepth]]

			## Adjust weight.
			incr resultweight [dict get $parsedschema weight]
		} elseif {$name in [dict get $methods $method schemaListOptions]} {
			## List of subschemas option.
			dict set options $name {}
			set index 0
			foreach element $value {
				## Parse the subschema.
				set parsedschema [::xjson::_parseSchema $element $dubious [string cat $path $method "#" $index "/"] $depth $ldepth $weight $tabulator $methods]
				dict lappend options $name $parsedschema

				## Adjust depth.
				set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

				## Adjust weight.
				incr resultweight [dict get $parsedschema weight]

				## Next element.
				incr index
			}
		} elseif {$name in [dict get $methods $method schemaPairOptions]} {
			## Pairs of subschemas option.
			## Fail if not pairs.
			if {[llength $value]%2 != 0} {
				return -code error -errorcode {XJSON SCHEMA WRONGARGS} \
					[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
						"Schema option " [_printValue $name] " isn't a list of pairs."]
			}

			## Go through all elements.
			dict set options $name {}
			set index 0
			foreach {lelement relement} $value {
				## Parse the left subschema.
				set parsedschema [::xjson::_parseSchema $lelement $dubious [string cat $path $method "<" $index "/"] $depth $ldepth $weight $tabulator $methods]
				dict lappend options $name $parsedschema

				## Adjust result depth.
				set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

				## Adjust weight.
				incr resultweight [dict get $parsedschema weight]

				## Parse the right subschema.
				set parsedschema [::xjson::_parseSchema $relement $dubious [string cat $path $method ">" $index "/"] $depth $ldepth $weight $tabulator $methods]
				dict lappend arguments $name $parsedschema

				## Adjust result depth.
				set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

				## Adjust weight.
				incr resultweight [dict get $parsedschema weight]

				## Next pair.
				incr index
			}
		} elseif {$name in [dict get $methods $method schemaDictOptions]} {
			## Dict of subschemas option.
			## Fail if not a dict.
			if {[llength $value]%2 != 0} {
				return -code error -errorcode {XJSON SCHEMA WRONGARGS} \
					[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
						"Schema option " [_printValue $name] " isn't a dict."]
			}

			## Go through all elements.
			dict set options $name {}
			foreach {key element} $value {
				## Fail on fields listed multiple times.
				if {[dict exists $options $name $key]} {
					return -code error -errorcode {XJSON SCHEMA AMBIGUOUS_FIELD} \
						[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
							"Schema option " [_printValue $name] " key " [_printValue $key] " is listed multiple times."]
				}

				## Remember subschema for that key.
				set parsedschema [::xjson::_parseSchema $element $dubious [string cat $path $method ":" $key "/"] $depth $ldepth $weight $tabulator $methods]
				dict set options $name $key $parsedschema

				## Adjust result depth.
				set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

				## Adjust weight.
				incr resultweight [dict get $parsedschema weight]
			}
		} else {
			## Not a schema. Keep option as it was.
		}
	}

	## Run through all arguments and traverse the schema tree.
	## Calculate depth and weight from each level as well.
	set arguments [dict create]
	foreach name $argnames value $argvalues {
		if {$name in [dict get $methods $method schemaArguments]} {
			## Single subschema argument.
			set parsedschema [::xjson::_parseSchema $value $dubious [string cat $path $method "/"] $depth $ldepth $weight $tabulator $methods]
			dict set arguments $name $parsedschema

			## Adjust depth.
			set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

			## Adjust line depth.
			set resultldepth [::tcl::mathfunc::max $resultldepth [dict get $parsedschema ldepth]]

			## Adjust weight.
			incr resultweight [dict get $parsedschema weight]
		} elseif {$name in [dict get $methods $method schemaListArguments]} {
			## List of subschemas argument.
			dict set arguments $name {}
			set index 0
			foreach element $value {
				## Parse the subschema.
				set parsedschema [::xjson::_parseSchema $element $dubious [string cat $path $method "#" $index "/"] $depth $ldepth $weight $tabulator $methods]
				dict lappend arguments $name $parsedschema

				## Adjust depth.
				set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

				## Adjust weight.
				incr resultweight [dict get $parsedschema weight]

				## Next element.
				incr index
			}
		} elseif {$name in [dict get $methods $method schemaPairArguments]} {
			## Pairs of subschemas argument.
			## Fail if not pairs.
			if {[llength $value]%2 != 0} {
				return -code error -errorcode {XJSON SCHEMA WRONGARGS} \
					[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
						"Schema argument " [_printValue $name] " isn't a list of pairs."]
			}

			## Go through all elements.
			dict set arguments $name {}
			set index 0
			foreach {lelement relement} $value {
				## Parse the left subschema.
				set parsedschema [::xjson::_parseSchema $lelement $dubious [string cat $path $method "<" $index "/"] $depth $ldepth $weight $tabulator $methods]
				dict lappend arguments $name $parsedschema

				## Adjust result depth.
				set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

				## Adjust weight.
				incr resultweight [dict get $parsedschema weight]

				## Parse the right subschema.
				set parsedschema [::xjson::_parseSchema $relement $dubious [string cat $path $method ">" $index "/"] $depth $ldepth $weight $tabulator $methods]
				dict lappend arguments $name $parsedschema

				## Adjust result depth.
				set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

				## Adjust weight.
				incr resultweight [dict get $parsedschema weight]

				## Next pair.
				incr index
			}
		} elseif {$name in [dict get $methods $method schemaDictArguments]} {
			## Dict of subschemas argument.
			## Fail if not a dict.
			if {[llength $value]%2 != 0} {
				return -code error -errorcode {XJSON SCHEMA WRONGARGS} \
					[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
						"Schema argument " [_printValue $name] " isn't a dict."]
			}

			## Go through all elements.
			dict set arguments $name {}
			foreach {key element} $value {
				## Fail on fields listed multiple times.
				if {[dict exists $arguments $name $key]} {
					return -code error -errorcode {XJSON SCHEMA AMBIGUOUS_FIELD} \
						[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
							"Schema argument " [_printValue $name] " key " [_printValue $key] " is listed multiple times."]
				}

				## Remember subschema for that key.
				set parsedschema [::xjson::_parseSchema $element $dubious [string cat $path $method ":" $key "/"] $depth $ldepth $weight $tabulator $methods]
				dict set arguments $name $key $parsedschema

				## Adjust result depth.
				set resultdepth [::tcl::mathfunc::max $resultdepth [dict get $parsedschema depth]]

				## Adjust weight.
				incr resultweight [dict get $parsedschema weight]
			}
		} else {
			## Not a schema.
			dict set arguments $name $value
		}
	}

	## Increment depth.
	incr resultdepth

	## Increment line depth.
	incr resultldepth

	## Increment weight.
	incr resultweight

	## Return result dict.
	dict create method $method depth $resultdepth ldepth $resultldepth weight $resultweight options $options arguments $arguments
}


## Automatic sandboxing.
proc ::xjson::_sandbox {data schema path interpreter script isolate tabulator recursionlimit} {
	## Fail if the interpreter given does not exist at runtime.
	if {[catch {interp issafe $interpreter} issafe]} {
		return -code error -errorcode {XJSON SCHEMA BAD_INTERPRETER} \
			[string cat "invalid schema " [::xjson::_printLeftTrimmed $schema $tabulator] " at " $path "\n" \
				"The interpreter " [::xjson::_printValue $interpreter] " does not exist."]
	}

	## Use the given interpreter if it is safe, and we should not isolate.
	if {$issafe && !$isolate} {
		set localInterpreter $interpreter
	} else {
		## Otherwise create a local safe interpreter.
		set localInterpreter [interp create -safe]

		## Forbid recursion in that local interpreter.
		$localInterpreter recursionlimit $recursionlimit
	}

	## Evaluate the given script in the safe interpreter.
	if {[catch {$localInterpreter eval $script} result]} {
		## On error, delete the locally created interpreter.
		if {$localInterpreter ne $interpreter} {
			interp delete $localInterpreter
		}

		## Escalate the error.
		return -code error -errorcode $::errorCode -errorinfo $::errorInfo $result
	}

	## Delete the locally created interpreter.
	if {$localInterpreter ne $interpreter} {
		interp delete $localInterpreter
	}

	## Return the result.
	return $result
}


## Compile class methods from definitions.
proc ::xjson::_compileMethods {what definitions} {
	## Run through all definitions.
	set namelists {simple parameter integer integerList number regexp format compare index range pair dict regexpTest code timezone schema schemaList schemaPair schemaDict}
	set methodConsts [dict create]
	set methodScripts [dict create]

	## Compile method definitions.
	foreach {classmethod classmethoddef} $definitions {
		## Run through the method definition and sort out the options and arguments.
		set classmethodargs {}
		set classmethodoptions {}
		set argvalues {}
		for {set index 0} {$index < [llength $classmethoddef]} {incr index} {
			## Get element.
			set element [lindex $classmethoddef $index]

			## Check for end of option processing.
			if {$element eq "--"} {
				## All the remaining elements are arguments.
				lappend classmethodargs {*}[lrange $classmethoddef $index+1 end]
				break
			}

			## Check for a non-option.
			if {[string index $element 0] ne "-"} {
				## This and all the remaining elements are arguments.
				lappend classmethodargs {*}[lrange $classmethoddef $index end]
				break
			}

			## Remember element as an option with value if it is only of the recognized options.
			if {$element in {-dubious -unsafe}} {
				lappend classmethodoptions $element
				continue
			}

			## Fail.
			return -code error -errorcode [list XJSON $what FACTORY METHOD UNKNOWN_OPTION] \
				[string cat "class method definition for method \"" $classmethod "\" is bogus. " \
					"It does not take the option " [::xjson::_printValue $element] "."]
		}

		## Prepend the list of method arguments with the method name if it is an even number of elements.
		if {[llength $classmethodargs]%2 == 0} {
			set classmethodargs [linsert $classmethodargs 0 $classmethod]
		}

		## Run through all methods listed for that classmethod.
		dict for {name argsopts} [lrange $classmethodargs 0 end-1] {
			## Create argname and optionname lists.
			foreach namelist $namelists {
				set ${namelist}Arguments {}
				set ${namelist}Options {}
			}

			## Populate the option and argument lists.
			foreach argopt $argsopts {
				## Test options.
				switch -regexp -matchvar match -- $argopt {
					{^(-[[:alpha:]]+)(!=|>|<|>=|<=)([[:digit:]]+)$} {
						lappend  integerOptions [lindex $match 1]
						dict set compareOptions [lindex $match 1] [lrange $match 2 3]
					}
					{^(-[[:alpha:]]+)(!=|>|<|>=|<=)([[:digit:]]*\.[[:digit:]]+)$} {
						lappend  numberOptions  [lindex $match 1]
						dict set compareOptions [lindex $match 1] [lrange $match 2 3]
					}
					{^(-[[:alpha:]]+)=(.+)$} {dict set regexpTestOptions [lindex $match 1] [lindex $match 2]}
					{^(-[[:alpha:]]+)/$}     {lappend numberOptions      [lindex $match 1]}
					{^(-[[:alpha:]]+)#$}     {lappend integerOptions     [lindex $match 1]}
					{^(-[[:alpha:]]+)##$}    {lappend integerListOptions [lindex $match 1]}
					{^(-[[:alpha:]]+)~$}     {lappend regexpOptions      [lindex $match 1]}
					{^(-[[:alpha:]]+)%$}     {lappend formatOptions      [lindex $match 1]}
					{^(-[[:alpha:]]+)\.$}    {lappend indexOptions       [lindex $match 1]}
					{^(-[[:alpha:]]+)-$}     {lappend rangeOptions       [lindex $match 1]}
					{^(-[[:alpha:]]+)\|$}    {lappend pairOptions        [lindex $match 1]}
					{^(-[[:alpha:]]+):$}     {lappend dictOptions        [lindex $match 1]}
					{^(-[[:alpha:]]+)!$}     {lappend codeOptions        [lindex $match 1]}
					{^(-[[:alpha:]]+)'$}     {lappend timezoneOptions    [lindex $match 1]}
					{^(-[[:alpha:]]+){}$}    {lappend schemaOptions      [lindex $match 1]}
					{^(-[[:alpha:]]+){_}$}   {lappend schemaListOptions  [lindex $match 1]}
					{^(-[[:alpha:]]+){\|}$}  {lappend schemaPairOptions  [lindex $match 1]}
					{^(-[[:alpha:]]+){:}$}   {lappend schemaDictOptions  [lindex $match 1]}
					{^(-[[:alpha:]]+)=$}     {}
					{^(-[[:alpha:]]+)$}      {lappend simpleOptions      [lindex $match 1]}
					{^([[:alpha:]]+)(!=|>|<|>=|<=)([[:digit:]]+)$} {
						lappend  integerArguments [lindex $match 1]
						dict set compareArguments [lindex $match 1] [lrange $match 2 3]
					}
					{^([[:alpha:]]+)(!=|>|<|>=|<=)([[:digit:]]*\.[[:digit:]]+)$} {
						lappend  numberArguments  [lindex $match 1]
						dict set compareArguments [lindex $match 1] [lrange $match 2 3]
					}
					{^([[:alpha:]]+)=(.+)$} {dict set regexpTestArguments [lindex $match 1] [lindex $match 2]}
					{^([[:alpha:]]+)/$}     {lappend numberArguments      [lindex $match 1]}
					{^([[:alpha:]]+)#$}     {lappend integerArguments     [lindex $match 1]}
					{^([[:alpha:]]+)##$}    {lappend integerListArguments [lindex $match 1]}
					{^([[:alpha:]]+)~$}     {lappend regexpArguments      [lindex $match 1]}
					{^([[:alpha:]]+)%$}     {lappend formatArguments      [lindex $match 1]}
					{^([[:alpha:]]+)\.$}    {lappend indexArguments       [lindex $match 1]}
					{^([[:alpha:]]+)-$}     {lappend rangeArguments       [lindex $match 1]}
					{^([[:alpha:]]+)\|$}    {lappend pairArguments        [lindex $match 1]}
					{^([[:alpha:]]+):$}     {lappend dictArguments        [lindex $match 1]}
					{^([[:alpha:]]+)!$}     {lappend codeArguments        [lindex $match 1]}
					{^([[:alpha:]]+)'$}     {lappend timezoneArguments    [lindex $match 1]}
					{^([[:alpha:]]+){}$}    {lappend schemaArguments      [lindex $match 1]}
					{^([[:alpha:]]+){_}$}   {lappend schemaListArguments  [lindex $match 1]}
					{^([[:alpha:]]+){\|}$}  {lappend schemaPairArguments  [lindex $match 1]}
					{^([[:alpha:]]+){:}$}   {lappend schemaDictArguments  [lindex $match 1]}
					{^([[:alpha:]]+)$}      {}
					default {
						return -code error -errorcode [list XJSON $what FACTORY METHOD WRONGARGS] \
							[string cat "method definition \"" $name "\" for class method \"" $classmethod "\" is bogus. " \
								"Argument and option names must be pure alpha-strings. The string \"" $match "\" is not." ]
					}
				}

				## Remember as plain parameter option as well, if there is a type marker.
				if {[regexp {^(-[[:alpha:]]+)[^[:alpha:]]} $argopt match optname]} {
					lappend parameterOptions $optname
				}

				## Remember as plain argument as well.
				if {[regexp {^([[:alpha:]]+)} $argopt match argname]} {
					lappend parameterArguments $argname
				}
			}

			## Remember method.
			dict set methodConsts $name [dict create method [list {*}$classmethod] generalOptions [list {*}$classmethodoptions]]
			foreach namelist $namelists {
				## There are no "simple" args, that list is always empty. Sort it out.
				if {$namelist ne "simple"} {
					dict set methodConsts $name ${namelist}Arguments [set ${namelist}Arguments]
				}
				dict set methodConsts $name ${namelist}Options [set ${namelist}Options]
			}
		}

		## Remember method body for classbody.
		dict set methodScripts $classmethod [list protected method *$classmethod {data schema path interpreter previous} [lindex $classmethodargs end]]
	}

	## Return the results.
	list $methodScripts $methodConsts
}


## "String is" helper proc that can also test for uuids.
proc ::xjson::_stringis {is value} {
	switch -- $is {
		uuid {
			regexp -- {^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$} $value
		}
		default {
			string is $is -strict $value
		}
	}
}
