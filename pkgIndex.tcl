package ifneeded xjson 1.5 [subst -nocommands {
	source [file join $dir xjson.tcl]
	source [file join $dir utilities.tcl]
	source [file join $dir decode.tcl]
	source [file join $dir encode.tcl]
	source [file join $dir recode.tcl]
	source [file join $dir diff.tcl]
	source [file join $dir patch.tcl]
	source [file join $dir makeCollectorClass.tcl]
	source [file join $dir builtinCollectingMethods.tcl]
	source [file join $dir makeComposerClass.tcl]
	source [file join $dir builtinComposingMethods.tcl]
	package provide xjson 1.5
}]
