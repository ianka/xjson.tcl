package ifneeded xjson 1.1.1 [subst -nocommands {
	source [file join $dir xjson.tcl]
	source [file join $dir utilities.tcl]
	source [file join $dir makeCollectorClass.tcl]
	source [file join $dir builtinCollectingMethods.tcl]
	source [file join $dir decode.tcl]
	source [file join $dir makeComposerClass.tcl]
	source [file join $dir builtinComposingMethods.tcl]
	source [file join $dir encode.tcl]
	package provide xjson 1.1.1
}]
