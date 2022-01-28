##
## xjson - extended JSON functions for tcl
##
## Factory for creating JSON composer classes.
##
## Written by Jan Kandziora <jjj@gmx.de>
##
## (C)2021 by Jan Kandziora <jjj@gmx.de>
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Create a class that composes JSON data acoording to a schema.
proc ::xjson::makeComposerClass {args} {
	## Run through the arguments and sort out the options and arguments.
	set options {}
	set argvalues {}
	for {set index 0} {$index < [llength $args]} {incr index} {
		## Get element.
		set element [lindex $args $index]

		## Check for end of option processing.
		if {$element eq "--"} {
			## All the remaining elements are arguments.
			lappend argvalues {*}[lrange $args $index+1 end]
			break
		}

		## Check for a non-option.
		if {[string index $element 0] ne "-"} {
			## This and all the remaining elements are arguments.
			lappend argvalues {*}[lrange $args $index end]
			break
		}

		## Remember element as an option with value true if it is in the list of simple options.
		if {$element in {-nobuiltins}} {
			lappend options $element true
			continue
		}

		## Remember element as an option with its given value if it is in the list of parameter options.
		if {$element in {-tabulator -maxldepth -maxweight -maxlines}} {
			## Move on to option parameter.
			incr index

			## Remember.
			lappend options $element [lindex $args $index]
			continue
		}

		## Fail.
		return -code error -errorcode {XJSON COMPOSER FACTORY UNKNOWN_OPTION} \
			[string cat "wrong args: should be \"::xjson::makeComposerClass ?-nobuiltins? ?-tabulator value? ?-maxldepth value? ?-maxweight value? ?-maxlines value?  ?--? className ?methodName methodDefinition ...?\""]
	}

	## Fail on missing class name.
	if {[llength $argvalues]%2!=1} {
		return -code error -errorcode {XJSON COMPOSER FACTORY WRONGARGS}
	}

	## Remember class name.
	set class [lindex $argvalues 0]

	## Start with builtin methods if not explicitely deactivated.
	if {![dict exists $options "-nobuiltins"]} {
		set definitions $::xjson::builtinComposingMethods
	} else {
		set definitions {}
	}

	## Merge user methods. Remove those builtin methods redefined as empty.
	set definitions [dict filter [dict merge $definitions [lrange $argvalues 1 end]] \
		script {k v} {expr {$v ne {}}}]

	## Compile the class methods from their definitions.
	lassign [::xjson::_compileMethods COMPOSER $definitions] methodScripts methodConsts

	## Create the class body.
	set classbody {}

	## Populate the class body with the configured methods.
	dict for {classmethod methoddef} $methodScripts {
		lappend classbody $methoddef
	}

	## Add compiled composing method definitions.
	lappend classbody [list protected common _composingMethods $methodConsts]

	## Constants for pretty printing.
	foreach {option is default} {
		-tabulator {}     "\t"
		-maxldepth entier 4
		-maxweight entier 5
		-maxlines  entier 20
	} {
		## Check if listed.
		if {[dict exists $options $option]} {
			## Listed. Check type.
			if {$is ne {} && ![string is $is [dict get $options $option]]} {
				return -code error -errorcode {XJSON COMPOSER FACTORY OPTION_TYPE_MISMATCH} \
					[string cat "wrong parameters: option \"" $option "\" must be an " $is "."]
			}

			## Use listed value.
			lappend classbody [list protected common _[string range $option 1 end] [dict get $options $option]]
		} else {
			## Use default value if not listed.
			lappend classbody [list protected common _[string range $option 1 end] $default]
		}
	}

	## Add the fixed parts to the class body.
	lappend classbody {
		## Maximum depth for pretty printing. Not used for now.
		protected common _maxdepth 0


		## Class wrappers for utility procedures.
		protected proc _printAmount {value unit} {
			::xjson::_printAmount $value $unit
		}
		protected proc _printData {data} {
			::xjson::_printTclData $data $_tabulator $_maxlines
		}
		protected proc _printValue {value} {
			::xjson::_printValue $value
		}
		protected proc _printLeftTrimmed {rawschema} {
			::xjson::_printLeftTrimmed $rawschema $_tabulator
		}
		protected proc _printSchema {parsedschema {indent 0}} {
			::xjson::_printSchema $parsedschema $indent $_tabulator $_maxdepth $_maxweight $_maxldepth $_composingMethods
		}
		protected proc _printErrors {errors} {
			string cat "\n" $_tabulator [join $errors [string cat "\n" $_tabulator]]]
		}
		protected proc _parseSchema {schema dubious {path /} {depth 0} {ldepth 0} {weight 0}} {
			::xjson::_parseSchema $schema $dubious $path $depth $ldepth $weight $_tabulator $_composingMethods
		}
		protected method _sandbox {data schema path interpreter script {isolate 0}} {
			if {[catch {::xjson::_sandbox $data $schema $path $interpreter $script $isolate $_tabulator $_recursionlimit} result]} {
				## Escalate the error in verbatim if a xjson error, otherwise add an explanatory message.
				if {[string match {XJSON *} $::errorCode]} {
					return -code error -errorcode $::errorCode -errorinfo $::errorInfo $result
				} else {
					return -code error -errorcode $::errorCode -errorinfo \
						[string cat "Tcl data " [_printData $data] " does not match schema " [_printSchema $schema] " at " $path "\n" \
							"The method " [_printValue [dict get $schema method]] " returned an error:\n\t" $::errorInfo] $result
				}
			} else {
				return $result
			}
		}


		## Nested composers registered in this object.
		protected variable _nestedComposers [dict create]


		## Sandbox default init script.
		protected variable _initscript {}

		## Sandbox minimum recursion limit as needed for the builtin functions.
		protected variable _recursionlimit 3


		## Schema that is registered in this object.
		protected variable _schema {}


		## Construct a composer object.
		constructor {args} {
			## Run through the arguments and sort out the options and arguments.
			set options {}
			set argvalues {}
			for {set index 0} {$index < [llength $args]} {incr index} {
				## Get element.
				set element [lindex $args $index]

				## Check for end of option processing.
				if {$element eq "--"} {
					## All the remaining elements are arguments.
					lappend argvalues {*}[lrange $args $index+1 end]
					break
				}

				## Check for a non-option.
				if {[string index $element 0] ne "-"} {
					## This and all the remaining elements are arguments.
					lappend argvalues {*}[lrange $args $index end]
					break
				}

				## Remember element as an option with value true if it is in the list of simple options.
				if {$element in {-trusted}} {
					lappend options $element true
					continue
				}

				## Remember element as an option with a value true if it is in the list of value options.
				if {$element in {-init -recursionlimit}} {
					## Move on to option parameter.
					incr index

					## Fail if the index is beyond the length of the args.
					if {$index == [llength $args]} {
						return -code error -errorcode {XJSON COMPOSER CLASS WRONGARGS} \
							[string cat "wrong args: should be \"" [info class] " objectName " \
								"?-trusted? ?-init body? ?-recursionlimit limit? ?--? ?nestedComposerName nestedComposerObject ...? schema\""]
					}

					## Remember.
					lappend options $element [lindex $args $index]
					continue
				}

				## Fail.
				return -code error -errorcode {XJSON COMPOSER CLASS UNKNOWN_OPTION} \
					[string cat "wrong args: should be \"" [info class] " objectName " \
						"?-trusted? ?-init body? ?-recursionlimit limit? ?--? ?nestedComposerName nestedComposerObject ...? schema\""]
			}

			## Fail if the argument length is even or if the recursionlimit isn't an integer.
			if {[llength $argvalues]%2 != 1 ||
				([dict exists $options "-recursionlimit"] && ![string is entier -strict [dict get $options "-recursionlimit"]])} {
				return -code error -errorcode {XJSON COMPOSER CLASS WRONGARGS} \
					[string cat "wrong # args: should be \"" [info class] " objectName " \
						"?-trusted? ?-init body? ?-recursionlimit limit? ?--? ?nestedComposerName nestedComposerObject ...? schema\""]
			}

			## Remember the nested composers.
			foreach {name object} [lrange $argvalues 0 end-1] {
				dict set _nestedComposers $name $object
			}

			## Remember sandbox init script.
			set _initscript [expr {[dict exists $options "-init"]?[dict get $options "-init"]:{}}]

			## Remember sandbox recursion limit.
			set _recursionlimit [::tcl::mathfunc::max $_recursionlimit [expr {[dict exists $options "-recursionlimit"]?[dict get $options "-recursionlimit"]:0}]]

			## Now parse the schema found in the last argument along with the initial dubious value.
			set _schema [_parseSchema [lindex $argvalues end] \
				[expr {![dict exists $options "-trusted"]}]]
		}


		## No specialized destructor so far.
		destructor {}


		## Compose JSON data from Tcl data.
		protected method _compose {data schema path interpreter previous} {
			## Assume an empty schema to be a null schema.
			if {$schema eq {}} {
				set schema [dict create method null depth 1 ldepth 1 weight 1 options {} arguments {}]
			}

			## Continue with the composing method in question.
			*[dict get $_composingMethods [dict get $schema method] method] $data $schema $path $interpreter $previous
		}


		## Compose JSON data from Tcl data. This wrapper method for the internal
		## [_compose] method uses the schema that is stored in this object.
		public method compose {data {path /}} {
			## Create a new safe interpreter.
			set interpreter [interp create -safe]

			## Set the recursion limit in that interpreter.
			$interpreter recursionlimit $_recursionlimit

			## Execute initialization script inside that interpreter.
			if {[catch {$interpreter eval [list apply [list {} $_initscript]]} result]} {
				## On error, delete the interpreter.
				interp delete $interpreter

				## Escalate the error.
				return -code error -errorcode $::errorCode -errorinfo $::errorInfo \
					[string cat "Compose initialization failed at " $path ":\n" $result]
			}

			## Collect data.
			if {[catch {_compose $data $_schema $path $interpreter {}} composed]} {
				## On error, delete the interpreter.
				interp delete $interpreter

				## Escalate the error.
				return -code error -errorcode $::errorCode -errorinfo $::errorInfo $composed
			}

			## Delete the interpreter.
			interp delete $interpreter

			## Return composed data.
			return $composed
		}


		## Print the schema stored in the object.
		public method printSchema {{indent 0}} {
			_printSchema $_schema $indent
		}
	}

	## Create the class.
	::itcl::class $class [join $classbody "\n"]

	## Return class name.
	return $class
}
