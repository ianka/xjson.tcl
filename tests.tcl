#!/usr/bin/tclsh
##
## tests.tcl - a test script for xjson.tcl
##

set auto_path [linsert $auto_path 0 .]

package require xjson
package require yaml

## Set default timezone.
set env(TZ) ":UTC"

## Helper procs.
proc underline {string char} {
	return $string\n[string repeat $char [string length $string]]
}

set log {}
proc log {string} {
	lappend ::log $string
}

proc lflush {} {
	puts [join $::log \n]
	set ::log {}
}

proc ldrop {} {
	set ::log {}
}


## Do one test.
proc test {operation test} {
	## Do the test.
	switch -- $operation {
		encode - decode - recode {
			::xjson::$operation [dict get $test data]
		}
		diff {
			::xjson::$operation [dict get $test odata] [dict get $test ndata]
		}
		patch - rpatch {
			::xjson::$operation [dict get $test data] [dict get $test patch]
		}
		makeCollectorClass - makeComposerClass {
			::xjson::$operation {*}[dict get $test fparams]
		}
		testCollectorClass - testComposerClass {
			set class [::xjson::[regsub -- "^test" $operation "make"] {*}[dict get $test fparams]]
			try {
				$class {*}[dict get $test cparams]
			} finally {
				::itcl::delete class $class
			}
		}
		printCollectorSchema - printComposerSchema {
			set class [::xjson::[regsub -- "^print(.*)Schema" $operation "make\\1Class"] {*}[dict get $test fparams]]
			try {
				set object [$class {*}[dict get $test cparams] [dict get $test schema]]
				try {
					set result [$object printSchema {*}[dict get $test mparams]]
				} finally {
					::itcl::delete object $object
				}
			} finally {
				::itcl::delete class $class
			}
			return $result
		}
		collect - compose {
			set class [::xjson::make[dict get {collect Collector compose Composer} $operation]Class ::testClass]
			try {
				set object [$class ::testObject -trusted -init {set ::schemasandbox {}} [dict get $test schema]]
				try {
					set result [$object $operation [dict get $test data]]
				} finally {
					::itcl::delete object $object
				}
			} finally {
				::itcl::delete class $class
			}
			return $result
		}
		initCollect - initCompose {
			set class [::xjson::make[dict get {initCollect Collector initCompose Composer} $operation]Class ::testClass]
			try {
				set object [$class ::testObject -trusted -init [dict get $test init] [dict get $test schema]]
				try {
					set result [$object [dict get {initCollect collect initCompose compose} $operation] [dict get $test data]]
				} finally {
					::itcl::delete object $object
				}
			} finally {
				::itcl::delete class $class
			}
			return $result
		}
		nestedCollect - nestedCompose {
			set class [::xjson::make[dict get {nestedCollect Collector nestedCompose Composer} $operation]Class {*}[dict get $test fparams]]
			try {
				set nestedobject [$class ::nestedObject -trusted [dict get $test nestedschema]]
				try {
					set object [$class ::testObject [dict get $test nestedname] $nestedobject [dict get $test schema]]
					try {
						set result [$object [dict get {nestedCollect collect nestedCompose compose} $operation] [dict get $test data]]
					} finally {
						::itcl::delete object $object
					}
				} finally {
					::itcl::delete object $nestedobject
				}
			} finally {
				::itcl::delete class $class
			}
			return $result
		}
	}
}


## Report a passed test.
proc passedTest {test} {
	log "[format %3d $::counter]: \[passed\] [dict get $test name] ([dict get $test desc])"
	incr ::passed
}


## Report a failed test.
proc failedTest {test result} {
	log "[format %3d $::counter]: \[failed\] [dict get $test name] ([dict get $test desc])"
	if {[dict exists $test fparams]} {
		log "Factory params: [dict get $test fparams]"
	}
	if {[dict exists $test cparams]} {
		log "Class params: [dict get $test cparams]"
	}
	if {[dict exists $test mparams]} {
		log "Method params: [dict get $test mparams]"
	}
	if {[dict exists $test schema]} {
		log "Schema: [dict get $test schema]"
	}
	if {[dict exists $test data]} {
		log "Data: [dict get $test data]"
	}
	if {[dict exists $test odata]} {
		log "Old data: [dict get $test odata]"
	}
	if {[dict exists $test ndata]} {
		log "New data: [dict get $test ndata]"
	}
	if {[dict exists $test patch]} {
		log "Patch: [dict get $test patch]"
	}
	log "Expected: \"[string map {" " "."} [dict get $test expected]]\""
	log "Result:   \"[string map {" " "."} $result]\""
}


## Report a passed or failed test.
proc checkTestResult {test result} {
	## Check error code result.
	if {$result eq [dict get $test expected]} {
		## Passed.
		passedTest $test
	} else {
		## Failed test due to unexpected result.
		failedTest $test $result
		puts stderr $::errorInfo
	}
}


## Do the tests of a single test file.
proc testFile {name} {
	set fd [open $name r]

	## Load test content.
	set tests [::yaml::yaml2dict [read $fd]]

	## Print overview when all tests should be performed.
	log \n[underline "Test file $name:" =]\n[dict get $tests overview]\n

	## Go through all tests.
	set lflush false
	foreach test [dict get $tests tests] {
		## Increment test counter
		incr ::counter

		## Ignore test if a special test number should be performed and this isn't it.
		if {$::selected ne {} && $::counter ni $::selected} continue

		## Flush log later.
		set lflush true

		## Do the test.
		if {[dict exists $tests testerror] && [dict get $tests testerror]} {
			## Test for error code or log.
			if {![catch {test [dict get $tests operation] $test} result]} {
				## Failed test due to no error.
				failedTest $test $result
			} else {
				if {[dict exists $tests testcode] && [dict get $tests testcode]} {
					## Compare error code.
					checkTestResult $test $::errorCode
				} else {
					## Compare error message.
					checkTestResult $test $result
				}
			}
		} else {
			## Test for return value.
			if {[catch {test [dict get $tests operation] $test} result]} {
				## Failed test due to error.
				failedTest $test $result
			} else {
				## No error. Check result.
				checkTestResult $test $result
			}
		}
	}

	## Flush log if the was a test selected in this file. Otherwise drop log.
	if {$lflush} lflush else ldrop

	close $fd
}


## Get the test ranges and files from argv.
set files {}
set selected {}
foreach arg $argv {
	if {[string is integer -strict $arg]} {
		lappend selected $arg
	} elseif {[regexp {([[:digit:]]+)-([[:digit:]]+)} $arg match start end]} {
		for {set i $start} {$i <= $end} {incr i} {
			lappend selected $i
		}
	} else {
		lappend files $arg
	}
}

## Test all files if no files are mentioned.
if {$files eq {}} {
	set files [lsort [glob [file join tests *.yml]]]
}

## Go trough all tests.
set counter 0
set passed 0
foreach filename $files {
	testFile $filename
}

log "\n[underline "Result:" =]\n$passed [expr {$selected ne {}?"of [llength $selected] selected ":""}](of $counter) tests passed."
lflush
