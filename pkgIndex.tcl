package ifneeded xjson 1.12 [list apply {dir {
	foreach file {
		xjson.tcl
		utilities.tcl
		decode.tcl
		encode.tcl
		recode.tcl
		diff.tcl
		patch.tcl
		makeCollectorClass.tcl
		builtinCollectingMethods.tcl
		makeComposerClass.tcl
		builtinComposingMethods.tcl
	} {
		uplevel #0 [list source [file join $dir $file]]
	}
	package provide xjson 1.12
}} $dir]
