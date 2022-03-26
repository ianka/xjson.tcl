#!/usr/bin/tclsh
package require doctools

set data {
[manpage_begin xjson n 1.5]
[moddesc   {xjson.tcl}]
[titledesc {extended JSON functions for Tcl}]
[copyright "2021 Jan Kandziora <jjj@gmx.de>, BSD-2-Clause license"]
[keywords tcl json validation diff patch]
[require Tcl 8.6-]
[require itcl 4.0-]
[require struct::set]
[require struct::list]
[require xjson [opt 1.5]]

[usage [cmd ::xjson::decode] [arg json] [opt [arg indexVar]]]
[usage [cmd ::xjson::encode] [arg decodedJson] [opt [arg indent]] [opt [arg tabulator]] [opt [arg nest]]]
[usage [cmd ::xjson::recode] [arg decodedJson]]

[usage [cmd ::xjson::diff] [arg oldDecodedJson] [arg newDecodedJson]]
[usage [cmd ::xjson::patch] [arg decodedJson] [arg patch]]
[usage [cmd ::xjson::rpatch] [arg decodedJson] [arg patch]]

[usage [cmd ::xjson::makeCollectorClass] [opt [arg options]] [arg collectorClassName] [opt [arg {methodName methodDefinition ...}]]]
[usage [arg collectorClassName] [arg collectorObjName] [opt [arg options]] [opt [arg {nestedCollectorName nestedCollectorObjName ...}]] [arg schema]]
[usage [arg collectorObjName] [method collect] [arg decodedJson] [opt [arg path]]]
[usage [arg collectorObjName] [method printSchema] [opt [arg indent]]]

[usage [cmd ::xjson::makeComposerClass] [opt [arg options]] [arg composerClassName] [opt [arg {methodName methodDefinition ...}]]]
[usage [arg composerClassName] [arg composerObjName] [opt [arg options]] [opt [arg {nestedComposerName nestedComposerObjName ...}]] [arg schema]]
[usage [arg composerObjName] [method compose] [arg tclData] [opt [arg path]]]
[usage [arg composerObjName] [method printSchema] [opt [arg indent]]]

[description]
	This package is a set of extended JSON functions for Tcl. It allows decoding,
	encoding, and pretty-printing of JSON structures from Tcl structures and vice
	versa. In addition, decoded JSON that was created by functions outside of this
	package may be recoded. A set of diff and patch functions tailored to JSON
	allows to track changes in complicated JSON structures easily.
	[para]
	The main feature of this package however are two class factories that produce
	itcl classes that construct validator and data collector/composer objects.
	Those objects take a schema in a simple nested list syntax on construction, so
	they are then prepared for validating against that schema again and again. The
	schema may also	feature various operators that manipulate the validated data
	so that further configuration specific processing (e.g. data formatting) can
	be specified in the realm of the administrator rather than the programmer.
	[para]
	Schemas may be nested and libraries of commonly used collector/composer objects
	and	their schemas can be constructed easily.
	[para]
	The objects also feature automatic sandboxing, so they can specify Tcl code for
	doing more complicated tests or data manipulations. In addition, the programmer may
	define their own barebone, non-sandboxed methods when creating a new class with
	the class factory. For sandboxes and those methods, an additional security
	mechanism exists. Schemas may be marked as trusted (programmer/administrator
	supplied) and only such trusted schemas may use Tcl code or user-defined methods
	that are marked unsafe.
	[para]
	The procedures and objects return error messages that indicate the offending
	data and the non-matching schema in a human-readable, pretty-printed way. They
	are fit for supplying them to the interface user, which is usually a programmer
	or administrator of an another software interfacing the software using xjson.

[section BUGS]
	This manpage is intimidating. Please go right to the various [sectref "EXAMPLES"]
	sections at the bottom for maintaining a slow pulse.

[section PROCEDURES]
	The package defines the following public procedures:

	[list_begin definitions]
	[def "[cmd ::xjson::decode] [arg json] [opt [arg indexVar]]"]
		Decode the given JSON encoded data to nested Tcl data telling both types and
		values. The optional [arg indexVar] argument is the name of a variable that
		holds the index at which decoding begins and will hold the index immediately
		following the end of the decoded element. If [arg indexVar] is not specified,
		the entire JSON input is decoded, and it is an error for it to be followed by
		any non-whitespace characters.
		[para]
		See the section [sectref "DECODED JSON FORMAT"] for a description of the data
		format returned by this procedure.
		[para]
		See the section [sectref "DECODING EXAMPLES"] for examples.

	[def "[cmd ::xjson::encode] [arg decodedJson] [opt [arg indent]] [opt [arg tabulator]] [opt [arg nest]]"]
		Encode the given Tcl [arg decodedJson] data as JSON and pretty-print it with a base
		indentation as given with the optional [arg indent] argument. The likewise
		optional [arg nest] argument can be used to indicate the nesting level. If it's
		not zero, the first line of the JSON output will not be indented. This is
		useful when the first line is a brace or bracket following an already indented
		field name.
		[para]
		The pretty-printer indents with \t characters by default but this can be changed
		by setting the optional [arg tabulator] argument. If it is set to {}, the
		pretty printer is disabled completely and [cmd ::xjson::encode] returns
		condensed JSON.
		[para]
		See the section [sectref "DECODED JSON FORMAT"] for a description of the data
		format accepted by this procedure.
		[para]
		See the section [sectref "ENCODING EXAMPLES"] for examples.

	[def "[cmd ::xjson::recode] [arg decodedJson]"]
		Recode the given Tcl [arg decodedJson] data so that the included [const encoded]
		and	[const decoded] data types are replaced by their encoded and decoded
		equivalents. The other types are recoded as [cmd ::xjson::encode] followed by
		a subsequent [cmd ::xjson::decode] would do it. This may be used to	check data
		coming from sources outside of this library for syntatic correctness as well as
		for feeding it into a collector class.
		[para]
		[emph "Note:"] This function is basically a very lightweight alternative to
		[example_begin]
		% ::xjson::decode [lb]::xjson::encode [arg decodedJson][rb]
		[example_end]
		See the section [sectref "DECODED JSON FORMAT"] for a description of the data
		format accepted and produced by this procedure.
		[para]
		See the section [sectref "RECODING EXAMPLES"] for examples.


	[def "[cmd ::xjson::diff] [arg oldDecodedJson] [arg newDecodedJson]"]
		Compare the given Tcl [arg oldDecodedJson] and [arg newDecodedJson] data and
		produce a [arg patch] suitable for the [cmd ::xjson::patch] and
		[cmd ::xjson::rpatch] procedures.
		[para]
		See the section [sectref "DECODED JSON FORMAT"] for a description of the data
		format accepted by this procedure.
		See the section [sectref "JSON PATCH FORMAT"] for a description of the data
		format returned by this procedure.
		[para]
		See the section [sectref "DIFF EXAMPLES"] for examples.

	[def "[cmd ::xjson::patch] [arg decodedJson] [arg patch]"]
		Apply the [arg patch] produced by a previous [cmd ::xjson::diff] to the
		Tcl [arg decodedJson] data. The result of this function is put as Tcl decoded
		JSON format as well.
		[para]
		See the section [sectref "DECODED JSON FORMAT"] for a description of the data
		format accepted and returned by this procedure.
		See the section [sectref "JSON PATCH FORMAT"] for a description of the patch
		format accepted by this procedure.
		[para]
		See the section [sectref "PATCH EXAMPLES"] for examples.

	[def "[cmd ::xjson::rpatch] [arg decodedJson] [arg patch]"]
		Apply the [arg patch] produced by a previous [cmd ::xjson::diff] to the
		Tcl [arg decodedJson] data in reverse. That means, the operations noted in
		the patch are flipped in both their order and meaning so that the result of
		a previous identical patch is reversed.
		The result of this function is put as Tcl decoded JSON format as well.
		[para]
		[emph "Note:"] The result of this procedure is not literally but only
		functionally identical to the original, unpatched data. That is because the
		patch format does not store information about the order of JSON object keys.
		If the forward patch had removed keys from an object, the re-inserted keys
		are simply appended to the forward-patched object.
		[para]
		See the section [sectref "DECODED JSON FORMAT"] for a description of the data
		format accepted and returned by this procedure.
		See the section [sectref "JSON PATCH FORMAT"] for a description of the patch
		format accepted by this procedure.
		[para]
		See the section [sectref "PATCH EXAMPLES"] for examples.

	[def "[cmd ::xjson::makeCollectorClass] [opt [arg options]] [arg collectorClassName] [opt [arg {methodName methodDefinition ...}]]"]

	[def "[cmd ::xjson::makeComposerClass] [opt [arg options]] [arg composerClassName] [opt [arg {methodName methodDefinition ...}]]"]
		Make a JSON collector/composer class named [arg collectorClassName]/[arg composerClassName]
		according to the given options and additional method definitions.
		[para]
		Those procedures return the name of the produced class.
		[para]
		For definining your own methods, see the section [sectref "CUSTOM METHODS"].

		[list_begin definitions]
		[def "The following options are understood:"]
			[list_begin options]
			[opt_def -nobuiltins]
				Make a class without any builtin collecting/composing methods. For receiving a
				useful class despite specifying this option, you have to supply your own
				collecting/composing methods by the [arg {methodName methodDefinition ...}]
				arguments then.
				[para]
				[emph "Note:"] For not including selected builtin methods, you can define those
				as [arg methodName] {}. That excludes [arg methodName].

			[opt_def -tabulator [arg string]]
				Sets the tabulator for pretty-printing the subschema and offending JSON data in
				error messages returned by the objects of the class.

			[opt_def -maxldepth [arg integer]]
				Sets the maximum depth of methods in one line before there is a line break
				inserted when printing the subschema in error messages returned by the objects
				of the class.

			[opt_def -maxweight [arg integer]]
				Sets the maximum weight of methods before there is a line break inserted when
				printing the subschema in error messages returned by the objects of the class.

			[opt_def -maxlines [arg integer]]
				Sets the maximum number of lines in a printed value before they are folded in
				error messages returned by the objects of the class. Setting this option to the
				empty string disables the folding.

			[opt_def --]
				Marks the end of options. The argument following this one will be treated as
				an argument even if it starts with a [option -].

			[list_end]
		[list_end]
	[list_end]

	Read the following section [sectref "COLLECTOR AND COMPOSER CLASS USAGE"]
	on how to use the classes made by those procedures.

[section "COLLECTOR AND COMPOSER CLASS USAGE"]
	The [cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerClass] class factory procedures each make a class
	that is meant to be used to construct one or more collector respective composer objects using the following constructors:

	[list_begin definitions]
	[def "[arg collectorClassName] [arg collectorObjName] [opt [arg options]] [opt [arg {nestedCollectorName nestedCollectorObjName ...}]] [arg schema]"]

	[def "[arg composerClassName] [arg composerObjName] [opt [arg options]] [opt [arg {nestedComposerName nestedComposerObjName ...}]] [arg schema]"]
		Instantiate a collector/composer object named [arg collectorObjName]/[arg composerObjName]
		according to the given [arg options] and [arg schema]. Nested collector/composer
		objects used by the schema must be announced with their
		[arg nestedCollectorName]/[arg nestedComposerName] used as an alias inside the
		schema and their actual [arg nestedCollectorObjName]/[arg nestedComposerObjName]
		outside of the schema.
		[para]
		When [arg objName] contains the string "#auto", that string is replaced with an
		automatically generated name. Names have the form [arg className<number>],
		where the [arg className] part is modified to start with a lowercase letter. So
		if the [arg className] was "myCollectorClass" and the [arg objName] was
		"#auto.myCollector", the resulting name was "myCollectorClass0.myCollector".
		The constructor returns the actual [arg objName] generated that way.
		[para]
		Usually, specifying [arg collectorObjName]/[arg composerObjName] as "#auto" and
		storing the result of the constructor call in a variable is most convenient.
		[para]
		The schema is parsed on object construction and all possible pathes are walked.
		That way, the schema itself is validated before it is even used. Nested schemas
		are not walked as they are validated on their own object construction. Their
		collector/composer objects also only have to be available when the data is
		collected/composed.
		[para]
		See the section [sectref "COLLECTOR AND COMPOSER SCHEMAS"] for an explanation of the schema
		data structure.

		[list_begin definitions]
		[def "The following options are understood:"]
			[list_begin options]
			[opt_def -trusted]
				Mark the schema loaded into the constructed object as coming
				from a trustworthy source, such as a programmer of an application or the
				administrator of that software on the local machine.
				[para]
				Such schemas are allowed to execute Tcl code inside an automatically provided
				sandbox. Non-trusted schemas throw an error during schema validation if any
				collecting/composing method used in the schema has an argument or option that
				specifies code.
				[para]
				Such schemas are also allowed to specify collecting/composing methods that
				are marked unsafe, for example because they allow to specify arbitrary
				filenames in the schema, or allow the execution of arbitrary code from the
				schema outside of a sandbox. Again, non-trusted schemas throw an error during
				schema validation if such a collecting/composing method is used.
				[para]
				[emph "Note:"] None of the builtin methods do such unsafe stunts, so this option
				is only about allowing sandboxed code by default.
				[para]
				The builtin methods also feature a [cmd dubious] method which marks the subtree
				of the schema it overwatches as not trusted. That way you can construct partly
				dubious schemas on the fly without residing to nesting.
				[para]
				See the section [sectref "NESTING"] for details.

			[opt_def -init [arg body]]
				Execute the Tcl [arg body] inside the sandbox right after it is created at the
				start of the [cmd collect]/[cmd compose] method. This is meant for initializing
				global variables (e.g. counters) that may be used by downlevel methods.
				[para]
				[emph "Note:"] This is done inside an anonymous function, so simple variables
				don't clutter the global namespace inside the sandbox. You have to mark variables
				as global to make them accessible to the schema.

			[opt_def -recursionlimit [arg integer]]
				Sets the recursion limit for the sandbox to [arg integer]. A low
				value such as [const 0] may be specified but it's automatically
				raised to a reasonable minimal value as needed by the builtin
				methods that use sandboxes. If this option is not specified, the
				sandbox also defaults to that reasonable minimum.

			[opt_def --]
				Marks the end of options. The argument following this one will be treated as
				an argument even if it starts with a [option -].

			[list_end]
		[list_end]
	[list_end]

	Read the following section [sectref "COLLECTOR OBJECT USAGE"] respective
	[sectref "COMPOSER OBJECT USAGE"] on how to use the objects constructed by the class.

[subsection "COLLECTOR OBJECT USAGE"]
	The objects constructed by the collector class define the following methods:

	[list_begin definitions]
	[def "[arg collectorObjName] [method collect] [arg decodedJson] [opt [arg path]]"]
		Validate [arg decodedJson] data as described in section
		[sectref "DECODED JSON FORMAT"] and supplied by [cmd ::xjson::decode] against
		the schema loaded into the object on construction. Also collect and transform
		the JSON data to a Tcl data structure according to that schema. The collected
		data is returned. An error is thrown instead if the validation fails.
		[para]
		The optional [arg path] argument is used for printing the path of the offending
		data in error messages. It is set to "/" by default but if the supplied data is
		part of a larger JSON structure, it may be convenient to specify a more
		detailed starting path. This is for example automatically done when nesting
		collectors using the builtin [cmd nest] collecting method.

	[def "[arg collectorObjName] [method printSchema] [opt [arg indent]]"]
		Pretty-print the schema stored in the object with the given base [arg indent].

	[list_end]

[subsection "COMPOSER OBJECT USAGE"]
	The objects constructed by the composer class define the following methods:

	[list_begin definitions]
	[def "[arg composerObjName] [method compose] [arg tclData] [opt [arg path]]"]
		Validate [arg tclData] data as supplied by the program against
		the schema loaded into the object on construction. Also compose and transform
		the Tcl data structure to decoded JSON data according to that schema. The
		composed data is returned. An error is thrown instead if the validation fails.
		[para]
		The optional [arg path] argument is used for printing the path of the offending
		data in error messages. It is set to "/" by default but if the supplied data is
		part of a larger Tcl data structure, it may be convenient to specify a more
		detailed starting path. This is for example automatically done when nesting
		composers using the builtin [cmd nest] composing method.
		[para]
		The result is decoded JSON data as described in section [sectref "DECODED JSON FORMAT"].
		Feed it into [cmd ::xjson::encode] to render JSON data from it.

	[def "[arg composerObjName] [method printSchema] [opt [arg indent]]"]
		Pretty-print the schema stored in the object with the given base [arg indent].

	[list_end]

[subsection "COLLECTOR AND COMPOSER SCHEMAS"]
	Collector and composer schemas are nested lists of collecting/composing
	functions and their arguments.
	[para]
	As an important detail, both collector and composer schemas describe the
	JSON side of things. Validation always happens on the JSON side of things.
	This gets crucial as soon your schemas feature data manipulations.
	[para]
	Schemas can be very simple. For example, a schema [cmd "integer"] that is made
	from the collecting method of the same name validates JSON input data as
	[emph "-5"] but not JSON input data as [emph "3.2"] (not an integer) or
	[emph "\"5\""]. Mind the quotes that mark that character as a string value.
	For the composing direction, the Tcl input data is validated instead.
	[para]
	You can make that schema an argument of another schema. For example, the
	[cmd array] collecting method takes a schema as an argument. The resulting
	schema [cmd "{array integer}"] validates JSON input data as
	[emph "\[-4, 7, 8, 3\]"], or for the composing direction Tcl input data
	[emph "{-4 7 8 3}"].
	[para]
	Many collecting methods take options that allow to specify further constraints.
	For example, you can tell the [cmd array] method to allow only up to three
	array members in the JSON input data. The schema [cmd "{array -max 3 integer}"]
	validates [emph "\[\]"], [emph "\[156\]"], [emph "\[1, 0\]"], and
	[emph "\[3, 99, 3\]"], but not [emph "\[-4, 7, 8, 3\]"].
	And of course the [cmd integer] collecting method also allows further
	constraints. A schema [cmd "{array -max 3 {integer -min 0 -max 99}}"] validates
	[emph "\[\]"], [emph "\[1, 0\]"], and [emph "\[3, 99, 3\]"], but not
	[emph "\[-4, 7, 8, 3\]"] and neither [emph "\[156\]"]. Likewise for the
	composing direction with Tcl lists of integers.
	[para]
	The collector objects do not just validate the decoded JSON input data but also
	return it as plain Tcl data. For manipulating what is returned, there are
	special collecting methods meant for output formatting. For example, a schema
	[cmd "{array -max 3 {format \"%02d\" {integer -min 0 -max 99}}}"]
	returns the JSON input [emph "\[3, 99, 3\]"] as [emph "{03 99 03}"].
	[para]
	It works the reverse for composing. The Tcl data is validated to be an
	[cmd "array -max 3"], the single elements formatted according to the
	[cmd "format \"%02d\""] method, then validated according to the
	[cmd "integer -min 0 -max 99"] method and finally returned as decoded JSON.
	[para]
	Symetrical schemas may be the same for collector and composer objects. As soon
	there is asymetrical data manipulation (as that [cmd "format"] method) involved,
	you usually need separate schemas for both directions.
	[para]
	There are also methods that work as control structures. For example,
	the schema [cmd "{anyof {{integer -max -10} {integer -min 10}}}"]
	validates any integer value that is either <=-10 or >=10. And of course, you
	can also mix the allowed JSON input types that way if it makes sense in your
	application: e.g. [cmd "{array {anyof {number string boolean null}}}"]
	validates an array of all kinds of valid simple JSON types. Note that you will
	lose the JSON type information that way so you usually don't want to do such
	stunts without further type-specific output formatting.
	[para]
	See the section [sectref "BUILTIN METHODS"] and the various
	[sectref "EXAMPLES"] sections for more details.

[subsection "BUILTIN METHODS"]
	The following methods are built into each collector/composer class
	(and object) unless the class was created specifying the [option -nobuiltins]
	option when calling the
	[cmd ::xjson::makeCollectorClass] or [cmd ::xjson::makeComposerClass]
	class factory procedure.
	The [arg methodName] as used by the class factory procedure is the same as the
	method name below as it is used inside the schema, unless otherwise noted.

	[list_begin definitions]
	[def "Common options"]
		[list_begin options]
		[opt_def --]
			Marks the end of options. The argument following this one will be treated as
			an argument even if it starts with a [option -].

		[list_end]

	[def "Arguments used"]
		[list_begin definitions]
		[def [arg "body"]]
			A Tcl script body as accepted by Tcl's [cmd "apply"] command.

		[def [arg "by"]]
			A Tcl list of dict keys.

		[def [arg "chars"]]
			A Tcl string value listing chars to be trimmed from another string.

		[def [arg "class"]]
			A Tcl character class as accepted by Tcl's [cmd "string is"] command.

		[def [arg "double"]]
			A Tcl double value.

		[def [arg "elseSchema"]]
			A schema as described in the section [sectref "COLLECTOR AND COMPOSER SCHEMAS"].

		[def [arg "exp"]]
			A Tcl regular expression as accepted by Tcl's [cmd "regexp"] command.

		[def [arg "expr"]]
			A Tcl expression as accepted by Tcl's [cmd "expr"] command.

		[def [arg "index"]]
			A Tcl string index as accepted by Tcl's [cmd "string index"] command.

		[def [arg "integer"]]
			A Tcl integer value. (The test applied is actually Tcl's [cmd "string is entier"] command.)

		[def [arg "length"]]
			A Tcl integer value >= 0. (The test applied is actually Tcl's [cmd "string is entier"] command.)

		[def [arg "mapping"]]
			A Tcl list of string mappings as accepted by Tcl's [cmd "string map"] command.

		[def [arg "needle"]]
			A Tcl string value giving a needle string to search for in a haystack string.

		[def [arg "nullvalue"]]
			A Tcl string value to be treated as null.

		[def [arg "pattern"]]
			A Tcl string pattern as accepted by Tcl's [cmd "string match"] command.

		[def [arg "nestedCollectorName"]]
			The name of a nested collector as specified when constructing the collector object.

		[def [arg "range"]]
			A Tcl list giving a string range as accepted by Tcl's [cmd "string range"] command.
			In addition, also a Tcl string index as accepted by Tcl's [cmd "string index"] command.

		[def [arg "replacement"]]
			An Tcl string value used as a replacement for another string.

		[def [arg "schema"]]
			A schema as described in the section [sectref "COLLECTOR AND COMPOSER SCHEMAS"].

		[def [arg "schemaList"]]
			A Tcl list of schemas as described in the section [sectref "COLLECTOR AND COMPOSER SCHEMAS"].

		[def [arg "schemaDict"]]
			A Tcl dict of key-schema pairs as described in the section [sectref "COLLECTOR AND COMPOSER SCHEMAS"].
			The keys may be arbitrary Tcl string values.

		[def [arg "schemaPairs"]]
			A Tcl dict of schema-schema pairs as described in the section [sectref "COLLECTOR AND COMPOSER SCHEMAS"].

		[def [arg "start"]]
			A Tcl string index as accepted by Tcl's [cmd "string index"] command.

		[def [arg "string"]]
			A Tcl string value.

		[def [arg "testSchema"]]
			A schema as described in the section [sectref "COLLECTOR AND COMPOSER SCHEMAS"].

		[def [arg "thenSchema"]]
			A schema as described in the section [sectref "COLLECTOR AND COMPOSER SCHEMAS"].

		[def [arg "value"]]
			An arbitrary Tcl value as read from the decoded JSON input.

		[list_end]

	[def "Simple Types"]
		[list_begin commands]
		[cmd_def boolean]
			[list_begin definitions]
			[def "for collecting"]
				Validates [const "literal [emph value]"] in the decoded JSON input.
				As an additional constraint, the [emph value] must be a boolean.
				(The test applied is actually Tcl's [cmd "string is boolean"] command.)
				[para]
				Returns the boolean [emph value].

			[def "for composing"]
				Validates a Tcl input value that is a boolean to Tcl's [cmd "string is boolean"] command.
				[para]
				Returns either [const "literal true"] or [const "literal false"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

		[cmd_def decoded]
			[list_begin definitions]
			[def "for collecting"]
				This method does not exist in collector objects as the [cmd "::xjson::decode"] and
				[cmd "::xjson::recode"] functions never return a [const "decoded"] type.

			[def "for composing"]
				Validates a decoded JSON input [emph "value"] as understood by [cmd "::xjson::encode"]
				and [cmd "::xjson::recode"].
				See [sectref "DECODED JSON FORMAT"] for details.
				[para]
				Returns [const "decoded [arg value]"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

		[cmd_def encoded]
			[list_begin definitions]
			[def "for collecting"]
				This method does not exist in collector objects as the [cmd "::xjson::decode"] and
				[cmd "::xjson::recode"] functions never return an [const "encoded"] type.

			[def "for composing"]
				Validates a JSON input [emph "value"] as understood by [cmd "::xjson::decode"].
				[para]
				Returns [const "encoded [arg value]"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeComposerClass] class factory procedures is [cmd decoded].

		[cmd_def "integer [arg [opt options]]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates a [const "number [emph value]"] in the decoded JSON input.
				As an additional constraint, the [emph value] must be an integer.
				(The test applied is actually Tcl's [cmd "string is entier"] command.)
				[para]
				Returns the numeric [emph value].

			[def "for composing"]
				Validates a Tcl input value that is an integer to Tcl's [cmd "string is entier"] command.
				[para]
				Returns [const "number [arg value]"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]

			[def "The following general option may be specified:"]
				[list_begin options]
				[opt_def -isolate]
					Use a local sandbox.

				[list_end]

			[def "The following further constraints may be specified:"]
				[list_begin options]
				[opt_def -max [arg integer]]
					Validates a number [emph value] <= [arg integer].

				[opt_def -xmax [arg integer]]
					Validates a number [emph value] < [arg integer].

				[opt_def -min [arg integer]]
					Validates a number [emph value] >= [arg integer].

				[opt_def -xmin [arg integer]]
					Validates a number [emph value] > [arg integer].

				[opt_def -multipleof [arg integer]]
					Validates a number [emph value] that is a multiple of [arg integer].

				[opt_def -test [arg expr]]
					Validates a number [emph value] by passing it to the Tcl [arg expr] as
					the local variable [emph x]. If the expression results in a boolean false,
					the	validation fails.

				[list_end]
			[list_end]

			[emph "Note:"] The [arg methodName] for this method as used by the [cmd ::xjson::makeCollectorClass]
			respective [cmd ::xjson::makeComposerClass] class factory procedures is [cmd number].

		[cmd_def null]
			[list_begin definitions]
			[def "for collecting"]
				Validates a [const {literal null}] in the decoded JSON input.
				See the section [sectref "NULL HANDLING"] for additional information.

			[def "for composing"]
				Validates the null value as specified, if any.

				[list_begin definitions]
				[def "The following option should be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

		[cmd_def "number [arg [opt options]]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates a [const "number [emph value]"] in the decoded JSON input.
				(The test applied is actually Tcl's [cmd "string is double"] command.)
				[para]
				Returns the numeric [emph value].

			[def "for composing"]
				Validates a Tcl input value that is an integer to Tcl's [cmd "string is double"] command.
				[para]
				Returns [const "number [arg value]"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]

			[def "The following general option may be specified:"]
				[list_begin options]
				[opt_def -isolate]
					Use a local sandbox.

				[list_end]

			[def "The following further constraints may be specified:"]
				[list_begin options]
				[opt_def -max [arg double]]
					Validates a number [emph value] <= [arg double].

				[opt_def -xmax [arg double]]
					Validates a number [emph value] < [arg double].

				[opt_def -min [arg double]]
					Validates a number [emph value] >= [arg double].

				[opt_def -xmin [arg double]]
					Validates a number [emph value] > [arg double].

				[opt_def -test [arg expr]]
					Validates a number [emph value] by passing it to the Tcl [arg expr] as
					the local variable [emph x]. If the expression results in a boolean false,
					the	validation fails.

				[list_end]
			[list_end]

		[cmd_def "string [arg [opt options]]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates a [const "string [emph value]"] in the decoded JSON input.
				[para]
				Returns the original string [emph value].

			[def "for composing"]
				Validates any Tcl input value.
				[para]
				Returns [const "string [arg value]"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

			Further constraints may be specified. They all work on a test string that is
			initially filled with the string [emph value]. Some options aren't constraints
			but instead they manipulate the test string. All options are applied and tested
			in their order of appearance in the [arg options]. They may appear multiple
			times.
			[para]
			[emph "Note:"] To manipulate the string output, see the methods in the
			[sectref "Result Formatting Operators"] subsection.

			[list_begin definitions]
			[def "The following general options may be specified:"]
				[list_begin options]
				[opt_def -nocase]
				[opt_def -case]
					Makes the options [option -before], [option -xbefore], [option -behind],
					[option -xbehind], [option -equal], [option -map], [option -match],
					[option -regexp] work case-insensitively/case-sensitively until the other
					option is specified. By default all those options work case-sensitively.

				[opt_def -start [arg index]]
					Makes the options [option -first], [option -last] and [option -regexp] start
					their search with the character [arg index]. It accepts string indices as
					accepted by Tcl's [cmd "string index"] command. Specifying [arg index] as an
					empty string disables this option. It's disabled by default.

				[opt_def -clength [arg length]]
					Makes the options [option -before], [option -xbefore], [option -behind],
					[option -xbehind], and [option -equal] only consider a [arg length] of
					characters for their comparison. Specifying [arg length] as [const 0]
					disables this option. It's disabled by default.

				[opt_def -isolate]
					Use a local sandbox.

				[list_end]

			[def "The following test string manipulations may be specified:"]
				[list_begin options]
				[opt_def -and]
					Resets the test string to the [arg value] supplied from the decoded JSON input.
					This option may be used to do multiple validation tests without more convoluted
					control structures.

				[opt_def -map [arg mapping]]
					Manipulates the test string by mapping it as by Tcl's [cmd "string map"]
					command. The options [option -nocase] and [option -case] are honored.

				[opt_def -range [arg range]]
					Manipulates the test string by removing anything but the [arg range] of
					characters from it, as by Tcl's [cmd "string range"] command.

				[opt_def -reverse]
					Manipulates the test string by reversing the order of chars as by Tcl's
					[cmd "string reverse"] command. This is sometimes useful before testing for
					regular expressions.

				[opt_def -tolower [arg range]]
				[opt_def -toupper [arg range]]
					Manipulates the test string by forcing lowercase/uppercase on all characters in
					the [arg range] as by Tcl's [cmd "string tolower"] resp. [cmd "string toupper"]
					command.

				[opt_def -totitle [arg range]]
					Manipulates the test string by forcing uppercase on the first and lowercase on
					all other characters in the [arg range] as by Tcl's [cmd "string totitle"]
					command.

				[opt_def -transform [arg body]]
					Manipulates the test string by passing it to the Tcl [arg body] as the local
					variable [emph x]. The teststring is then set to the return value of that
					evaluation.

				[opt_def -trim [arg chars]]
				[opt_def -trimleft [arg chars]]
				[opt_def -trimright [arg chars]]
					Manipulates the test string by trimming all specified [arg chars] from it from
					left, right, or both. Specifying [arg chars] as an empty list makes it trim all
					whitespace (any character that tests positive for [cmd "string is space"]).
					That's a slight difference to Tcl's	[cmd "string trim"], [cmd "string trimleft"],
					[cmd "string trimright"] commands.

				[list_end]

			[def "The following further constraints on the test string length may be specified:"]
				[list_begin options]
				[opt_def -max [arg integer]]
					Validates a test string length <= [arg integer].

				[opt_def -xmax [arg integer]]
					Validates a test string length < [arg integer].

				[opt_def -min [arg integer]]
					Validates a test string length >= [arg integer].

				[opt_def -xmin [arg integer]]
					Validates a test string length > [arg integer].

				[opt_def -multipleof [arg integer]]
					Validates a test string length that is a multiple of [arg integer].

				[list_end]

			[def "The following further options and constraints on the position of a search string in the test string may be specified:"]
				[list_begin options]
					[opt_def -first [arg needle]]
					[opt_def -last [arg needle]]
						Find the [arg needle] in the teststring as by Tcl's [cmd "string first"] resp.
						[cmd "string last"] command. It starts at the position in the test string
						specified by the [option -start] option, or at its beginning/end if that option
						is disabled. It sets the needle position for further validation by the options
						[option -maxpos], [option -xmaxpos], [option -minpos], [option -xmaxpos], and
						[option -multipleofpos].  If the needle cannot be found, its position is set as
						[const -1]. The needle position is also [const -1] by default.

					[opt_def -maxpos [arg integer]]
						Validates a needle position <= [arg integer].

					[opt_def -xmaxpos [arg integer]]
						Validates a needle position < [arg integer].

					[opt_def -minpos [arg integer]]
						Validates a needle position >= [arg integer].

					[opt_def -xminpos [arg integer]]
						Validates a needle position > [arg integer].

					[opt_def -multipleofpos [arg integer]]
						Validates a needle position that is a multiple of [arg integer].

					[list_end]

			[def [join [list The following further constraints on the sorting order of the test string as by Tcl's commands [cmd "string compare"] and [cmd "string equal"] may be specified, but only the first characters as specified by the [option -clength] option are considered. The options [option -nocase] and [option -case] are honored.]]]
				[list_begin options]
				[opt_def -before [arg string]]
					Validates a test string sorting before or equal [arg string].

				[opt_def -xbefore [arg string]]
					Validates a test string sorting before [arg string].

				[opt_def -behind [arg string]]
					Validates a test string sorting behind or equal [arg string].

				[opt_def -xbehind [arg string]]
					Validates a test string sorting behind [arg string].

				[opt_def -equal [arg string]]
					Validates a test string sorting equal [arg string].

				[list_end]

			[def "The following further constraints on the test string may be specified:"]
				[list_begin options]
				[opt_def -is [arg class]]
					Validates a test string [arg class] as by Tcl's [cmd "string is"] command.
					In addition, [arg class] may also be put as [const "uuid"], which validates
					a UUID/GUID. Both lowercase and uppercase hex digits are considered valid.

				[opt_def -match [arg pattern]]
					Validates a test string that matches the [arg pattern] as by Tcl's
					[cmd "string match"] command.
					The options [option -nocase] and [option -case] are honored.

				[opt_def -regexp [arg exp]]
					Validates a test string that matches the regular expression [arg exp] as by
					Tcl's [cmd "regexp"] command.  It starts at the position in the test string
					specified by the [option -start] option, or at its beginning if that option
					is disabled.
					The options [option -nocase] and [option -case] are honored.

				[opt_def -test [arg expr]]
					Validates a test string by passing it to the Tcl [arg expr] as the local
					variable [emph x]. If the expression results in a boolean false, the
					validation fails.

				[list_end]
			[list_end]
		[list_end]

	[def "Aggregate Types"]
		[list_begin commands]
		[cmd_def "array [arg [opt options]] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates an [const "array {...}"] in the decoded JSON input with
				elements according to the given [arg schema].
				[para]
				Returns a Tcl list with each array member as one list element.
				Returns an empty Tcl list if the array has no members.

			[def "for composing"]
				Validates a Tcl list with elements according to the given [arg schema].
				[para]
				Returns an [const "array {...}"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						This isn't about individual elements but about whether the whole array
						should be considered [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

			[emph "Note:"] Array elements that evaluate as [const null] are completely
			ignored -as if they were not posted-.
			See the section [sectref "NULL HANDLING"] for additional information.

			[list_begin definitions]
			[def "The following general option may be specified:"]
				[list_begin options]
				[opt_def -isolate]
					Use a local sandbox.

				[list_end]

			[def "The following further constraints on the array length may be specified:"]
				[list_begin options]
				[opt_def -max [arg integer]]
					Validates an array length <= [arg integer] elements.

				[opt_def -xmax [arg integer]]
					Validates an array length < [arg integer] elements.

				[opt_def -min [arg integer]]
					Validates an array length >= [arg integer] elements.

				[opt_def -xmin [arg integer]]
					Validates an array length > [arg integer] elements.

				[opt_def -multipleof [arg integer]]
					Validates an array length that is a multiple of [arg integer] elements.

				[opt_def -test [arg expr]]
					Validates an array length by passing it to the Tcl [arg expr] as
					the local variable [emph x]. If the expression results in a boolean false,
					the	validation fails.

				[list_end]
			[list_end]

		[cmd_def "duple [arg schemaDict]"]
			A shortcut for [cmd "duples -min 1 -max 1 [arg schemaDict]"].
			See below.
			[para]
			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerrClass]
			class factory procedures is [cmd array].

		[cmd_def "duples [arg [opt options]] [arg schemaDict]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates an [const "array {...}"] in the decoded JSON input with
				elements according to the given [arg schemaDict].
				[para]
				Different to the
				[cmd "array"] collecting method, this method alternates through the given
				[arg schemaDict] and requires the array elements to validate against the
				different schemas in order. An incomplete last tuple results in failed
				validation.
				[para]
				Different to the [cmd "tuples"] collecting method, this method labels the
				collected input data according to the schema so the result isn't a Tcl list of
				lists but a list of dicts.
				Returns an empty Tcl list if the array has no members.

			[def "for composing"]
				Validates a Tcl list of dicts with elements according to the given
				[arg schemaDict].
				[para]
				Different to the
				[cmd "array"] composing method, this method alternates through the given
				[arg schemaDict] and requires the dict elements to validate against the
				different schemas in order. An incomplete last tuple results in failed
				validation.
				[para]
				Different to the [cmd "tuples"] composing method, this method requires the
				collected input data to be labeled according to the schema so the input must
				be a Tcl list of dicts, not a Tcl list of lists.
				[para]
				Returns an [const "array {...}"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						This isn't about individual elements but about whether the whole array
						should be considered [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

			[emph "Note:"] Array elements that evaluate as [const null] are completely
			ignored -as if they were not posted-.
			See the section [sectref "NULL HANDLING"] for additional information.
			[para]
			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerClass]
			class factory procedures is [cmd array].

			[list_begin definitions]
			[def "The following general option may be specified:"]
				[list_begin options]
				[opt_def -isolate]
					Use a local sandbox.

				[list_end]

			[def "The following further constraints on the tuples count may be specified:"]
				[list_begin options]
				[opt_def -max [arg integer]]
					Validates an array length <= [arg integer] tuples.

				[opt_def -xmax [arg integer]]
					Validates an array length < [arg integer] tuples.

				[opt_def -min [arg integer]]
					Validates an array length >= [arg integer] tuples.

				[opt_def -xmin [arg integer]]
					Validates an array length > [arg integer] tuples.

				[opt_def -multipleof [arg integer]]
					Validates an array length that is a multiple of [arg integer] tuples.

				[opt_def -test [arg expr]]
					Validates an array length (in tuples) by passing it to the Tcl [arg expr] as
					the local variable [emph x]. If the expression results in a boolean false,
					the	validation fails.

				[list_end]
			[list_end]

		[cmd_def "object [arg [opt options]] [arg schemaDict]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates an [const "object {...}"] in the decoded JSON input with
				elements according to the given [arg schemaDict].
				[para]
				Returns a Tcl dict of key-value pairs. This behaviour may be changed with the
				[option -values] option. The order of elements is always the same as specified
				in the [arg schemaDict] argument.

			[def "for composing"]
				Validates a Tcl dict with elements according to the given [arg schemaDict].
				This behaviour may be changed with the [option -values] option.
				The order of elements is always the same as specified in the [arg schemaDict]
				argument.
				[para]
				Returns an [const "object {...}"].

				[list_begin definitions]
				[def "The following options may be specified:"]
					[list_begin options]
					[opt_def -missing [arg nullvalue]]
						Specifies a Tcl value that should be passed to the downlevel schemas
						whenever a field is missing in the input. The specific downlevel schema
						may then specify the same Tcl string as its own [const "null"] value
						and report a [const "null"] to uplevel, where a [cmd default] or
						[cmd optional] method can override the validation failure.
						See the section [sectref "NULL HANDLING"] for additional information.

					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						This isn't about individual elements but about whether the whole object
						should be considered [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

			[emph "Note:"] Missing keys are treated as a validation failure, and as are
			elements that evaluate as [const null]. This may be circumvented by enclosing
			the schema for an element with a [cmd default] or [cmd optional] method.
			See the subsection [sectref "Aggregate Field Operators"].

			[list_begin definitions]
			[def "The following option may be specified:"]
				[list_begin options]
				[opt_def -values]
					Instead of returning/requiring a Tcl dict of key-value pairs, return/require
					a Tcl list of the values.

				[list_end]
			[list_end]

		[cmd_def "tuple [arg schemaList]"]
			A shortcut for [cmd "tuples -flat -min 1 -max 1 [arg schemaList]"].
			See below.
			[para]
			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerClass]
			class factory procedures is [cmd array].


		[cmd_def "tuples [arg [opt options]] [arg schemaList]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates an [const "array {...}"] in the decoded JSON input with
				elements according to the given [arg schemaList].
				[para]
				Different to the
				[cmd "array"] collecting method, this method alternates through the given
				[arg schemaList] and requires the array elements to validate against the
				different schemas in order. An incomplete last tuple results in failed
				validation.
				[para]
				This method returns a Tcl list with each tuple list as one list element. This
				can be changed with the [option -flat] option. The resulting list is flat then.
				Returns an empty Tcl list if the array has no members.

			[def "for composing"]
				Validates a Tcl list of lists with elements according to the given
				[arg schemaList]. This can be changed with the [option -flat] option.
				It validates a flat Tcl list then.
				[para]
				Different to the
				[cmd "array"] composing method, this method alternates through the given
				[arg schemaList] and requires the list elements to validate against the
				different schemas in order. An incomplete last tuple results in failed
				validation.
				[para]
				Returns an [const "array {...}"].

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -null [arg nullvalue]]
						Specifies a Tcl input value that should be treated as [const "null"].
						This isn't about individual elements but about whether the whole array
						should be considered [const "null"].
						See the section [sectref "NULL HANDLING"] for additional information.

					[list_end]
				[list_end]
			[list_end]

			[emph "Note:"] Array elements that evaluate as [const null] are completely
			ignored -as if they were not posted-.
			See the section [sectref "NULL HANDLING"] for additional information.
			[para]
			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerClass]
			class factory procedures is [cmd array].

			[list_begin definitions]
			[def "The following general options may be specified:"]
				[list_begin options]
				[opt_def -flat]
					Instead of returning a Tcl list of lists, return a flat Tcl list.

				[opt_def -isolate]
					Use a local sandbox.

				[list_end]

			[def "The following further constraints on the tuples count may be specified:"]
				[list_begin options]
				[opt_def -max [arg integer]]
					Validates an array length <= [arg integer] tuples.

				[opt_def -xmax [arg integer]]
					Validates an array length < [arg integer] tuples.

				[opt_def -min [arg integer]]
					Validates an array length >= [arg integer] tuples.

				[opt_def -xmin [arg integer]]
					Validates an array length > [arg integer] tuples.

				[opt_def -multipleof [arg integer]]
					Validates an array length that is a multiple of [arg integer] tuples.

				[opt_def -test [arg expr]]
					Validates an array length (in tuples) by passing it to the Tcl [arg expr] as
					the local variable [emph x]. If the expression results in a boolean false,
					the	validation fails.

				[list_end]
			[list_end]

		[list_end]

	[def "Aggregate Field Operators"]
		[list_begin commands]
		[cmd_def "default [arg string] [arg schema] (for collecting)"]
		[cmd_def "default [arg type] [arg string] [arg schema] (for composing)"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. If it succeeds, the
				value returned by the schema is returned. If it fails, the reported validation
				error is escalated.
				If it is reported as [const null] however because the input data is simply
				missing or a [const "literal null"], it is reported as successfully validated
				and the	given [arg string] is returned.
				[para]
				[emph "Note:"] The [arg string] does not have to validate. It may be an arbitrary
				string.

			[def "for composing"]
				Validates the Tcl input with the [arg schema]. If it succeeds, the
				value returned by the schema is returned. If it fails, the reported validation
				error is escalated.
				If it is reported as [const null] however, it is reported as successfully validated
				instead and the	given [arg type] and [arg string] are returned.
				[para]
				[emph "Note:"] Neither [arg type] nor [arg string] have to validate. They may be
				both arbitrary values. It's the reponsibilty of the schema author to choose
				meaningful values.

			[list_end]

			[emph "Note:"] Though most useful with object fields, this operator may be
			specified at any place where a missing or [const "null"] value in the
			input data should be replaced by a reasonable default.

		[cmd_def "optional [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. If it succeeds, the
				value returned by the schema is returned. If it fails, the reported validation
				error is escalated.
				If it validates as [const null] however because the input data is simply missing
				or a [const "literal null"], it is reported as a special validation error
				instead, and an uplevel	[cmd object] method will ignore the field for
				this object. It's not going to be reported as a key-value pair in the object
				result at all.

			[def "for composing"]
				Validates the Tcl input with the [arg schema]. If it succeeds, the
				value returned by the schema is returned. If it fails, the reported validation
				error is escalated.
				If it is reported as [const null] however, it is reported as a special validation
				error instead, and an uplevel [cmd object] method will ignore the field
				for	this object. It's not going to be reported as a key-value pair in the object
				result at all.

				[list_begin definitions]
				[def "The following option may be specified:"]
					[list_begin options]
					[opt_def -emitnull]
						Changes the type of validation error reported so the uplevel method will
						report a [const "literal null"] instead of a missing field.
						See the section [sectref "NULL HANDLING"] for additional information.
					[list_end]
				[list_end]
			[list_end]

			[emph "Note:"] Be careful in conjunction with the [option -values] option of the
			[cmd object] method though. Optional fields must then be the last ones
			in the schema to avoid confusion on the result data.
			[para]
			[emph "Note:"] For any other uplevel methods than [cmd array], [cmd duple],
			[cmd duples], [cmd object], [cmd tuple], [cmd tuples], this
			operator simply changes the kind of validation error reported.

		[list_end]

	[def "Control Structures"]
		[list_begin commands]
		[cmd_def "allof [arg schemaList]"]
			Validates the input with all the schemas in the [arg schemaList].
			If any listed schema does not validate, the validation fails as a whole.
			[para]
			If a schema evaluates as [const null] it is counted as validated but no result
			is stored.
			[para]
			Returns the result of the first schema that had a result. If no schema had a
			result -they have all evaluated as [const null]-, this method
			returns [const null] as well.
			See the section [sectref "NULL HANDLING"] for additional information.

		[cmd_def "anyof [arg schemaList]"]
			Validates the input with all the schemas in the [arg schemaList].
			If no listed schema validates, the validation fails as a whole.
			[para]
			If a schema evaluates as [const null] it is counted as validated but no result
			is stored.
			[para]
			Returns the result of the first schema that had a result. If no schema had a
			result -they have all evaluated as [const null]-, this method
			returns [const null] as well.
			See the section [sectref "NULL HANDLING"] for additional information.
			[para]
			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerClass]
			class factory procedures is [cmd allof].

		[cmd_def "const [arg string] (for collecting)"]
		[cmd_def "const [arg type] [arg string] (for composing)"]
			[list_begin definitions]
			[def "for collecting"]
				Returns the [arg string] constant.

			[def "for composing"]
				Returns the [arg type] [arg string] constants.

			[list_end]

			This method is meant for the
			result schemas of the [cmd if] and [cmd switch] methods, but may also
			be put as a default value for those or the [cmd allof], [cmd anyof], and
			[cmd oneof] methods.

		[cmd_def "discard"]
			Discards the input and and returns a [const null] instead. That [const null]
			may be reinterpreted by uplevel methods.

		[cmd_def "dubious [arg schema]"]
			Marks the [arg schema] and its whole branch as not trusted. Such schemas may
			not specify Tcl code or methods that are marked as unsafe.
			[para]
			The dubious flag is not inherited to nested collector objects so they may be
			marked as having a trusted schema, and may specify Tcl code or unsafe methods.
			[para]
			See the section [sectref "NESTING"] for details.

		[cmd_def "escalate"]
			Escalates the validation error encountered in a [arg testSchema] of
			the [cmd if] method, or the validation error of the [cmd switch] method.
			[para]
			[emph "Note:"] When used outside of the [arg elseSchema] or [arg nullSchema]
			of the [cmd if] or [cmd switch] methods, this method reports an error.

		[cmd_def "if [arg testSchema] [arg thenSchema] [arg elseSchema] [arg nullSchema]"]
			Validates the input with the [arg testSchema].
			[para]
			If the test validation returns [const null],
			this method re-validates the input with the [arg nullSchema] and returns
			that result	(or fail validation). The [arg nullSchema] may be specified as
			[cmd escalate] to escalate the validation error of the [arg testSchema] instead.
			[para]
			If the test validation succeeded,
			this method re-validates the input with the [arg thenSchema] and returns
			that result	(or fail validation). The [arg thenSchema] may be specified as
			[cmd pass] to return the result of the [arg testSchema] instead.
			[para]
			If the test	validation failed, this method re-validates the input with the
			[arg elseSchema] and returns that result (or fail validation). The
			[arg elseSchema] may be specified as [cmd escalate] to escalate the validation
			error of the [arg testSchema] instead.
			[para]
			[emph "Note:"] The [cmd discard] method is also useful as either the
			[arg thenSchema] or the [arg elseSchema]. It returns a [const null].

		[cmd_def "nest [arg nestedCollectorName]"]
		[cmd_def "nest [arg nestedComposerName]"]
			Passes the branch of data at this point to the collector/composer object
			[arg nestedCollectorName]/[arg nestedComposerName] which was registered with
			the schema at the construction of this collector/composer object.
			[para]
			The dubious flag is not inherited to the nested collector/composer
			object so it may be marked as having a trusted schema, and may
			specify Tcl code or unsafe methods though the calling schema may not.
			[para]
			See the sections [sectref "NESTING"] and [sectref "SANDBOXING"] for details.

		[cmd_def "oneof [arg schemaList]"]
			Validates the input with all the schemas in the [arg schemaList].
			If none or more than one listed schema validates, the validation fails as a whole.
			[para]
			If a schema evaluates as [const null] it is counted as validated but no result
			is stored.
			[para]
			Returns the result of the first schema that had a result. If no schema had a result
			-they have all evaluated as [const null]-, this method returns
			[const null] as well.
			See the section [sectref "NULL HANDLING"] for additional information.
			[para]
			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerClass]
			class factory procedures is [cmd allof].

		[cmd_def "pass"]
			Passes the result of the validated input from a [arg testSchema] of
			the [cmd if] method or from the first matching [arg testSchema] of the [cmd switch] method.
			[para]
			[emph "Note:"] When used outside of a [arg thenSchema] of the [cmd if] or
			[cmd switch] methods, this method reports an error.

		[cmd_def "switch [arg schemaPairs] [arg elseSchema] [arg nullSchema]"]
			Validates the input with the [arg schemaPairs] list. The first, third, fifth,
			... element of that list is interpreted as a [arg testSchema], the second,
			fourth, sixth, ... element of that list is interpreted as a [arg thenSchema].
			[para]
			If a test validation returns [const null], the next [arg testSchema] is checked.
			[para]
			If a test validation fails, the next [arg testSchema] is checked.
			[para]
			As soon a test validation succeeded, no more [arg testSchema]s are checked
			but instead, this method re-validates the input with the following
			[arg thenSchema] and returns that result (or fail validation).
			The [arg thenSchema] may be specified as [cmd pass] to return the result
			of the [arg testSchema] instead.
			[para]
			If no test schema validated, this method checks whether all test results have been
			[const null]. In that case it re-validates the input with the [arg nullSchema],
			otherwise with  the [arg elseSchema] and returns that result (or fail
			validation). Either may be specified as [cmd escalate] to
			escalate the validation error of the switch method instead.
			[para]
			[emph "Note:"] The [cmd discard] method is also useful as either a
			[arg thenSchema], the [arg elseSchema], or the [arg nullSchema].
			It returns a [const null].

		[list_end]

	[def "Result Formatting Operators"]
		[list_begin commands]

		[cmd_def "apply [arg [opt options]] [arg varList] [arg body] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. That result is then
				expanded as needed by the amount of variable names in [arg varList] and
				then passed into Tcl's [cmd "apply"] command along the [arg varList] and
				the supplied Tcl [arg body].
				The last variable in the [arg varList] gets assigned a list of the
				remaining input elements if there are more of those than variable names
				specified.
				[para]
				The operator returns the result of Tcl's [cmd "apply"] command.

			[def "for composing"]
				Expands the Tcl input data as needed by the amount of variable names in
				[arg varList] and passes it into Tcl's [cmd "apply"] command along the
				[arg varList] and the supplied Tcl [arg body].
				The last variable in the [arg varList] gets assigned a list of the
				remaining input elements if there are more of those than variable names
				specified.
				[para]
 				The result of that is then validated with the [arg schema].
				The operator returns the result of the schema.

			[list_end]

			[list_begin definitions]
			[def "The following options may be specified:"]
				[list_begin options]
				[opt_def -isolate]
					Use a local sandbox.

				[list_end]
			[list_end]

		[cmd_def "datetime [arg [opt options]] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. That result is then
				passed into Tcl's [cmd "clock scan"] command along the supplied
				[arg options] arguments.
				[para]
				The operator returns the result of Tcl's [cmd "clock scan"] command.

			[def "for composing"]
				Passes the Tcl input data into Tcl's [cmd "clock format"] command
				along the supplied [arg options] arguments.
				[para]
 				The result of that is then validated with the [arg schema].
				The operator returns the result of the schema.

			[def "The following options may be specified:"]
				[list_begin options]
				[opt_def -format [arg format]]
					A format string as understood by Tcl's [cmd "clock -format"] option.

				[opt_def -timezone [arg zoneName]]
					A timezone name as understood by Tcl's [cmd "clock -timezone"] option.

				[opt_def -locale [arg localeName]]
					A locale name as understood by Tcl's [cmd "clock -locale"] option.

				[list_end]
			[list_end]

		[cmd_def "expr [arg [opt options]] [arg varList] [arg expr] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. That result is then
				expanded as needed by the amount of variable names in [arg varList] and
				then passed into Tcl's [cmd "expr"] command along the [arg varList] and
				the supplied Tcl expression [arg expr].
				The last variable in the [arg varList] gets assigned a list of the
				remaining input elements if there are more of those than variable names
				specified.
				[para]
				The operator returns the result of Tcl's [cmd "expr"] command.

			[def "for composing"]
				Expands the Tcl input data as needed by the amount of variable names in
				[arg varList] and passes it into Tcl's [cmd "expr"] command along the
				[arg varList] and the supplied Tcl [arg body].
				The last variable in the [arg varList] gets assigned a list of the
				remaining input elements if there are more of those than variable names
				specified.
				[para]
 				The result of that is then validated with the [arg schema].
				The operator returns the result of the schema.

			[list_end]

			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerClass]
			class factory procedure is [cmd apply].

			[list_begin definitions]
			[def "The following options may be specified:"]
				[list_begin options]
				[opt_def -isolate]
					Use a local sandbox.

				[list_end]
			[list_end]

		[cmd_def "format [arg format] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. That result is then
				expanded and passed into Tcl's [cmd "format"] command along the supplied
				[arg format] argument as individual list items.
				So it works both on individual values and on the result of aggregate types
				and operators.
				[para]
				The operator returns the result of Tcl's [cmd "format"] command.

			[def "for composing"]
				Expands the Tcl input data and passes it into Tcl's [cmd "format"] command
				along the [arg format] argument as individual list items.
				[para]
 				The result of that is then validated with the [arg schema].
				The operator returns the result of the schema.

			[list_end]

		[cmd_def "mark [arg mark] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema].
				[para]
				The operator returns a Tcl list with the [arg mark] argument as the first
				list element and the result of the validation as the second list element.

			[def "for composing"]
				Treats the Tcl input data as a list and fail validation if the first list
				element isn't the same as the [arg mark] argument.
				[para]
 				If it passes, the second list element is then validated with the [arg schema].
				The operator returns the result of the schema.

			[list_end]

		[cmd_def "regsub [arg [opt options]] [arg exp] [arg replacement] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. The	result is then
				passed into Tcl's [cmd "regsub"] command along the supplied
				[arg exp] and [arg replacement] arguments.
				[para]
				The operator returns the result of Tcl's [cmd "regsub"] command.

			[def "for composing"]
				Passes the Tcl input data into Tcl's [cmd "regsub"] command
				along the [arg exp] and [arg replacement] arguments
				[para]
 				The result of that is then validated with the [arg schema].
				The operator returns the result of the schema.

			[def "The following options may be specified:"]
				[list_begin options]
				[opt_def -all]
					All ranges in the input value that match exp are found and
					substitution is	performed for each of these ranges.

				[opt_def -nocase]
					Upper-case characters in the input value will be converted to
					lower-case before matching against [arg exp]

				[opt_def -start [arg start]]
					Start matching at the position inside the input value
					specified by the [option -start] option instead of its
					beginning.

				[list_end]
			[list_end]

		[cmd_def "stringop [arg [opt options]] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. That result is then
				passed into Tcl's [cmd "string"] command along the supplied
				[arg options] arguments. All options are applied in their order of
				appearance in the [arg options]. They may appear multiple times.
				[para]
				The operator returns the result of Tcl's [cmd "string"] command.

			[def "for composing"]
				Passes the Tcl input data into Tcl's [cmd "string"] command
				along the supplied [arg options] arguments. All options are applied in
				their order of appearance in the [arg options]. They may appear
				multiple times.
				[para]
 				The result of that is then validated with the [arg schema].
				The operator returns the result of the schema.

			[def "The following general options may be specified:"]
				[list_begin options]
				[opt_def -nocase]
				[opt_def -case]
					Makes the option [option -map] work case-insensitively/case-sensitively
					until the other option is specified. By default that option works
					case-sensitively.

				[list_end]

			[def "The following string manipulations may be specified:"]
				[list_begin options]
				[opt_def -map [arg mapping]]
					Manipulates the input data by mapping it as by Tcl's [cmd "string map"]
					command. The options [option -nocase] and [option -case] are honored.

				[opt_def -range [arg range]]
					Manipulates the input data by removing anything but the [arg range] of
					characters from it, as by Tcl's [cmd "string range"] command.

				[opt_def -tolower [arg range]]
				[opt_def -toupper [arg range]]
					Manipulates the input data by forcing lowercase/uppercase on all characters in
					the [arg range] as by Tcl's [cmd "string tolower"] resp. [cmd "string toupper"]
					command.

				[opt_def -totitle [arg range]]
					Manipulates the input data by forcing uppercase on the first and lowercase on
					all other characters in the [arg range] as by Tcl's [cmd "string totitle"]
					command.

				[opt_def -trim [arg chars]]
				[opt_def -trimleft [arg chars]]
				[opt_def -trimright [arg chars]]
					Manipulates the input data by trimming all specified [arg chars] from it from
					left, right, or both. Specifying [arg chars] as an empty list makes it trim all
					whitespace (any character that tests positive for [cmd "string is space"]).
					That's a slight difference to Tcl's	[cmd "string trim"], [cmd "string trimleft"],
					[cmd "string trimright"] commands.

				[list_end]
			[list_end]
		[list_end]

	[def "Aggregate Result Formatting Operators"]
		[list_begin commands]

		[cmd_def "dictby [arg by] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema].
				That result is evaluated as a list of dicts of the form
				[example "{{key1 value1a key2 value2a} {key1 value1b key2 value2b}}"]
				as coming from the collecting methods [cmd duples] or [cmd array]
				of [cmd object]s. The argument [arg by] tells which key(s) from the
				inner dicts should be moved to form a dict of dicts as for example for
				[arg by] specified as [emph key1]
				[example "{value1a {key2 value2a} value1b {key2 value2b}}"]
				The argument [arg by] may be a Tcl list of keys, the resulting keys
				are Tcl lists of those values then.

			[def "for composing"]
				Rearranges the Tcl input data from a dict of dicts of the form
				[example "{value1a {key2 value2a} value1b {key2 value2b}}"]
				into a list of dicts of the form
				[example "{{key1 value1a key2 value2a} {key1 value1b key2 value2b}}"]
			 	The argument [arg by] tells which name the dict key should have when
				forming the inner dicts. The argument [arg by] may be a Tcl list of keys,
				the resulting inner dicts then have multiple additional keys.
				[para]
				The result is then validated with the [arg schema].

			[list_end]

		[cmd_def "dictbyindex [arg by] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema].
				[para]
				That result is evaluated as a list of lists of the form
				[example "{{value1a value2a value3a} {value1b value2b value3b}}"]
				as matching to the methods [cmd tuples] or [cmd array]
				of [cmd array]s or [cmd array] of [cmd "object -values"].
				The argument [arg by] tells which indices from the
				inner lists should be moved to form a dict of lists as for example
				for [arg by] specified as [emph 0]
				[example "{value1a {value2a value3a} value1b {value2b value3b}}"]
				The argument [arg by] may be a Tcl list of indices, the resulting
				keys are Tcl lists of those values then.

			[def "for composing"]
				Rearranges the Tcl input data from a dict of lists of the form
				[example "{value1a {value2a value3a} value1b {value2b value3b}}"]
				into a list of lists of the form
				[example "{{value1a value2a value3a} {value1b value2b value3b}}"]
				as matching to the methods [cmd tuples] or [cmd array]
				of [cmd array]s or [cmd array] of [cmd "object -values"].
				The argument [arg by] tells at which places inside
				the inner lists the dict keys should be inserted.
				The argument [arg by] may be a Tcl list of indices.
				[para]
				The result is then validated with the [arg schema].
				[para]
				[emph "Note:"] The result elements are constructed in an additive
				fashion. If several indices are given and they aren't in ascending
				order, the results may be unexpected. This is not a bug.

			[list_end]

		[cmd_def "lmap [arg [opt options]] [arg varList] [arg body] [arg schema]"]
			[list_begin definitions]
			[def "for collecting"]
				Validates the decoded JSON input with the [arg schema]. That result is
				passed into Tcl's [cmd "lmap"] command as a list along the [arg varList]
				and the supplied [arg body].
				[para]
				The operator returns the result of Tcl's [cmd "lmap"] command.

			[def "for composing"]
				Passes the Tcl input data as a list into Tcl's [cmd "lmap"] command
				along the [arg varList] and the supplied Tcl [arg body].
				[para]
 				The result of that is then validated with the [arg schema].
				The operator returns the result of the schema.

			[list_end]

			[emph "Note:"] The [arg methodName] for this method as used by the
			[cmd ::xjson::makeCollectorClass] and [cmd ::xjson::makeComposerClass]
			class factory procedures is [cmd apply].

			[list_begin definitions]
			[def "The following option may be specified:"]
				[list_begin options]
				[opt_def -isolate]
					Use a local sandbox.

				[list_end]
			[list_end]
		[list_end]
	[list_end]

[subsection "CUSTOM METHODS"]
	If neither the above collecting/composing methods nor sandboxed Tcl code from
	within the schema are sufficient to solve the particular validation and
	collecting/composing problem, you may want to create custom collecting methods.
	This can be done with relative ease. They have to be specified on the call to the
	[cmd "::xjson::makeCollectorClass"] or [cmd "::xjson::makeComposerClass"] class
	factory procedure with a unique [arg "methodName"] and a [arg "methodDefinition"].

	[list_begin definitions]
	[def [arg "methodName"]]
		Each [arg "methodName"] may define multiple methods for use within the schema
		that share the same definition but differ in details, such as the accepted
		parameters and options. They are sorted out from within their Tcl body by the
		actual method name used in the schema then.
		The following [arg "methodName"]s are reserved for the builtin methods:
		[para]
		[cmd "allof anyof apply array boolean const decoded default expr dictby dictbyindex discard dubious escalate format if nest not null number object oneof optional otherwise pass regsub string stringop switch"]
		[para]
		You may of course overwrite those as well but it will break compatibility with
		existing schemas. For forward compatibility with new versions of
		[const "xjson"], it's best to mark private methods with an [const "@"] in
		front. Such methods names will never be used as the names of builtins by
		the [const "xjson"] package.

	[def [arg "methodDefinition"]]
		The [arg "methodDefinition"] must be a list that resembles a parameter list.

		[list_begin definitions]
		[def "Its syntax is either"]
			[opt [arg methodOptions]] [opt [arg {aliasName aliasParameters ...}]] [arg body]

		[def "or (simplified)"]
			[opt [arg methodOptions]] [arg methodParameters] [arg body]

		[list_end]

		In the simplified variant, the method has only one name and one set of parameters.
		The following [arg aliasName]s are reserved for the builtin methods:
		[para]
		[cmd "allof anyof apply array boolean const decoded default duple duples encoded expr dictby dictbyindex discard dubious escalate format if integer lmap nest not null number object oneof optional otherwise pass regsub string stringop switch tuple tuples"]

		[list_begin definitions]
		[def "The following [arg methodOptions] may be specified:"]
			[list_begin options]
			[opt_def -unsafe]
				This method does potentially unsafe things (such as reading arbitrary files
				whose names	are specfied in the schema, or evaluating code outside of a
				sandbox) and that may only be used in trusted schemas.

			[opt_def -dubious]
				The schema arguments of this method may come from a dubious (non-trusted) source.

			[opt_def --]
				Marks the end of options. The argument following this one will be treated as
				an argument even if it starts with a [option -].

			[list_end]

		[def "The [arg aliasParameters]/[arg methodParameters] are a list of parameter names."]

			Option names must start with a [const "-"], otherwise the parameter name is
			that of a mandatory argument. Each argument or option name may be followed by
			an indicator that shows its type and additional constraints the schema parser
			should check during the construction of the collector/composer object.
			[para]
			The default argument type is a string. The default option type is a switch
			that is true when it is listed.
			[para]
			The indicators are:

			[list_begin definitions]
			[def [const "="]]
				A string.

			[def [const "=[arg exp]"]]
				A string that matches the regular expression [arg "exp"].

			[def [const "#"]]
				An integer.

			[def [const "##"]]
				A list of integers.

			[def [const "/"]]
				A number -integer or float-.

			[def [const "!=123"]]
				An integer that is not 123.

			[def [const "!=123.0"]]
				A number -integer or float- that is neither 123 nor 123.0.

			[def [const ">123"]]
				An integer that is larger than 123.

			[def [const ">123.0"]]
				A number -integer or float- that is larger than 123 or 123.0.

			[def [const "<123"]]
				An integer that is smaller than 123.

			[def [const "<123.0"]]
				A number -integer or float- that is smaller than 123 or 123.0.

			[def [const ">=123"]]
				An integer that is larger than or equal 123.

			[def [const ">=123.0"]]
				A number -integer or float- that is larger than or equal 123 or 123.0.

			[def [const "<=123"]]
				An integer that is smaller than or equal 123.

			[def [const "<=123.0"]]
				A number -integer or float- that is smaller than or equal 123 or 123.0.

			[def [const "~"]]
				A regular expression as understood by Tcl's [cmd "regexp"] command.

			[def [const "%"]]
				A format string as understood by Tcl's [cmd "format"] command.

			[def [const "'"]]
				A timezone name as understood by Tcl's [cmd "clock -timezone"] command option.

			[def [const "."]]
				A string index as understood by Tcl's [cmd "string index"] command.

			[def [const "-"]]
				A string range as understood by Tcl's [cmd "string range"] command
				or a string index as understood by Tcl's [cmd "string index"] command.

			[def [const "|"]]
				A list of pairs as understood by Tcl's [cmd "string map"] command.

			[def [const ":"]]
				A dict as understood by Tcl's [cmd "dict"] command.

			[def [const "!"]]
				Tcl code, either as a body or as an expression.

			[def [const "{}"]]
				A schema.

			[def [const "{_}"]]
				A list of schemas.

			[def [const "{|}"]]
				A dict of schema-schema pairs.

			[def [const "{:}"]]
				A dict of key-schema pairs.

			[list_end]

		[def "The [arg body] is the Tcl body of the method."]

		[list_end]
	[list_end]
	See the files
	[file builtinCollectingMethods.tcl] and [file builtinComposingMethods.tcl]
	from the library installation directory (often [file /usr/share/tcl/xjson1.5/])
	for examples on how to write your own custom methods.

[subsection "NESTING"]
	With each collector/composer object you construct from the classes produced by
	[cmd "::xjson::makeCollectorClass"] or [cmd "::xjson::makeComposerClass"], you
	may specify other collector/composer objects that should be accessible from
	within the registered schema by a
	[arg nestedCollectorName]/[arg nestedComposerName] alias.  The rationale of
	this is creating libraries of different collector/composer objects for often
	used JSON aggregates in your application, and calling them from an uplevel or
	the toplevel schema.
	[para]
	The [cmd nest] method makes use of this function. It takes an alias name and
	calls the [method collect]/[method compose] method of the nested object with the
	decoded JSON input data at that point, and the path.
	The nested object takes care of the input data, validates it with
	its own schema, and returns the result to the calling object.
	[para]
	The specified nested objects do not have to exist when the calling object is
	constructed. It is also not checked which class the nested object has. You may
	specify any object that has a [method collect]/[method compose] method with the
	same semantics as those produced by
	[cmd "::xjson::makeCollectorClass"] resp. [cmd "::xjson::makeComposerClass"].
	[para]
	The dubious/trusted flag is local to each object. This may
	be used to create collector/composer objects with application provided
	schemas and elevated rights that a object with user-provided schem
	and restricted rights may call.

[subsection "SANDBOXING"]
	User supplied data is never evaluated as code by any builtin method.
	All the considerations below are about configuration-supplied rather than
	programmer-supplied schemas.
	[para]
	On construction of the collector/composer object, you may specify the
	[option "-trusted"]	option to enable Tcl code evaluation from the schema.
	If not specified, using those methods and options in the supplied schema
	will throw an error instead and the object won't be constructed at all.
	[para]
	Schemas may specify collecting/composing methods (e.g. [cmd "apply"], [cmd "expr"],
	[cmd "lmap"]) or options (e.g. [option "-test"], [option "-transform"]) that
	rely on Tcl code supplied from within the schema. To use such schemas in a safe
	fashion, all that Tcl code is executed in a safe interpreter (a sandbox) as
	supplied by Tcl's [cmd "interp -safe"] command.
	[para]
	Sandbox creation and destruction after use happens automatically whenever
	data is collected/composed. That sandbox is shared by all methods in the schema
	and may also be used to pass values in global variables between methods.
	As a shortcut, all of the methods that have	arguments or options allowing
	to specify Tcl code also have an option [option "-isolate"], that creates a
	local sandbox just for that method automatically.

[section "NULL HANDLING"]
	The procedures [cmd "::xjson::encode"], [cmd "::xjson::recode"], and
	[cmd "::xjson::decode"] treat JSON
	[emph null] values literally. As with the JSON boolean values [emph true] and
	[emph false] that are coded as [const "literal true"] resp.
	[const "literal false"], JSON [emph null] values are decoded as
	[const "literal null"] by [cmd "::xjson::decode"] and the same literal needs to
	be specified to [cmd "::xjson::encode"] to produce a JSON [emph null] value.
	[cmd "::xjson::decode"] returns an empty list on empty JSON input, and
	[cmd "::xjson::encode"] and [cmd "::xjson::recode"] throw an error on an
	attempt to encode an empty list.
	[para]
	In contrast, the collector/composer objects constructed from the classes
	produced by
	[cmd "::xjson::makeCollectorClass"] and [cmd "::xjson::makeComposerClass"]
	treat JSON [emph null] values symbolically.
	[para]
	A [const "literal null"] a collector class finds in its decoded JSON input is
	treated as if the data field it fills isn't there. JSON [emph null]s in arrays
	are simply skipped, and they also don't count for the array length. JSON
	[emph null]s as the value of an object field are treated the same as if that
	field wasn't specified in that object. Schemas may specify a [cmd null]
	collecting method that validates a [const "literal null"]. It is however
	treated as such and will trigger the above null handling in the uplevel schema.
	An empty list in the decoded JSON input data is treated the same as a
	[const "literal null"]. A missing data field is also treated like a
	[const "literal null"].
	[para]
	In composer classes, the methods that emit JSON types have a special option
	[option "-null"] that allows the schema author to tell which Tcl input value
	should be treated as [const "null"], if any. If not specified, there will
	never be a [const null] value emitted at that place. The [cmd "optional"]
	method has a special option [option "-emitnull"] that allows the schema author
	to specify if downlevel [const "null"]s should be inserted into the emitted
	JSON object or array literally instead of simply leaving out that field.
	[para]
	To change that symbolic treatment of JSON [emph null]s at specific places, you
	can use the [cmd default] collecting method and tell a default value that
	should be used whenever a [emph null] is encountered in the JSON input at that
	place.

[section "DATA FORMATS"]

[subsection "DECODED JSON FORMAT"]
	The decoded JSON format as returned by the [cmd "::xjson::decode"] and accepted
	by the [cmd "::xjson::encode"] and [cmd "::xjson::recode"] commands is a nested
	list of type-data pairs.

	[list_begin definitions]
	[def "The following types are understood:"]
		[list_begin commands]
			[cmd_def "array [arg list]"]
				Represents a JSON array. The [arg list] argument is a list of type-data pairs.

			[cmd_def "object [arg dict]"]
				Represents a JSON object. The [arg dict] argument is a dict of Tcl strings used
				for the JSON object keys and the values as type-data pairs.

			[cmd_def "string [arg value]"]
				Represents a JSON string. The [arg value] argument is the Tcl representation of
				that string.

			[cmd_def "number [arg value]"]
				Represents a JSON number. The [arg value] argument is the Tcl representation of
				that number.

			[cmd_def "literal [arg value]"]
				Represents a JSON literal. The [arg value] argument is one of the constants
				[const true], [const false], or [const null].
				[para]
				[emph "Note:"] Arbitrary Tcl boolean values are not accepted by
				[cmd "::xjson::encode"] and [cmd "::xjson::recode"].
				The [arg value] must be one of the constants above. The builtin [method boolean]
				method of the composer classes is aware of that.

			[cmd_def "encoded [arg json]"]
				This type is meant for encoding in multiple steps.
				It is accepted by [cmd "::xjson::encode"] and [cmd "::xjson::recode"], it is
				never returned by [cmd "::xjson::decode"].
				[cmd "::xjson::encode"] does no checks on the [arg json] argument,
				it must be valid JSON.
				[cmd "::xjson::recode"] however checks the [arg json] argument for syntatic
				validity as it recodes it.

			[cmd_def "decoded [arg decodedJson]"]
				This type is meant for encoding in multiple steps.
				It is accepted by [cmd "::xjson::encode"] and [cmd "::xjson::recode"], it is
				never returned by [cmd "::xjson::decode"].
				The [arg decodedJson] is first encoded by [cmd "::xjson::encode"], then
				inserted in the output. This is sometimes useful if the type information in
				the input is dynamic as well.
				[cmd "::xjson::recode"] checks the [arg decodedJson] argument for syntatic
				validity as it recodes it.

		[list_end]
	[list_end]

[subsection "JSON PATCH FORMAT"]

	The JSON patch format as returned by the [cmd "::xjson::diff"] and accepted
	by the [cmd "::xjson::patch"] and [cmd "::xjson::rpatch"] commands is a nested
	list of diff operations.

	[list_begin definitions]
	[def "The following operations are understood:"]
		[list_begin commands]
			[cmd_def "replace [arg oldDecodedJson] [arg newDecodedJson]"]
				Replace [arg oldDecodedJson] with [arg newDecodedJson].
				This operation works on all decoded JSON types.

			[cmd_def "keys [arg dictOfOperations]"]
				Apply the [arg dictOfOperations] to the noted keys of an [const object]
				decoded JSON type.

			[cmd_def "add [arg decodedJson]"]
				Add the [arg decodedJson] to the [const object] under the noted key.
				This operation works only inside a [const keys] operation.

			[cmd_def "delete [arg decodedJson]"]
				Delete the [arg decodedJson] from the [const object] under the noted key.
				This operation works only inside a [const keys] operation.

			[cmd_def "indices [arg pairsOfOperations]"]
				Apply the [arg pairsOfOperations] to the noted indices of an [const array]
				decoded JSON type.

			[cmd_def "insert [arg listOfDecodedJson]"]
				Insert the [arg listOfDecodedJson] into the [const array] at the noted index.
				This operation works only inside an [const indices] operation.

			[cmd_def "remove [arg listOfDecodedJson]"]
				Remove the [arg listOfDecodedJson] from the [const array] at the noted index.
				This operation works only inside an [const indices] operation.

		[list_end]
	[list_end]

[section "EXAMPLES"]

[subsection "DECODING EXAMPLES"]
	Decode an array of array of numbers.

	[example_begin]
		% ::xjson::decode {[lb][lb]1,2[rb],[lb]3,4[rb][rb]}
		array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}

	[example_end]

	Decode an object of various types.

	[example_begin]
		% ::xjson::decode {{"foo":"hello","bar":42,"quux":null}}
		object {foo {string hello} bar {number 42} quux {literal null}}

	[example_end]

	Same with arbitrary whitespace.

	[example_begin]
		% ::xjson::decode {
		{
		    "foo":  "hello",
		    "bar":  42,
		    "quux": null
		}
		}
		object {foo {string hello} bar {number 42} quux {literal null}}

	[example_end]

[subsection "ENCODING EXAMPLES"]
	Encode an array of array of numbers.

	[example_begin]
		% ::xjson::encode {array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}} 0 {}
		[lb][lb]1,2[rb],[lb]3,4[rb][rb]

	[example_end]

	Encode an object of various types.

	[example_begin]
		% ::xjson::encode {object {foo {string hello} bar {number 42} quux {literal null}}} 0 {}
		{"foo":"hello","bar":42,"quux":null}

	[example_end]

	Same with pretty printing.

	[example_begin]
		% ::xjson::encode {object {foo {string hello} bar {number 42} quux {literal null}}}
		{
		    "foo":  "hello",
		    "bar":  42,
		    "quux": null
		}

	[example_end]

	Encode with pre-encoded data.

	[example_begin]
		% set json {"hello"}
		% ::xjson::encode [lb]list object [lb]list foo [lb]list encoded $json[rb] bar {number 42} quux {literal null}[rb][rb] 0 {}
		{"foo":"hello","bar":42,"quux":null}

	[example_end]

	Encode with nested decoded data.

	[example_begin]
		% set type decoded
		% set data {string hello}
		% ::xjson::encode [lb]list object [lb]list foo [lb]list $type $data[rb] bar {number +42} quux {literal null}[rb][rb] 0 {}
		{"foo":"hello","bar":42,"quux":null}

	[example_end]

[subsection "RECODING EXAMPLES"]
	Recode pre-encoded data.

	[example_begin]
		% set json {"oof rab"}
		% ::xjson::recode [lb]list object [lb]list foo [lb]list encoded $json[rb] bar {number +42} quux {literal null}[rb][rb]
		object {foo {string {oof rab}} bar {number 42} quux {literal null}}

	[example_end]

	Recode with nested decoded data.

	[example_begin]
		% set type decoded
		% set data {string "oof rab"}
		% ::xjson::recode [lb]list object [lb]list foo [lb]list $type $data[rb] bar {number +42} quux {literal null}[rb][rb]
		object {foo {string {oof rab}} bar {number 42} quux {literal null}}

	[example_end]

[subsection "DIFF EXAMPLES"]
	Feed two sets of slightly different JSON data into the decoder and remember the result.

	[example_begin]
		% set old [lb]::xjson::decode {
		    {
		        "articles": [lb]
		            {
		                "id":    101,
		                "name":  "Pizzapane bianca",
		                "price": 4.95
		            },
		            {
		                "id":    120,
		                "name":  "Pizza Regina",
		                "price": 9.8
		            },
		            {
		                "id":    139,
		                "name":  "Wunschpizza",
		                "price": 12.70
		            },
		            {
		                "id":    201,
		                "name":  "Rucola",
		                "extra": true,
		                "price": 1
		            }
		        [rb]
		    }
		}[rb]

		% set new [lb]::xjson::decode {
		    {
		        "articles": [lb]
		            {
		                "id":    101,
		                "name":  "Pizzapane bianca",
		                "extra": true,
		                "price": 4.95
		            },
		            {
		                "id":    120,
		                "name":  "Pizza Regina",
		                "price": 9.80
		            },
		            {
		                "id":    138,
		                "name":  "Pizza Hawaii",
		                "price": 12.00
		            },
		            {
		                "id":    139,
		                "name":  "Wunschpizza",
		                "price": 13.50
		            },
		            {
		                "id":    201,
		                "name":  "Rucola",
		                "price": 1
		            }
		        [rb]
		    }
		}[rb]

	[example_end]

	Calculate the patch data.

	[example_begin]
		% ::xjson::diff $old $new
		keys {articles {indices {0 {keys {extra {add {literal true}}}} 2 {remove {{object {id {number 139} name {string Wunschpizza} price {number 12.7}}} {object {id {number 201} name {string Rucola} extra {literal true} price {number 1}}}}} 2 {insert {{object {id {number 138} name {string {Pizza Hawaii}} price {number 12.0}}} {object {id {number 139} name {string Wunschpizza} price {number 13.5}}} {object {id {number 201} name {string Rucola} price {number 1}}}}}}}}

	[example_end]

[subsection "PATCH EXAMPLES"]
	Feed JSON data into the decoder and remember the result.

	[example_begin]
		% set old [lb]::xjson::decode {
		    {
		        "articles": [lb]
		            {
		                "id":    101,
		                "name":  "Pizzapane bianca",
		                "price": 4.95
		            },
		            {
		                "id":    120,
		                "name":  "Pizza Regina",
		                "price": 9.8
		            },
		            {
		                "id":    139,
		                "name":  "Wunschpizza",
		                "price": 12.70
		            },
		            {
		                "id":    201,
		                "name":  "Rucola",
		                "extra": true,
		                "price": 1
		            }
		        [rb]
		    }
		}[rb]

	[example_end]

	Dig out matching patch data.

	[example_begin]
		% set patch {keys {articles {indices {0 {keys {extra {add {literal true}}}} 2 {remove {{object {id {number 139} name {string Wunschpizza} price {number 12.7}}} {object {id {number 201} name {string Rucola} extra {literal true} price {number 1}}}}} 2 {insert {{object {id {number 138} name {string {Pizza Hawaii}} price {number 12.0}}} {object {id {number 139} name {string Wunschpizza} price {number 13.5}}} {object {id {number 201} name {string Rucola} price {number 1}}}}}}}}}

	[example_end]

	Apply the patch and encode it.

	[example_begin]
		% ::xjson::encode [lb]::xjson::patch $old $patch[rb]
		{
		    "articles": [lb]
		        {
		            "id":    101,
		            "name":  "Pizzapane bianca",
		            "price": 4.95
                    "extra": true
		        },
		        {
		            "id":    120,
		            "name":  "Pizza Regina",
		            "price": 9.8
		        },
		        {
		            "id":    138,
		            "name":  "Pizza Hawaii",
		            "price": 12.0
		        },
		        {
		            "id":    139,
		            "name":  "Wunschpizza",
		            "price": 13.5
		        },
		        {
		            "id":    201,
		            "name":  "Rucola",
		            "price": 1
		        }
		    [rb]
		}

	[example_end]

[subsection "JSON VALIDATION AND DATA COLLECTING EXAMPLE"]
	Create a collector class with the class factory and the builtin methods. Even
	for advanced usage, you only ever need to do this once.  More than once only if
	you want to create multiple collector classes with a different set of builtin
	and your own collection methods, or different options.

	[example_begin]
		% ::xjson::makeCollectorClass ::myCollectorClass

	[example_end]

	Create a collector object with a schema. You need to do this once per different
	schema you want to use.

	[example_begin]
		% set ::mycollector [lb]::myCollectorClass #auto {
		    object {
		        "articles" {
		            dictby "id" {array -max 100 {object {
		                "id"    integer
		                "extra" {default false boolean}
		                "name"  string
		                "price" {format "%.2f" number}
		            }}}
		        }
		    }
		}[rb]

	[example_end]

	Feed JSON data into the decoder, and the decoded json data into the collector
	object.

	[example_begin]
		% $::mycollector collect [lb]::xjson::decode {
		    {
		        "articles": [lb]
		            {
		                "id":    101,
		                "name":  "Pizzapane bianca",
		                "price": 4.95
		            },
		            {
		                "id":    120,
		                "name":  "Pizza Regina",
		                "price": 9.8
		            },
		            {
		                "id":    139,
		                "name":  "Wunschpizza",
		                "price": 12.70
		            },
		            {
		                "id":    201,
		                "name":  "Rucola",
		                "extra": true,
		                "price": 1
		            }
		        [rb]
		    }
		}[rb]
		articles {101 {extra false name {Pizzapane bianca} price 4.95} 120 {extra false name {Pizza Regina} price 9.80} 139 {extra false name Wunschpizza price 12.70} 201 {extra true name Rucola price 1.00}}

	[example_end]

[subsection "JSON COMPOSING EXAMPLE"]
	Create a composer class with the class factory and the builtin methods. Even
	for advanced usage, you only ever need to do this once.  More than once only if
	you want to create multiple composer classes with a different set of builtin
	and your own composer methods, or different options.

	[example_begin]
		% ::xjson::makeComposerClass ::myComposerClass

	[example_end]

	Create a composer object with a schema. You need to do this once per different
	schema you want to use.

	[example_begin]
		% set ::mycomposer [lb]::myComposerClass #auto {
		    array {
		        object {
		            id   integer
		            name string
		        }
		    }
		}[rb]

	[example_end]

	Feed Tcl data into the composer object, and the result into the encoder.

	[example_begin]
		% ::xjson::encode [lb]$::mycomposer compose {{id 7 name foo} {id 3 name bar}}[rb]
		[lb]
		    {
		        "id":   7,
		        "name": "foo"
		    },
		    {
		        "id":   3,
		        "name": "bar"
		    }
		[rb]
	[example_end]

[subsection "JSON RECOMPOSING EXAMPLE"]
	This toy example decodes and validates a JSON input, collects the data, then recomposes the data into JSON.

	[example_begin]
		% ::xjson::makeCollectorClass ::myCollectorClass
		% ::xjson::makeComposerClass ::myComposerClass

		% set ::mycollector [lb]::myCollectorClass #auto {
			dictbyindex 1 {array {object -values {id integer name {stringop -toupper {0 end} string} comment string}}}
		}[rb]

		% set ::mycomposer [lb]::myComposerClass #auto {
			dictbyindex 1 {array {object -values {id integer name {stringop -tolower {0 end} string} comment string}}}
		}[rb]

		% set step0 {[lb]{"id": 1, "name": "abc", "comment": "foo"}, {"id": 981, "name": "xyz", "comment": "bar"}[rb]}
		[lb]{"id": 1, "name": "abc", "comment": "foo"}, {"id": 981, "name": "xyz", "comment": "bar"}[rb]

		% set step1 [lb]::xjson::decode $step0[rb]
		array {{object {id {number 1} name {string abc} comment {string foo}}} {object {id {number 981} name {string xyz} comment {string bar}}}}

		% set step2 [lb]$mycollector collect $step1[rb]
		ABC {1 foo} XYZ {981 bar}

		% set step3 [lb]$mycomposer compose $step2[rb]
		array {{object {id {number 1} name {string abc} comment {string foo}}} {object {id {number 981} name {string xyz} comment {string bar}}}}

		% set step4 [lb]::xjson::encode $step3 0 {}[rb]
		[lb]{"id":1,"name":"abc","comment":"foo"},{"id":981,"name":"xyz","comment":"bar"}[rb]

	[example_end]

[manpage_end]
}

regsub -all -line {^\t*} $data {} data
regsub -all {\t} $data { } data

foreach {format name} {html xjson.html nroff xjson.n markdown README.md} {
	::doctools::new $name -format $format
	set fd [open $name w+]
	puts $fd [$name format $data]
	close $fd
}
