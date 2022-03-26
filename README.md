
[//000000001]: # (xjson \- xjson\.tcl)
[//000000002]: # (Generated from file '' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2021 Jan Kandziora <jjj@gmx\.de>, BSD\-2\-Clause license)
[//000000004]: # (xjson\(n\) 1\.5  "xjson\.tcl")

# NAME

xjson \- extended JSON functions for Tcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [BUGS](#section2)

  - [PROCEDURES](#section3)

  - [COLLECTOR AND COMPOSER CLASS USAGE](#section4)

      - [COLLECTOR OBJECT USAGE](#subsection1)

      - [COMPOSER OBJECT USAGE](#subsection2)

      - [COLLECTOR AND COMPOSER SCHEMAS](#subsection3)

      - [BUILTIN METHODS](#subsection4)

      - [CUSTOM METHODS](#subsection5)

      - [NESTING](#subsection6)

      - [SANDBOXING](#subsection7)

  - [NULL HANDLING](#section5)

  - [DATA FORMATS](#section6)

      - [DECODED JSON FORMAT](#subsection8)

      - [JSON PATCH FORMAT](#subsection9)

  - [EXAMPLES](#section7)

      - [DECODING EXAMPLES](#subsection10)

      - [ENCODING EXAMPLES](#subsection11)

      - [RECODING EXAMPLES](#subsection12)

      - [DIFF EXAMPLES](#subsection13)

      - [PATCH EXAMPLES](#subsection14)

      - [JSON VALIDATION AND DATA COLLECTING EXAMPLE](#subsection15)

      - [JSON COMPOSING EXAMPLE](#subsection16)

      - [JSON RECOMPOSING EXAMPLE](#subsection17)

  - [Keywords](#keywords)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6\-  
package require itcl 4\.0\-  
package require struct::set  
package require struct::list  
package require xjson ?1\.5?  

__::xjson::decode__ *json* ?*indexVar*?  
__::xjson::encode__ *decodedJson* ?*indent*? ?*tabulator*? ?*nest*?  
__::xjson::recode__ *decodedJson*  
__::xjson::diff__ *oldDecodedJson* *newDecodedJson*  
__::xjson::patch__ *decodedJson* *patch*  
__::xjson::rpatch__ *decodedJson* *patch*  
__::xjson::makeCollectorClass__ ?*options*? *collectorClassName* ?*methodName methodDefinition \.\.\.*?  
*collectorClassName* *collectorObjName* ?*options*? ?*nestedCollectorName nestedCollectorObjName \.\.\.*? *schema*  
*collectorObjName* __collect__ *decodedJson* ?*path*?  
*collectorObjName* __printSchema__ ?*indent*?  
__::xjson::makeComposerClass__ ?*options*? *composerClassName* ?*methodName methodDefinition \.\.\.*?  
*composerClassName* *composerObjName* ?*options*? ?*nestedComposerName nestedComposerObjName \.\.\.*? *schema*  
*composerObjName* __compose__ *tclData* ?*path*?  
*composerObjName* __printSchema__ ?*indent*?  

# <a name='description'></a>DESCRIPTION

This package is a set of extended JSON functions for Tcl\. It allows decoding,
encoding, and pretty\-printing of JSON structures from Tcl structures and vice
versa\. In addition, decoded JSON that was created by functions outside of this
package may be recoded\. A set of diff and patch functions tailored to JSON
allows to track changes in complicated JSON structures easily\.

The main feature of this package however are two class factories that produce
itcl classes that construct validator and data collector/composer objects\. Those
objects take a schema in a simple nested list syntax on construction, so they
are then prepared for validating against that schema again and again\. The schema
may also feature various operators that manipulate the validated data so that
further configuration specific processing \(e\.g\. data formatting\) can be
specified in the realm of the administrator rather than the programmer\.

Schemas may be nested and libraries of commonly used collector/composer objects
and their schemas can be constructed easily\.

The objects also feature automatic sandboxing, so they can specify Tcl code for
doing more complicated tests or data manipulations\. In addition, the programmer
may define their own barebone, non\-sandboxed methods when creating a new class
with the class factory\. For sandboxes and those methods, an additional security
mechanism exists\. Schemas may be marked as trusted \(programmer/administrator
supplied\) and only such trusted schemas may use Tcl code or user\-defined methods
that are marked unsafe\.

The procedures and objects return error messages that indicate the offending
data and the non\-matching schema in a human\-readable, pretty\-printed way\. They
are fit for supplying them to the interface user, which is usually a programmer
or administrator of an another software interfacing the software using xjson\.

# <a name='section2'></a>BUGS

This manpage is intimidating\. Please go right to the various
[EXAMPLES](#section7) sections at the bottom for maintaining a slow pulse\.

# <a name='section3'></a>PROCEDURES

The package defines the following public procedures:

  - __::xjson::decode__ *json* ?*indexVar*?

    Decode the given JSON encoded data to nested Tcl data telling both types and
    values\. The optional *indexVar* argument is the name of a variable that
    holds the index at which decoding begins and will hold the index immediately
    following the end of the decoded element\. If *indexVar* is not specified,
    the entire JSON input is decoded, and it is an error for it to be followed
    by any non\-whitespace characters\.

    See the section [DECODED JSON FORMAT](#subsection8) for a description
    of the data format returned by this procedure\.

    See the section [DECODING EXAMPLES](#subsection10) for examples\.

  - __::xjson::encode__ *decodedJson* ?*indent*? ?*tabulator*? ?*nest*?

    Encode the given Tcl *decodedJson* data as JSON and pretty\-print it with a
    base indentation as given with the optional *indent* argument\. The
    likewise optional *nest* argument can be used to indicate the nesting
    level\. If it's not zero, the first line of the JSON output will not be
    indented\. This is useful when the first line is a brace or bracket following
    an already indented field name\.

    The pretty\-printer indents with \\t characters by default but this can be
    changed by setting the optional *tabulator* argument\. If it is set to \{\},
    the pretty printer is disabled completely and __::xjson::encode__
    returns condensed JSON\.

    See the section [DECODED JSON FORMAT](#subsection8) for a description
    of the data format accepted by this procedure\.

    See the section [ENCODING EXAMPLES](#subsection11) for examples\.

  - __::xjson::recode__ *decodedJson*

    Recode the given Tcl *decodedJson* data so that the included
    __encoded__ and __decoded__ data types are replaced by their encoded
    and decoded equivalents\. The other types are recoded as
    __::xjson::encode__ followed by a subsequent __::xjson::decode__
    would do it\. This may be used to check data coming from sources outside of
    this library for syntatic correctness as well as for feeding it into a
    collector class\.

    *Note:* This function is basically a very lightweight alternative to

    > % ::xjson::decode \[::xjson::encode *decodedJson*\]

    See the section [DECODED JSON FORMAT](#subsection8) for a description
    of the data format accepted and produced by this procedure\.

    See the section [RECODING EXAMPLES](#subsection12) for examples\.

  - __::xjson::diff__ *oldDecodedJson* *newDecodedJson*

    Compare the given Tcl *oldDecodedJson* and *newDecodedJson* data and
    produce a *patch* suitable for the __::xjson::patch__ and
    __::xjson::rpatch__ procedures\.

    See the section [DECODED JSON FORMAT](#subsection8) for a description
    of the data format accepted by this procedure\. See the section [JSON PATCH
    FORMAT](#subsection9) for a description of the data format returned by
    this procedure\.

    See the section [DIFF EXAMPLES](#subsection13) for examples\.

  - __::xjson::patch__ *decodedJson* *patch*

    Apply the *patch* produced by a previous __::xjson::diff__ to the Tcl
    *decodedJson* data\. The result of this function is put as Tcl decoded JSON
    format as well\.

    See the section [DECODED JSON FORMAT](#subsection8) for a description
    of the data format accepted and returned by this procedure\. See the section
    [JSON PATCH FORMAT](#subsection9) for a description of the patch format
    accepted by this procedure\.

    See the section [PATCH EXAMPLES](#subsection14) for examples\.

  - __::xjson::rpatch__ *decodedJson* *patch*

    Apply the *patch* produced by a previous __::xjson::diff__ to the Tcl
    *decodedJson* data in reverse\. That means, the operations noted in the
    patch are flipped in both their order and meaning so that the result of a
    previous identical patch is reversed\. The result of this function is put as
    Tcl decoded JSON format as well\.

    *Note:* The result of this procedure is not literally but only
    functionally identical to the original, unpatched data\. That is because the
    patch format does not store information about the order of JSON object keys\.
    If the forward patch had removed keys from an object, the re\-inserted keys
    are simply appended to the forward\-patched object\.

    See the section [DECODED JSON FORMAT](#subsection8) for a description
    of the data format accepted and returned by this procedure\. See the section
    [JSON PATCH FORMAT](#subsection9) for a description of the patch format
    accepted by this procedure\.

    See the section [PATCH EXAMPLES](#subsection14) for examples\.

  - __::xjson::makeCollectorClass__ ?*options*? *collectorClassName* ?*methodName methodDefinition \.\.\.*?

  - __::xjson::makeComposerClass__ ?*options*? *composerClassName* ?*methodName methodDefinition \.\.\.*?

    Make a JSON collector/composer class named
    *collectorClassName*/*composerClassName* according to the given options
    and additional method definitions\.

    Those procedures return the name of the produced class\.

    For definining your own methods, see the section [CUSTOM
    METHODS](#subsection5)\.

      * The following options are understood:

          + __\-nobuiltins__

            Make a class without any builtin collecting/composing methods\. For
            receiving a useful class despite specifying this option, you have to
            supply your own collecting/composing methods by the *methodName
            methodDefinition \.\.\.* arguments then\.

            *Note:* For not including selected builtin methods, you can define
            those as *methodName* \{\}\. That excludes *methodName*\.

          + __\-tabulator__ *string*

            Sets the tabulator for pretty\-printing the subschema and offending
            JSON data in error messages returned by the objects of the class\.

          + __\-maxldepth__ *integer*

            Sets the maximum depth of methods in one line before there is a line
            break inserted when printing the subschema in error messages
            returned by the objects of the class\.

          + __\-maxweight__ *integer*

            Sets the maximum weight of methods before there is a line break
            inserted when printing the subschema in error messages returned by
            the objects of the class\.

          + __\-maxlines__ *integer*

            Sets the maximum number of lines in a printed value before they are
            folded in error messages returned by the objects of the class\.
            Setting this option to the empty string disables the folding\.

          + __\-\-__

            Marks the end of options\. The argument following this one will be
            treated as an argument even if it starts with a __\-__\.

Read the following section [COLLECTOR AND COMPOSER CLASS USAGE](#section4)
on how to use the classes made by those procedures\.

# <a name='section4'></a>COLLECTOR AND COMPOSER CLASS USAGE

The __::xjson::makeCollectorClass__ and __::xjson::makeComposerClass__
class factory procedures each make a class that is meant to be used to construct
one or more collector respective composer objects using the following
constructors:

  - *collectorClassName* *collectorObjName* ?*options*? ?*nestedCollectorName nestedCollectorObjName \.\.\.*? *schema*

  - *composerClassName* *composerObjName* ?*options*? ?*nestedComposerName nestedComposerObjName \.\.\.*? *schema*

    Instantiate a collector/composer object named
    *collectorObjName*/*composerObjName* according to the given *options*
    and *schema*\. Nested collector/composer objects used by the schema must be
    announced with their *nestedCollectorName*/*nestedComposerName* used as
    an alias inside the schema and their actual
    *nestedCollectorObjName*/*nestedComposerObjName* outside of the schema\.

    When *objName* contains the string "\#auto", that string is replaced with
    an automatically generated name\. Names have the form *className<number>*,
    where the *className* part is modified to start with a lowercase letter\.
    So if the *className* was "myCollectorClass" and the *objName* was
    "\#auto\.myCollector", the resulting name was "myCollectorClass0\.myCollector"\.
    The constructor returns the actual *objName* generated that way\.

    Usually, specifying *collectorObjName*/*composerObjName* as "\#auto" and
    storing the result of the constructor call in a variable is most convenient\.

    The schema is parsed on object construction and all possible pathes are
    walked\. That way, the schema itself is validated before it is even used\.
    Nested schemas are not walked as they are validated on their own object
    construction\. Their collector/composer objects also only have to be
    available when the data is collected/composed\.

    See the section [COLLECTOR AND COMPOSER SCHEMAS](#subsection3) for an
    explanation of the schema data structure\.

      * The following options are understood:

          + __\-trusted__

            Mark the schema loaded into the constructed object as coming from a
            trustworthy source, such as a programmer of an application or the
            administrator of that software on the local machine\.

            Such schemas are allowed to execute Tcl code inside an automatically
            provided sandbox\. Non\-trusted schemas throw an error during schema
            validation if any collecting/composing method used in the schema has
            an argument or option that specifies code\.

            Such schemas are also allowed to specify collecting/composing
            methods that are marked unsafe, for example because they allow to
            specify arbitrary filenames in the schema, or allow the execution of
            arbitrary code from the schema outside of a sandbox\. Again,
            non\-trusted schemas throw an error during schema validation if such
            a collecting/composing method is used\.

            *Note:* None of the builtin methods do such unsafe stunts, so this
            option is only about allowing sandboxed code by default\.

            The builtin methods also feature a __dubious__ method which
            marks the subtree of the schema it overwatches as not trusted\. That
            way you can construct partly dubious schemas on the fly without
            residing to nesting\.

            See the section [NESTING](#subsection6) for details\.

          + __\-init__ *body*

            Execute the Tcl *body* inside the sandbox right after it is
            created at the start of the __collect__/__compose__ method\.
            This is meant for initializing global variables \(e\.g\. counters\) that
            may be used by downlevel methods\.

            *Note:* This is done inside an anonymous function, so simple
            variables don't clutter the global namespace inside the sandbox\. You
            have to mark variables as global to make them accessible to the
            schema\.

          + __\-recursionlimit__ *integer*

            Sets the recursion limit for the sandbox to *integer*\. A low value
            such as __0__ may be specified but it's automatically raised to
            a reasonable minimal value as needed by the builtin methods that use
            sandboxes\. If this option is not specified, the sandbox also
            defaults to that reasonable minimum\.

          + __\-\-__

            Marks the end of options\. The argument following this one will be
            treated as an argument even if it starts with a __\-__\.

Read the following section [COLLECTOR OBJECT USAGE](#subsection1)
respective [COMPOSER OBJECT USAGE](#subsection2) on how to use the objects
constructed by the class\.

## <a name='subsection1'></a>COLLECTOR OBJECT USAGE

The objects constructed by the collector class define the following methods:

  - *collectorObjName* __collect__ *decodedJson* ?*path*?

    Validate *decodedJson* data as described in section [DECODED JSON
    FORMAT](#subsection8) and supplied by __::xjson::decode__ against
    the schema loaded into the object on construction\. Also collect and
    transform the JSON data to a Tcl data structure according to that schema\.
    The collected data is returned\. An error is thrown instead if the validation
    fails\.

    The optional *path* argument is used for printing the path of the
    offending data in error messages\. It is set to "/" by default but if the
    supplied data is part of a larger JSON structure, it may be convenient to
    specify a more detailed starting path\. This is for example automatically
    done when nesting collectors using the builtin __nest__ collecting
    method\.

  - *collectorObjName* __printSchema__ ?*indent*?

    Pretty\-print the schema stored in the object with the given base *indent*\.

## <a name='subsection2'></a>COMPOSER OBJECT USAGE

The objects constructed by the composer class define the following methods:

  - *composerObjName* __compose__ *tclData* ?*path*?

    Validate *tclData* data as supplied by the program against the schema
    loaded into the object on construction\. Also compose and transform the Tcl
    data structure to decoded JSON data according to that schema\. The composed
    data is returned\. An error is thrown instead if the validation fails\.

    The optional *path* argument is used for printing the path of the
    offending data in error messages\. It is set to "/" by default but if the
    supplied data is part of a larger Tcl data structure, it may be convenient
    to specify a more detailed starting path\. This is for example automatically
    done when nesting composers using the builtin __nest__ composing method\.

    The result is decoded JSON data as described in section [DECODED JSON
    FORMAT](#subsection8)\. Feed it into __::xjson::encode__ to render
    JSON data from it\.

  - *composerObjName* __printSchema__ ?*indent*?

    Pretty\-print the schema stored in the object with the given base *indent*\.

## <a name='subsection3'></a>COLLECTOR AND COMPOSER SCHEMAS

Collector and composer schemas are nested lists of collecting/composing
functions and their arguments\.

As an important detail, both collector and composer schemas describe the JSON
side of things\. Validation always happens on the JSON side of things\. This gets
crucial as soon your schemas feature data manipulations\.

Schemas can be very simple\. For example, a schema __integer__ that is made
from the collecting method of the same name validates JSON input data as *\-5*
but not JSON input data as *3\.2* \(not an integer\) or *"5"*\. Mind the quotes
that mark that character as a string value\. For the composing direction, the Tcl
input data is validated instead\.

You can make that schema an argument of another schema\. For example, the
__array__ collecting method takes a schema as an argument\. The resulting
schema __\{array integer\}__ validates JSON input data as *\[\-4, 7, 8, 3\]*,
or for the composing direction Tcl input data *\{\-4 7 8 3\}*\.

Many collecting methods take options that allow to specify further constraints\.
For example, you can tell the __array__ method to allow only up to three
array members in the JSON input data\. The schema __\{array \-max 3 integer\}__
validates *\[\]*, *\[156\]*, *\[1, 0\]*, and *\[3, 99, 3\]*, but not *\[\-4, 7,
8, 3\]*\. And of course the __integer__ collecting method also allows further
constraints\. A schema __\{array \-max 3 \{integer \-min 0 \-max 99\}\}__ validates
*\[\]*, *\[1, 0\]*, and *\[3, 99, 3\]*, but not *\[\-4, 7, 8, 3\]* and neither
*\[156\]*\. Likewise for the composing direction with Tcl lists of integers\.

The collector objects do not just validate the decoded JSON input data but also
return it as plain Tcl data\. For manipulating what is returned, there are
special collecting methods meant for output formatting\. For example, a schema
__\{array \-max 3 \{format "%02d" \{integer \-min 0 \-max 99\}\}\}__ returns the JSON
input *\[3, 99, 3\]* as *\{03 99 03\}*\.

It works the reverse for composing\. The Tcl data is validated to be an __array
\-max 3__, the single elements formatted according to the __format "%02d"__
method, then validated according to the __integer \-min 0 \-max 99__ method
and finally returned as decoded JSON\.

Symetrical schemas may be the same for collector and composer objects\. As soon
there is asymetrical data manipulation \(as that __format__ method\) involved,
you usually need separate schemas for both directions\.

There are also methods that work as control structures\. For example, the schema
__\{anyof \{\{integer \-max \-10\} \{integer \-min 10\}\}\}__ validates any integer
value that is either <=\-10 or >=10\. And of course, you can also mix the allowed
JSON input types that way if it makes sense in your application: e\.g\. __\{array
\{anyof \{number string boolean null\}\}\}__ validates an array of all kinds of
valid simple JSON types\. Note that you will lose the JSON type information that
way so you usually don't want to do such stunts without further type\-specific
output formatting\.

See the section [BUILTIN METHODS](#subsection4) and the various
[EXAMPLES](#section7) sections for more details\.

## <a name='subsection4'></a>BUILTIN METHODS

The following methods are built into each collector/composer class \(and object\)
unless the class was created specifying the __\-nobuiltins__ option when
calling the __::xjson::makeCollectorClass__ or
__::xjson::makeComposerClass__ class factory procedure\. The *methodName*
as used by the class factory procedure is the same as the method name below as
it is used inside the schema, unless otherwise noted\.

  - Common options

      * __\-\-__

        Marks the end of options\. The argument following this one will be
        treated as an argument even if it starts with a __\-__\.

  - Arguments used

      * *body*

        A Tcl script body as accepted by Tcl's __apply__ command\.

      * *by*

        A Tcl list of dict keys\.

      * *chars*

        A Tcl string value listing chars to be trimmed from another string\.

      * *class*

        A Tcl character class as accepted by Tcl's __string is__ command\.

      * *double*

        A Tcl double value\.

      * *elseSchema*

        A schema as described in the section [COLLECTOR AND COMPOSER
        SCHEMAS](#subsection3)\.

      * *exp*

        A Tcl regular expression as accepted by Tcl's __regexp__ command\.

      * *expr*

        A Tcl expression as accepted by Tcl's __expr__ command\.

      * *index*

        A Tcl string index as accepted by Tcl's __string index__ command\.

      * *integer*

        A Tcl integer value\. \(The test applied is actually Tcl's __string is
        entier__ command\.\)

      * *length*

        A Tcl integer value >= 0\. \(The test applied is actually Tcl's __string
        is entier__ command\.\)

      * *mapping*

        A Tcl list of string mappings as accepted by Tcl's __string map__
        command\.

      * *needle*

        A Tcl string value giving a needle string to search for in a haystack
        string\.

      * *nullvalue*

        A Tcl string value to be treated as null\.

      * *pattern*

        A Tcl string pattern as accepted by Tcl's __string match__ command\.

      * *nestedCollectorName*

        The name of a nested collector as specified when constructing the
        collector object\.

      * *range*

        A Tcl list giving a string range as accepted by Tcl's __string
        range__ command\. In addition, also a Tcl string index as accepted by
        Tcl's __string index__ command\.

      * *replacement*

        An Tcl string value used as a replacement for another string\.

      * *schema*

        A schema as described in the section [COLLECTOR AND COMPOSER
        SCHEMAS](#subsection3)\.

      * *schemaList*

        A Tcl list of schemas as described in the section [COLLECTOR AND
        COMPOSER SCHEMAS](#subsection3)\.

      * *schemaDict*

        A Tcl dict of key\-schema pairs as described in the section [COLLECTOR
        AND COMPOSER SCHEMAS](#subsection3)\. The keys may be arbitrary Tcl
        string values\.

      * *schemaPairs*

        A Tcl dict of schema\-schema pairs as described in the section
        [COLLECTOR AND COMPOSER SCHEMAS](#subsection3)\.

      * *start*

        A Tcl string index as accepted by Tcl's __string index__ command\.

      * *string*

        A Tcl string value\.

      * *testSchema*

        A schema as described in the section [COLLECTOR AND COMPOSER
        SCHEMAS](#subsection3)\.

      * *thenSchema*

        A schema as described in the section [COLLECTOR AND COMPOSER
        SCHEMAS](#subsection3)\.

      * *value*

        An arbitrary Tcl value as read from the decoded JSON input\.

  - Simple Types

      * __boolean__

          + for collecting

            Validates __literal *value*__ in the decoded JSON input\. As an
            additional constraint, the *value* must be a boolean\. \(The test
            applied is actually Tcl's __string is boolean__ command\.\)

            Returns the boolean *value*\.

          + for composing

            Validates a Tcl input value that is a boolean to Tcl's __string is
            boolean__ command\.

            Returns either __literal true__ or __literal false__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. See the section [NULL
                    HANDLING](#section5) for additional information\.

      * __decoded__

          + for collecting

            This method does not exist in collector objects as the
            __::xjson::decode__ and __::xjson::recode__ functions never
            return a __decoded__ type\.

          + for composing

            Validates a decoded JSON input *value* as understood by
            __::xjson::encode__ and __::xjson::recode__\. See [DECODED
            JSON FORMAT](#subsection8) for details\.

            Returns __decoded *value*__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. See the section [NULL
                    HANDLING](#section5) for additional information\.

      * __encoded__

          + for collecting

            This method does not exist in collector objects as the
            __::xjson::decode__ and __::xjson::recode__ functions never
            return an __encoded__ type\.

          + for composing

            Validates a JSON input *value* as understood by
            __::xjson::decode__\.

            Returns __encoded *value*__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. See the section [NULL
                    HANDLING](#section5) for additional information\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeComposerClass__ class factory procedures is
        __decoded__\.

      * __integer *?options?*__

          + for collecting

            Validates a __number *value*__ in the decoded JSON input\. As
            an additional constraint, the *value* must be an integer\. \(The
            test applied is actually Tcl's __string is entier__ command\.\)

            Returns the numeric *value*\.

          + for composing

            Validates a Tcl input value that is an integer to Tcl's __string
            is entier__ command\.

            Returns __number *value*__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. See the section [NULL
                    HANDLING](#section5) for additional information\.

          + The following general option may be specified:

              - __\-isolate__

                Use a local sandbox\.

          + The following further constraints may be specified:

              - __\-max__ *integer*

                Validates a number *value* <= *integer*\.

              - __\-xmax__ *integer*

                Validates a number *value* < *integer*\.

              - __\-min__ *integer*

                Validates a number *value* >= *integer*\.

              - __\-xmin__ *integer*

                Validates a number *value* > *integer*\.

              - __\-multipleof__ *integer*

                Validates a number *value* that is a multiple of *integer*\.

              - __\-test__ *expr*

                Validates a number *value* by passing it to the Tcl *expr*
                as the local variable *x*\. If the expression results in a
                boolean false, the validation fails\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ respective
        __::xjson::makeComposerClass__ class factory procedures is
        __number__\.

      * __null__

          + for collecting

            Validates a __literal null__ in the decoded JSON input\. See the
            section [NULL HANDLING](#section5) for additional information\.

          + for composing

            Validates the null value as specified, if any\.

              - The following option should be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. See the section [NULL
                    HANDLING](#section5) for additional information\.

      * __number *?options?*__

          + for collecting

            Validates a __number *value*__ in the decoded JSON input\. \(The
            test applied is actually Tcl's __string is double__ command\.\)

            Returns the numeric *value*\.

          + for composing

            Validates a Tcl input value that is an integer to Tcl's __string
            is double__ command\.

            Returns __number *value*__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. See the section [NULL
                    HANDLING](#section5) for additional information\.

          + The following general option may be specified:

              - __\-isolate__

                Use a local sandbox\.

          + The following further constraints may be specified:

              - __\-max__ *double*

                Validates a number *value* <= *double*\.

              - __\-xmax__ *double*

                Validates a number *value* < *double*\.

              - __\-min__ *double*

                Validates a number *value* >= *double*\.

              - __\-xmin__ *double*

                Validates a number *value* > *double*\.

              - __\-test__ *expr*

                Validates a number *value* by passing it to the Tcl *expr*
                as the local variable *x*\. If the expression results in a
                boolean false, the validation fails\.

      * __string *?options?*__

          + for collecting

            Validates a __string *value*__ in the decoded JSON input\.

            Returns the original string *value*\.

          + for composing

            Validates any Tcl input value\.

            Returns __string *value*__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. See the section [NULL
                    HANDLING](#section5) for additional information\.

        Further constraints may be specified\. They all work on a test string
        that is initially filled with the string *value*\. Some options aren't
        constraints but instead they manipulate the test string\. All options are
        applied and tested in their order of appearance in the *options*\. They
        may appear multiple times\.

        *Note:* To manipulate the string output, see the methods in the
        __Result Formatting Operators__ subsection\.

          + The following general options may be specified:

              - __\-nocase__

              - __\-case__

                Makes the options __\-before__, __\-xbefore__,
                __\-behind__, __\-xbehind__, __\-equal__, __\-map__,
                __\-match__, __\-regexp__ work
                case\-insensitively/case\-sensitively until the other option is
                specified\. By default all those options work case\-sensitively\.

              - __\-start__ *index*

                Makes the options __\-first__, __\-last__ and
                __\-regexp__ start their search with the character *index*\.
                It accepts string indices as accepted by Tcl's __string
                index__ command\. Specifying *index* as an empty string
                disables this option\. It's disabled by default\.

              - __\-clength__ *length*

                Makes the options __\-before__, __\-xbefore__,
                __\-behind__, __\-xbehind__, and __\-equal__ only
                consider a *length* of characters for their comparison\.
                Specifying *length* as __0__ disables this option\. It's
                disabled by default\.

              - __\-isolate__

                Use a local sandbox\.

          + The following test string manipulations may be specified:

              - __\-and__

                Resets the test string to the *value* supplied from the
                decoded JSON input\. This option may be used to do multiple
                validation tests without more convoluted control structures\.

              - __\-map__ *mapping*

                Manipulates the test string by mapping it as by Tcl's __string
                map__ command\. The options __\-nocase__ and __\-case__
                are honored\.

              - __\-range__ *range*

                Manipulates the test string by removing anything but the
                *range* of characters from it, as by Tcl's __string
                range__ command\.

              - __\-reverse__

                Manipulates the test string by reversing the order of chars as
                by Tcl's __string reverse__ command\. This is sometimes
                useful before testing for regular expressions\.

              - __\-tolower__ *range*

              - __\-toupper__ *range*

                Manipulates the test string by forcing lowercase/uppercase on
                all characters in the *range* as by Tcl's __string
                tolower__ resp\. __string toupper__ command\.

              - __\-totitle__ *range*

                Manipulates the test string by forcing uppercase on the first
                and lowercase on all other characters in the *range* as by
                Tcl's __string totitle__ command\.

              - __\-transform__ *body*

                Manipulates the test string by passing it to the Tcl *body* as
                the local variable *x*\. The teststring is then set to the
                return value of that evaluation\.

              - __\-trim__ *chars*

              - __\-trimleft__ *chars*

              - __\-trimright__ *chars*

                Manipulates the test string by trimming all specified *chars*
                from it from left, right, or both\. Specifying *chars* as an
                empty list makes it trim all whitespace \(any character that
                tests positive for __string is space__\)\. That's a slight
                difference to Tcl's __string trim__, __string
                trimleft__, __string trimright__ commands\.

          + The following further constraints on the test string length may be specified:

              - __\-max__ *integer*

                Validates a test string length <= *integer*\.

              - __\-xmax__ *integer*

                Validates a test string length < *integer*\.

              - __\-min__ *integer*

                Validates a test string length >= *integer*\.

              - __\-xmin__ *integer*

                Validates a test string length > *integer*\.

              - __\-multipleof__ *integer*

                Validates a test string length that is a multiple of
                *integer*\.

          + The following further options and constraints on the position of a search string in the test string may be specified:

              - __\-first__ *needle*

              - __\-last__ *needle*

                Find the *needle* in the teststring as by Tcl's __string
                first__ resp\. __string last__ command\. It starts at the
                position in the test string specified by the __\-start__
                option, or at its beginning/end if that option is disabled\. It
                sets the needle position for further validation by the options
                __\-maxpos__, __\-xmaxpos__, __\-minpos__,
                __\-xmaxpos__, and __\-multipleofpos__\. If the needle
                cannot be found, its position is set as __\-1__\. The needle
                position is also __\-1__ by default\.

              - __\-maxpos__ *integer*

                Validates a needle position <= *integer*\.

              - __\-xmaxpos__ *integer*

                Validates a needle position < *integer*\.

              - __\-minpos__ *integer*

                Validates a needle position >= *integer*\.

              - __\-xminpos__ *integer*

                Validates a needle position > *integer*\.

              - __\-multipleofpos__ *integer*

                Validates a needle position that is a multiple of *integer*\.

          + The following further constraints on the sorting order of the test string as by Tcl's commands __string compare__ and __string equal__ may be specified, but only the first characters as specified by the __\-clength__ option are considered\. The options __\-nocase__ and __\-case__ are honored\.

              - __\-before__ *string*

                Validates a test string sorting before or equal *string*\.

              - __\-xbefore__ *string*

                Validates a test string sorting before *string*\.

              - __\-behind__ *string*

                Validates a test string sorting behind or equal *string*\.

              - __\-xbehind__ *string*

                Validates a test string sorting behind *string*\.

              - __\-equal__ *string*

                Validates a test string sorting equal *string*\.

          + The following further constraints on the test string may be specified:

              - __\-is__ *class*

                Validates a test string *class* as by Tcl's __string is__
                command\. In addition, *class* may also be put as __uuid__,
                which validates a UUID/GUID\. Both lowercase and uppercase hex
                digits are considered valid\.

              - __\-match__ *pattern*

                Validates a test string that matches the *pattern* as by Tcl's
                __string match__ command\. The options __\-nocase__ and
                __\-case__ are honored\.

              - __\-regexp__ *exp*

                Validates a test string that matches the regular expression
                *exp* as by Tcl's __regexp__ command\. It starts at the
                position in the test string specified by the __\-start__
                option, or at its beginning if that option is disabled\. The
                options __\-nocase__ and __\-case__ are honored\.

              - __\-test__ *expr*

                Validates a test string by passing it to the Tcl *expr* as the
                local variable *x*\. If the expression results in a boolean
                false, the validation fails\.

  - Aggregate Types

      * __array *?options?* *schema*__

          + for collecting

            Validates an __array \{\.\.\.\}__ in the decoded JSON input with
            elements according to the given *schema*\.

            Returns a Tcl list with each array member as one list element\.
            Returns an empty Tcl list if the array has no members\.

          + for composing

            Validates a Tcl list with elements according to the given
            *schema*\.

            Returns an __array \{\.\.\.\}__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. This isn't about individual elements but about
                    whether the whole array should be considered __null__\.
                    See the section [NULL HANDLING](#section5) for
                    additional information\.

        *Note:* Array elements that evaluate as __null__ are completely
        ignored \-as if they were not posted\-\. See the section [NULL
        HANDLING](#section5) for additional information\.

          + The following general option may be specified:

              - __\-isolate__

                Use a local sandbox\.

          + The following further constraints on the array length may be specified:

              - __\-max__ *integer*

                Validates an array length <= *integer* elements\.

              - __\-xmax__ *integer*

                Validates an array length < *integer* elements\.

              - __\-min__ *integer*

                Validates an array length >= *integer* elements\.

              - __\-xmin__ *integer*

                Validates an array length > *integer* elements\.

              - __\-multipleof__ *integer*

                Validates an array length that is a multiple of *integer*
                elements\.

              - __\-test__ *expr*

                Validates an array length by passing it to the Tcl *expr* as
                the local variable *x*\. If the expression results in a boolean
                false, the validation fails\.

      * __duple *schemaDict*__

        A shortcut for __duples \-min 1 \-max 1 *schemaDict*__\. See below\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ and
        __::xjson::makeComposerrClass__ class factory procedures is
        __array__\.

      * __duples *?options?* *schemaDict*__

          + for collecting

            Validates an __array \{\.\.\.\}__ in the decoded JSON input with
            elements according to the given *schemaDict*\.

            Different to the __array__ collecting method, this method
            alternates through the given *schemaDict* and requires the array
            elements to validate against the different schemas in order\. An
            incomplete last tuple results in failed validation\.

            Different to the __tuples__ collecting method, this method
            labels the collected input data according to the schema so the
            result isn't a Tcl list of lists but a list of dicts\. Returns an
            empty Tcl list if the array has no members\.

          + for composing

            Validates a Tcl list of dicts with elements according to the given
            *schemaDict*\.

            Different to the __array__ composing method, this method
            alternates through the given *schemaDict* and requires the dict
            elements to validate against the different schemas in order\. An
            incomplete last tuple results in failed validation\.

            Different to the __tuples__ composing method, this method
            requires the collected input data to be labeled according to the
            schema so the input must be a Tcl list of dicts, not a Tcl list of
            lists\.

            Returns an __array \{\.\.\.\}__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. This isn't about individual elements but about
                    whether the whole array should be considered __null__\.
                    See the section [NULL HANDLING](#section5) for
                    additional information\.

        *Note:* Array elements that evaluate as __null__ are completely
        ignored \-as if they were not posted\-\. See the section [NULL
        HANDLING](#section5) for additional information\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ and
        __::xjson::makeComposerClass__ class factory procedures is
        __array__\.

          + The following general option may be specified:

              - __\-isolate__

                Use a local sandbox\.

          + The following further constraints on the tuples count may be specified:

              - __\-max__ *integer*

                Validates an array length <= *integer* tuples\.

              - __\-xmax__ *integer*

                Validates an array length < *integer* tuples\.

              - __\-min__ *integer*

                Validates an array length >= *integer* tuples\.

              - __\-xmin__ *integer*

                Validates an array length > *integer* tuples\.

              - __\-multipleof__ *integer*

                Validates an array length that is a multiple of *integer*
                tuples\.

              - __\-test__ *expr*

                Validates an array length \(in tuples\) by passing it to the Tcl
                *expr* as the local variable *x*\. If the expression results
                in a boolean false, the validation fails\.

      * __object *?options?* *schemaDict*__

          + for collecting

            Validates an __object \{\.\.\.\}__ in the decoded JSON input with
            elements according to the given *schemaDict*\.

            Returns a Tcl dict of key\-value pairs\. This behaviour may be changed
            with the __\-values__ option\. The order of elements is always the
            same as specified in the *schemaDict* argument\.

          + for composing

            Validates a Tcl dict with elements according to the given
            *schemaDict*\. This behaviour may be changed with the
            __\-values__ option\. The order of elements is always the same as
            specified in the *schemaDict* argument\.

            Returns an __object \{\.\.\.\}__\.

              - The following options may be specified:

                  * __\-missing__ *nullvalue*

                    Specifies a Tcl value that should be passed to the downlevel
                    schemas whenever a field is missing in the input\. The
                    specific downlevel schema may then specify the same Tcl
                    string as its own __null__ value and report a
                    __null__ to uplevel, where a __default__ or
                    __optional__ method can override the validation failure\.
                    See the section [NULL HANDLING](#section5) for
                    additional information\.

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. This isn't about individual elements but about
                    whether the whole object should be considered __null__\.
                    See the section [NULL HANDLING](#section5) for
                    additional information\.

        *Note:* Missing keys are treated as a validation failure, and as are
        elements that evaluate as __null__\. This may be circumvented by
        enclosing the schema for an element with a __default__ or
        __optional__ method\. See the subsection __Aggregate Field
        Operators__\.

          + The following option may be specified:

              - __\-values__

                Instead of returning/requiring a Tcl dict of key\-value pairs,
                return/require a Tcl list of the values\.

      * __tuple *schemaList*__

        A shortcut for __tuples \-flat \-min 1 \-max 1 *schemaList*__\. See
        below\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ and
        __::xjson::makeComposerClass__ class factory procedures is
        __array__\.

      * __tuples *?options?* *schemaList*__

          + for collecting

            Validates an __array \{\.\.\.\}__ in the decoded JSON input with
            elements according to the given *schemaList*\.

            Different to the __array__ collecting method, this method
            alternates through the given *schemaList* and requires the array
            elements to validate against the different schemas in order\. An
            incomplete last tuple results in failed validation\.

            This method returns a Tcl list with each tuple list as one list
            element\. This can be changed with the __\-flat__ option\. The
            resulting list is flat then\. Returns an empty Tcl list if the array
            has no members\.

          + for composing

            Validates a Tcl list of lists with elements according to the given
            *schemaList*\. This can be changed with the __\-flat__ option\.
            It validates a flat Tcl list then\.

            Different to the __array__ composing method, this method
            alternates through the given *schemaList* and requires the list
            elements to validate against the different schemas in order\. An
            incomplete last tuple results in failed validation\.

            Returns an __array \{\.\.\.\}__\.

              - The following option may be specified:

                  * __\-null__ *nullvalue*

                    Specifies a Tcl input value that should be treated as
                    __null__\. This isn't about individual elements but about
                    whether the whole array should be considered __null__\.
                    See the section [NULL HANDLING](#section5) for
                    additional information\.

        *Note:* Array elements that evaluate as __null__ are completely
        ignored \-as if they were not posted\-\. See the section [NULL
        HANDLING](#section5) for additional information\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ and
        __::xjson::makeComposerClass__ class factory procedures is
        __array__\.

          + The following general options may be specified:

              - __\-flat__

                Instead of returning a Tcl list of lists, return a flat Tcl
                list\.

              - __\-isolate__

                Use a local sandbox\.

          + The following further constraints on the tuples count may be specified:

              - __\-max__ *integer*

                Validates an array length <= *integer* tuples\.

              - __\-xmax__ *integer*

                Validates an array length < *integer* tuples\.

              - __\-min__ *integer*

                Validates an array length >= *integer* tuples\.

              - __\-xmin__ *integer*

                Validates an array length > *integer* tuples\.

              - __\-multipleof__ *integer*

                Validates an array length that is a multiple of *integer*
                tuples\.

              - __\-test__ *expr*

                Validates an array length \(in tuples\) by passing it to the Tcl
                *expr* as the local variable *x*\. If the expression results
                in a boolean false, the validation fails\.

  - Aggregate Field Operators

      * __default *string* *schema* \(for collecting\)__

      * __default *type* *string* *schema* \(for composing\)__

          + for collecting

            Validates the decoded JSON input with the *schema*\. If it
            succeeds, the value returned by the schema is returned\. If it fails,
            the reported validation error is escalated\. If it is reported as
            __null__ however because the input data is simply missing or a
            __literal null__, it is reported as successfully validated and
            the given *string* is returned\.

            *Note:* The *string* does not have to validate\. It may be an
            arbitrary string\.

          + for composing

            Validates the Tcl input with the *schema*\. If it succeeds, the
            value returned by the schema is returned\. If it fails, the reported
            validation error is escalated\. If it is reported as __null__
            however, it is reported as successfully validated instead and the
            given *type* and *string* are returned\.

            *Note:* Neither *type* nor *string* have to validate\. They may
            be both arbitrary values\. It's the reponsibilty of the schema author
            to choose meaningful values\.

        *Note:* Though most useful with object fields, this operator may be
        specified at any place where a missing or __null__ value in the
        input data should be replaced by a reasonable default\.

      * __optional *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. If it
            succeeds, the value returned by the schema is returned\. If it fails,
            the reported validation error is escalated\. If it validates as
            __null__ however because the input data is simply missing or a
            __literal null__, it is reported as a special validation error
            instead, and an uplevel __object__ method will ignore the field
            for this object\. It's not going to be reported as a key\-value pair
            in the object result at all\.

          + for composing

            Validates the Tcl input with the *schema*\. If it succeeds, the
            value returned by the schema is returned\. If it fails, the reported
            validation error is escalated\. If it is reported as __null__
            however, it is reported as a special validation error instead, and
            an uplevel __object__ method will ignore the field for this
            object\. It's not going to be reported as a key\-value pair in the
            object result at all\.

              - The following option may be specified:

                  * __\-emitnull__

                    Changes the type of validation error reported so the uplevel
                    method will report a __literal null__ instead of a
                    missing field\. See the section [NULL
                    HANDLING](#section5) for additional information\.

        *Note:* Be careful in conjunction with the __\-values__ option of
        the __object__ method though\. Optional fields must then be the last
        ones in the schema to avoid confusion on the result data\.

        *Note:* For any other uplevel methods than __array__,
        __duple__, __duples__, __object__, __tuple__,
        __tuples__, this operator simply changes the kind of validation
        error reported\.

  - Control Structures

      * __allof *schemaList*__

        Validates the input with all the schemas in the *schemaList*\. If any
        listed schema does not validate, the validation fails as a whole\.

        If a schema evaluates as __null__ it is counted as validated but no
        result is stored\.

        Returns the result of the first schema that had a result\. If no schema
        had a result \-they have all evaluated as __null__\-, this method
        returns __null__ as well\. See the section [NULL
        HANDLING](#section5) for additional information\.

      * __anyof *schemaList*__

        Validates the input with all the schemas in the *schemaList*\. If no
        listed schema validates, the validation fails as a whole\.

        If a schema evaluates as __null__ it is counted as validated but no
        result is stored\.

        Returns the result of the first schema that had a result\. If no schema
        had a result \-they have all evaluated as __null__\-, this method
        returns __null__ as well\. See the section [NULL
        HANDLING](#section5) for additional information\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ and
        __::xjson::makeComposerClass__ class factory procedures is
        __allof__\.

      * __const *string* \(for collecting\)__

      * __const *type* *string* \(for composing\)__

          + for collecting

            Returns the *string* constant\.

          + for composing

            Returns the *type* *string* constants\.

        This method is meant for the result schemas of the __if__ and
        __switch__ methods, but may also be put as a default value for those
        or the __allof__, __anyof__, and __oneof__ methods\.

      * __discard__

        Discards the input and and returns a __null__ instead\. That
        __null__ may be reinterpreted by uplevel methods\.

      * __dubious *schema*__

        Marks the *schema* and its whole branch as not trusted\. Such schemas
        may not specify Tcl code or methods that are marked as unsafe\.

        The dubious flag is not inherited to nested collector objects so they
        may be marked as having a trusted schema, and may specify Tcl code or
        unsafe methods\.

        See the section [NESTING](#subsection6) for details\.

      * __escalate__

        Escalates the validation error encountered in a *testSchema* of the
        __if__ method, or the validation error of the __switch__ method\.

        *Note:* When used outside of the *elseSchema* or *nullSchema* of
        the __if__ or __switch__ methods, this method reports an error\.

      * __if *testSchema* *thenSchema* *elseSchema* *nullSchema*__

        Validates the input with the *testSchema*\.

        If the test validation returns __null__, this method re\-validates
        the input with the *nullSchema* and returns that result \(or fail
        validation\)\. The *nullSchema* may be specified as __escalate__ to
        escalate the validation error of the *testSchema* instead\.

        If the test validation succeeded, this method re\-validates the input
        with the *thenSchema* and returns that result \(or fail validation\)\.
        The *thenSchema* may be specified as __pass__ to return the result
        of the *testSchema* instead\.

        If the test validation failed, this method re\-validates the input with
        the *elseSchema* and returns that result \(or fail validation\)\. The
        *elseSchema* may be specified as __escalate__ to escalate the
        validation error of the *testSchema* instead\.

        *Note:* The __discard__ method is also useful as either the
        *thenSchema* or the *elseSchema*\. It returns a __null__\.

      * __nest *nestedCollectorName*__

      * __nest *nestedComposerName*__

        Passes the branch of data at this point to the collector/composer object
        *nestedCollectorName*/*nestedComposerName* which was registered with
        the schema at the construction of this collector/composer object\.

        The dubious flag is not inherited to the nested collector/composer
        object so it may be marked as having a trusted schema, and may specify
        Tcl code or unsafe methods though the calling schema may not\.

        See the sections [NESTING](#subsection6) and
        [SANDBOXING](#subsection7) for details\.

      * __oneof *schemaList*__

        Validates the input with all the schemas in the *schemaList*\. If none
        or more than one listed schema validates, the validation fails as a
        whole\.

        If a schema evaluates as __null__ it is counted as validated but no
        result is stored\.

        Returns the result of the first schema that had a result\. If no schema
        had a result \-they have all evaluated as __null__\-, this method
        returns __null__ as well\. See the section [NULL
        HANDLING](#section5) for additional information\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ and
        __::xjson::makeComposerClass__ class factory procedures is
        __allof__\.

      * __pass__

        Passes the result of the validated input from a *testSchema* of the
        __if__ method or from the first matching *testSchema* of the
        __switch__ method\.

        *Note:* When used outside of a *thenSchema* of the __if__ or
        __switch__ methods, this method reports an error\.

      * __switch *schemaPairs* *elseSchema* *nullSchema*__

        Validates the input with the *schemaPairs* list\. The first, third,
        fifth, \.\.\. element of that list is interpreted as a *testSchema*, the
        second, fourth, sixth, \.\.\. element of that list is interpreted as a
        *thenSchema*\.

        If a test validation returns __null__, the next *testSchema* is
        checked\.

        If a test validation fails, the next *testSchema* is checked\.

        As soon a test validation succeeded, no more *testSchema*s are checked
        but instead, this method re\-validates the input with the following
        *thenSchema* and returns that result \(or fail validation\)\. The
        *thenSchema* may be specified as __pass__ to return the result of
        the *testSchema* instead\.

        If no test schema validated, this method checks whether all test results
        have been __null__\. In that case it re\-validates the input with the
        *nullSchema*, otherwise with the *elseSchema* and returns that
        result \(or fail validation\)\. Either may be specified as __escalate__
        to escalate the validation error of the switch method instead\.

        *Note:* The __discard__ method is also useful as either a
        *thenSchema*, the *elseSchema*, or the *nullSchema*\. It returns a
        __null__\.

  - Result Formatting Operators

      * __apply *?options?* *varList* *body* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. That result is
            then expanded as needed by the amount of variable names in
            *varList* and then passed into Tcl's __apply__ command along
            the *varList* and the supplied Tcl *body*\. The last variable in
            the *varList* gets assigned a list of the remaining input elements
            if there are more of those than variable names specified\.

            The operator returns the result of Tcl's __apply__ command\.

          + for composing

            Expands the Tcl input data as needed by the amount of variable names
            in *varList* and passes it into Tcl's __apply__ command along
            the *varList* and the supplied Tcl *body*\. The last variable in
            the *varList* gets assigned a list of the remaining input elements
            if there are more of those than variable names specified\.

            The result of that is then validated with the *schema*\. The
            operator returns the result of the schema\.

          + The following options may be specified:

              - __\-isolate__

                Use a local sandbox\.

      * __datetime *?options?* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. That result is
            then passed into Tcl's __clock scan__ command along the supplied
            *options* arguments\.

            The operator returns the result of Tcl's __clock scan__ command\.

          + for composing

            Passes the Tcl input data into Tcl's __clock format__ command
            along the supplied *options* arguments\.

            The result of that is then validated with the *schema*\. The
            operator returns the result of the schema\.

          + The following options may be specified:

              - __\-format__ *format*

                A format string as understood by Tcl's __clock \-format__
                option\.

              - __\-timezone__ *zoneName*

                A timezone name as understood by Tcl's __clock \-timezone__
                option\.

              - __\-locale__ *localeName*

                A locale name as understood by Tcl's __clock \-locale__
                option\.

      * __expr *?options?* *varList* *expr* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. That result is
            then expanded as needed by the amount of variable names in
            *varList* and then passed into Tcl's __expr__ command along
            the *varList* and the supplied Tcl expression *expr*\. The last
            variable in the *varList* gets assigned a list of the remaining
            input elements if there are more of those than variable names
            specified\.

            The operator returns the result of Tcl's __expr__ command\.

          + for composing

            Expands the Tcl input data as needed by the amount of variable names
            in *varList* and passes it into Tcl's __expr__ command along
            the *varList* and the supplied Tcl *body*\. The last variable in
            the *varList* gets assigned a list of the remaining input elements
            if there are more of those than variable names specified\.

            The result of that is then validated with the *schema*\. The
            operator returns the result of the schema\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ and
        __::xjson::makeComposerClass__ class factory procedure is
        __apply__\.

          + The following options may be specified:

              - __\-isolate__

                Use a local sandbox\.

      * __format *format* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. That result is
            then expanded and passed into Tcl's __format__ command along the
            supplied *format* argument as individual list items\. So it works
            both on individual values and on the result of aggregate types and
            operators\.

            The operator returns the result of Tcl's __format__ command\.

          + for composing

            Expands the Tcl input data and passes it into Tcl's __format__
            command along the *format* argument as individual list items\.

            The result of that is then validated with the *schema*\. The
            operator returns the result of the schema\.

      * __mark *mark* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\.

            The operator returns a Tcl list with the *mark* argument as the
            first list element and the result of the validation as the second
            list element\.

          + for composing

            Treats the Tcl input data as a list and fail validation if the first
            list element isn't the same as the *mark* argument\.

            If it passes, the second list element is then validated with the
            *schema*\. The operator returns the result of the schema\.

      * __regsub *?options?* *exp* *replacement* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. The result is
            then passed into Tcl's __regsub__ command along the supplied
            *exp* and *replacement* arguments\.

            The operator returns the result of Tcl's __regsub__ command\.

          + for composing

            Passes the Tcl input data into Tcl's __regsub__ command along
            the *exp* and *replacement* arguments

            The result of that is then validated with the *schema*\. The
            operator returns the result of the schema\.

          + The following options may be specified:

              - __\-all__

                All ranges in the input value that match exp are found and
                substitution is performed for each of these ranges\.

              - __\-nocase__

                Upper\-case characters in the input value will be converted to
                lower\-case before matching against *exp*

              - __\-start__ *start*

                Start matching at the position inside the input value specified
                by the __\-start__ option instead of its beginning\.

      * __stringop *?options?* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. That result is
            then passed into Tcl's __string__ command along the supplied
            *options* arguments\. All options are applied in their order of
            appearance in the *options*\. They may appear multiple times\.

            The operator returns the result of Tcl's __string__ command\.

          + for composing

            Passes the Tcl input data into Tcl's __string__ command along
            the supplied *options* arguments\. All options are applied in their
            order of appearance in the *options*\. They may appear multiple
            times\.

            The result of that is then validated with the *schema*\. The
            operator returns the result of the schema\.

          + The following general options may be specified:

              - __\-nocase__

              - __\-case__

                Makes the option __\-map__ work
                case\-insensitively/case\-sensitively until the other option is
                specified\. By default that option works case\-sensitively\.

          + The following string manipulations may be specified:

              - __\-map__ *mapping*

                Manipulates the input data by mapping it as by Tcl's __string
                map__ command\. The options __\-nocase__ and __\-case__
                are honored\.

              - __\-range__ *range*

                Manipulates the input data by removing anything but the
                *range* of characters from it, as by Tcl's __string
                range__ command\.

              - __\-tolower__ *range*

              - __\-toupper__ *range*

                Manipulates the input data by forcing lowercase/uppercase on all
                characters in the *range* as by Tcl's __string tolower__
                resp\. __string toupper__ command\.

              - __\-totitle__ *range*

                Manipulates the input data by forcing uppercase on the first and
                lowercase on all other characters in the *range* as by Tcl's
                __string totitle__ command\.

              - __\-trim__ *chars*

              - __\-trimleft__ *chars*

              - __\-trimright__ *chars*

                Manipulates the input data by trimming all specified *chars*
                from it from left, right, or both\. Specifying *chars* as an
                empty list makes it trim all whitespace \(any character that
                tests positive for __string is space__\)\. That's a slight
                difference to Tcl's __string trim__, __string
                trimleft__, __string trimright__ commands\.

  - Aggregate Result Formatting Operators

      * __dictby *by* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. That result is
            evaluated as a list of dicts of the form

                {{key1 value1a key2 value2a} {key1 value1b key2 value2b}}

            as coming from the collecting methods __duples__ or
            __array__ of __object__s\. The argument *by* tells which
            key\(s\) from the inner dicts should be moved to form a dict of dicts
            as for example for *by* specified as *key1*

                {value1a {key2 value2a} value1b {key2 value2b}}

            The argument *by* may be a Tcl list of keys, the resulting keys
            are Tcl lists of those values then\.

          + for composing

            Rearranges the Tcl input data from a dict of dicts of the form

                {value1a {key2 value2a} value1b {key2 value2b}}

            into a list of dicts of the form

                {{key1 value1a key2 value2a} {key1 value1b key2 value2b}}

            The argument *by* tells which name the dict key should have when
            forming the inner dicts\. The argument *by* may be a Tcl list of
            keys, the resulting inner dicts then have multiple additional keys\.

            The result is then validated with the *schema*\.

      * __dictbyindex *by* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\.

            That result is evaluated as a list of lists of the form

                {{value1a value2a value3a} {value1b value2b value3b}}

            as matching to the methods __tuples__ or __array__ of
            __array__s or __array__ of __object \-values__\. The
            argument *by* tells which indices from the inner lists should be
            moved to form a dict of lists as for example for *by* specified as
            *0*

                {value1a {value2a value3a} value1b {value2b value3b}}

            The argument *by* may be a Tcl list of indices, the resulting keys
            are Tcl lists of those values then\.

          + for composing

            Rearranges the Tcl input data from a dict of lists of the form

                {value1a {value2a value3a} value1b {value2b value3b}}

            into a list of lists of the form

                {{value1a value2a value3a} {value1b value2b value3b}}

            as matching to the methods __tuples__ or __array__ of
            __array__s or __array__ of __object \-values__\. The
            argument *by* tells at which places inside the inner lists the
            dict keys should be inserted\. The argument *by* may be a Tcl list
            of indices\.

            The result is then validated with the *schema*\.

            *Note:* The result elements are constructed in an additive
            fashion\. If several indices are given and they aren't in ascending
            order, the results may be unexpected\. This is not a bug\.

      * __lmap *?options?* *varList* *body* *schema*__

          + for collecting

            Validates the decoded JSON input with the *schema*\. That result is
            passed into Tcl's __lmap__ command as a list along the
            *varList* and the supplied *body*\.

            The operator returns the result of Tcl's __lmap__ command\.

          + for composing

            Passes the Tcl input data as a list into Tcl's __lmap__ command
            along the *varList* and the supplied Tcl *body*\.

            The result of that is then validated with the *schema*\. The
            operator returns the result of the schema\.

        *Note:* The *methodName* for this method as used by the
        __::xjson::makeCollectorClass__ and
        __::xjson::makeComposerClass__ class factory procedures is
        __apply__\.

          + The following option may be specified:

              - __\-isolate__

                Use a local sandbox\.

## <a name='subsection5'></a>CUSTOM METHODS

If neither the above collecting/composing methods nor sandboxed Tcl code from
within the schema are sufficient to solve the particular validation and
collecting/composing problem, you may want to create custom collecting methods\.
This can be done with relative ease\. They have to be specified on the call to
the __::xjson::makeCollectorClass__ or __::xjson::makeComposerClass__
class factory procedure with a unique *methodName* and a *methodDefinition*\.

  - *methodName*

    Each *methodName* may define multiple methods for use within the schema
    that share the same definition but differ in details, such as the accepted
    parameters and options\. They are sorted out from within their Tcl body by
    the actual method name used in the schema then\. The following
    *methodName*s are reserved for the builtin methods:

    __allof anyof apply array boolean const decoded default expr dictby
    dictbyindex discard dubious escalate format if nest not null number object
    oneof optional otherwise pass regsub string stringop switch__

    You may of course overwrite those as well but it will break compatibility
    with existing schemas\. For forward compatibility with new versions of
    __xjson__, it's best to mark private methods with an __@__ in front\.
    Such methods names will never be used as the names of builtins by the
    __xjson__ package\.

  - *methodDefinition*

    The *methodDefinition* must be a list that resembles a parameter list\.

      * Its syntax is either

        ?*methodOptions*? ?*aliasName aliasParameters \.\.\.*? *body*

      * or \(simplified\)

        ?*methodOptions*? *methodParameters* *body*

    In the simplified variant, the method has only one name and one set of
    parameters\. The following *aliasName*s are reserved for the builtin
    methods:

    __allof anyof apply array boolean const decoded default duple duples
    encoded expr dictby dictbyindex discard dubious escalate format if integer
    lmap nest not null number object oneof optional otherwise pass regsub string
    stringop switch tuple tuples__

      * The following *methodOptions* may be specified:

          + __\-unsafe__

            This method does potentially unsafe things \(such as reading
            arbitrary files whose names are specfied in the schema, or
            evaluating code outside of a sandbox\) and that may only be used in
            trusted schemas\.

          + __\-dubious__

            The schema arguments of this method may come from a dubious
            \(non\-trusted\) source\.

          + __\-\-__

            Marks the end of options\. The argument following this one will be
            treated as an argument even if it starts with a __\-__\.

      * The *aliasParameters*/*methodParameters* are a list of parameter names\.

        Option names must start with a __\-__, otherwise the parameter name
        is that of a mandatory argument\. Each argument or option name may be
        followed by an indicator that shows its type and additional constraints
        the schema parser should check during the construction of the
        collector/composer object\.

        The default argument type is a string\. The default option type is a
        switch that is true when it is listed\.

        The indicators are:

          + __=__

            A string\.

          + __=*exp*__

            A string that matches the regular expression *exp*\.

          + __\#__

            An integer\.

          + __\#\#__

            A list of integers\.

          + __/__

            A number \-integer or float\-\.

          + __\!=123__

            An integer that is not 123\.

          + __\!=123\.0__

            A number \-integer or float\- that is neither 123 nor 123\.0\.

          + __>123__

            An integer that is larger than 123\.

          + __>123\.0__

            A number \-integer or float\- that is larger than 123 or 123\.0\.

          + __<123__

            An integer that is smaller than 123\.

          + __<123\.0__

            A number \-integer or float\- that is smaller than 123 or 123\.0\.

          + __>=123__

            An integer that is larger than or equal 123\.

          + __>=123\.0__

            A number \-integer or float\- that is larger than or equal 123 or
            123\.0\.

          + __<=123__

            An integer that is smaller than or equal 123\.

          + __<=123\.0__

            A number \-integer or float\- that is smaller than or equal 123 or
            123\.0\.

          + __~__

            A regular expression as understood by Tcl's __regexp__ command\.

          + __%__

            A format string as understood by Tcl's __format__ command\.

          + __'__

            A timezone name as understood by Tcl's __clock \-timezone__
            command option\.

          + __\.__

            A string index as understood by Tcl's __string index__ command\.

          + __\-__

            A string range as understood by Tcl's __string range__ command
            or a string index as understood by Tcl's __string index__
            command\.

          + __&#124;__

            A list of pairs as understood by Tcl's __string map__ command\.

          + __:__

            A dict as understood by Tcl's __dict__ command\.

          + __\!__

            Tcl code, either as a body or as an expression\.

          + __\{\}__

            A schema\.

          + __\{\_\}__

            A list of schemas\.

          + __\{&#124;\}__

            A dict of schema\-schema pairs\.

          + __\{:\}__

            A dict of key\-schema pairs\.

      * The *body* is the Tcl body of the method\.

See the files "builtinCollectingMethods\.tcl" and "builtinComposingMethods\.tcl"
from the library installation directory \(often "/usr/share/tcl/xjson1\.5/"\) for
examples on how to write your own custom methods\.

## <a name='subsection6'></a>NESTING

With each collector/composer object you construct from the classes produced by
__::xjson::makeCollectorClass__ or __::xjson::makeComposerClass__, you
may specify other collector/composer objects that should be accessible from
within the registered schema by a *nestedCollectorName*/*nestedComposerName*
alias\. The rationale of this is creating libraries of different
collector/composer objects for often used JSON aggregates in your application,
and calling them from an uplevel or the toplevel schema\.

The __nest__ method makes use of this function\. It takes an alias name and
calls the __collect__/__compose__ method of the nested object with the
decoded JSON input data at that point, and the path\. The nested object takes
care of the input data, validates it with its own schema, and returns the result
to the calling object\.

The specified nested objects do not have to exist when the calling object is
constructed\. It is also not checked which class the nested object has\. You may
specify any object that has a __collect__/__compose__ method with the
same semantics as those produced by __::xjson::makeCollectorClass__ resp\.
__::xjson::makeComposerClass__\.

The dubious/trusted flag is local to each object\. This may be used to create
collector/composer objects with application provided schemas and elevated rights
that a object with user\-provided schem and restricted rights may call\.

## <a name='subsection7'></a>SANDBOXING

User supplied data is never evaluated as code by any builtin method\. All the
considerations below are about configuration\-supplied rather than
programmer\-supplied schemas\.

On construction of the collector/composer object, you may specify the
__\-trusted__ option to enable Tcl code evaluation from the schema\. If not
specified, using those methods and options in the supplied schema will throw an
error instead and the object won't be constructed at all\.

Schemas may specify collecting/composing methods \(e\.g\. __apply__,
__expr__, __lmap__\) or options \(e\.g\. __\-test__, __\-transform__\)
that rely on Tcl code supplied from within the schema\. To use such schemas in a
safe fashion, all that Tcl code is executed in a safe interpreter \(a sandbox\) as
supplied by Tcl's __interp \-safe__ command\.

Sandbox creation and destruction after use happens automatically whenever data
is collected/composed\. That sandbox is shared by all methods in the schema and
may also be used to pass values in global variables between methods\. As a
shortcut, all of the methods that have arguments or options allowing to specify
Tcl code also have an option __\-isolate__, that creates a local sandbox just
for that method automatically\.

# <a name='section5'></a>NULL HANDLING

The procedures __::xjson::encode__, __::xjson::recode__, and
__::xjson::decode__ treat JSON *null* values literally\. As with the JSON
boolean values *true* and *false* that are coded as __literal true__
resp\. __literal false__, JSON *null* values are decoded as __literal
null__ by __::xjson::decode__ and the same literal needs to be specified
to __::xjson::encode__ to produce a JSON *null* value\.
__::xjson::decode__ returns an empty list on empty JSON input, and
__::xjson::encode__ and __::xjson::recode__ throw an error on an attempt
to encode an empty list\.

In contrast, the collector/composer objects constructed from the classes
produced by __::xjson::makeCollectorClass__ and
__::xjson::makeComposerClass__ treat JSON *null* values symbolically\.

A __literal null__ a collector class finds in its decoded JSON input is
treated as if the data field it fills isn't there\. JSON *null*s in arrays are
simply skipped, and they also don't count for the array length\. JSON *null*s
as the value of an object field are treated the same as if that field wasn't
specified in that object\. Schemas may specify a __null__ collecting method
that validates a __literal null__\. It is however treated as such and will
trigger the above null handling in the uplevel schema\. An empty list in the
decoded JSON input data is treated the same as a __literal null__\. A missing
data field is also treated like a __literal null__\.

In composer classes, the methods that emit JSON types have a special option
__\-null__ that allows the schema author to tell which Tcl input value should
be treated as __null__, if any\. If not specified, there will never be a
__null__ value emitted at that place\. The __optional__ method has a
special option __\-emitnull__ that allows the schema author to specify if
downlevel __null__s should be inserted into the emitted JSON object or array
literally instead of simply leaving out that field\.

To change that symbolic treatment of JSON *null*s at specific places, you can
use the __default__ collecting method and tell a default value that should
be used whenever a *null* is encountered in the JSON input at that place\.

# <a name='section6'></a>DATA FORMATS

## <a name='subsection8'></a>DECODED JSON FORMAT

The decoded JSON format as returned by the __::xjson::decode__ and accepted
by the __::xjson::encode__ and __::xjson::recode__ commands is a nested
list of type\-data pairs\.

  - The following types are understood:

      * __array *list*__

        Represents a JSON array\. The *list* argument is a list of type\-data
        pairs\.

      * __object *dict*__

        Represents a JSON object\. The *dict* argument is a dict of Tcl strings
        used for the JSON object keys and the values as type\-data pairs\.

      * __string *value*__

        Represents a JSON string\. The *value* argument is the Tcl
        representation of that string\.

      * __number *value*__

        Represents a JSON number\. The *value* argument is the Tcl
        representation of that number\.

      * __literal *value*__

        Represents a JSON literal\. The *value* argument is one of the
        constants __true__, __false__, or __null__\.

        *Note:* Arbitrary Tcl boolean values are not accepted by
        __::xjson::encode__ and __::xjson::recode__\. The *value* must
        be one of the constants above\. The builtin __boolean__ method of the
        composer classes is aware of that\.

      * __encoded *json*__

        This type is meant for encoding in multiple steps\. It is accepted by
        __::xjson::encode__ and __::xjson::recode__, it is never
        returned by __::xjson::decode__\. __::xjson::encode__ does no
        checks on the *json* argument, it must be valid JSON\.
        __::xjson::recode__ however checks the *json* argument for
        syntatic validity as it recodes it\.

      * __decoded *decodedJson*__

        This type is meant for encoding in multiple steps\. It is accepted by
        __::xjson::encode__ and __::xjson::recode__, it is never
        returned by __::xjson::decode__\. The *decodedJson* is first
        encoded by __::xjson::encode__, then inserted in the output\. This is
        sometimes useful if the type information in the input is dynamic as
        well\. __::xjson::recode__ checks the *decodedJson* argument for
        syntatic validity as it recodes it\.

## <a name='subsection9'></a>JSON PATCH FORMAT

The JSON patch format as returned by the __::xjson::diff__ and accepted by
the __::xjson::patch__ and __::xjson::rpatch__ commands is a nested list
of diff operations\.

  - The following operations are understood:

      * __replace *oldDecodedJson* *newDecodedJson*__

        Replace *oldDecodedJson* with *newDecodedJson*\. This operation works
        on all decoded JSON types\.

      * __keys *dictOfOperations*__

        Apply the *dictOfOperations* to the noted keys of an __object__
        decoded JSON type\.

      * __add *decodedJson*__

        Add the *decodedJson* to the __object__ under the noted key\. This
        operation works only inside a __keys__ operation\.

      * __delete *decodedJson*__

        Delete the *decodedJson* from the __object__ under the noted key\.
        This operation works only inside a __keys__ operation\.

      * __indices *pairsOfOperations*__

        Apply the *pairsOfOperations* to the noted indices of an __array__
        decoded JSON type\.

      * __insert *listOfDecodedJson*__

        Insert the *listOfDecodedJson* into the __array__ at the noted
        index\. This operation works only inside an __indices__ operation\.

      * __remove *listOfDecodedJson*__

        Remove the *listOfDecodedJson* from the __array__ at the noted
        index\. This operation works only inside an __indices__ operation\.

# <a name='section7'></a>EXAMPLES

## <a name='subsection10'></a>DECODING EXAMPLES

Decode an array of array of numbers\.

    % ::xjson::decode {[[1,2],[3,4]]}
    array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}

Decode an object of various types\.

    % ::xjson::decode {{"foo":"hello","bar":42,"quux":null}}
    object {foo {string hello} bar {number 42} quux {literal null}}

Same with arbitrary whitespace\.

    % ::xjson::decode {
    {
        "foo":  "hello",
        "bar":  42,
        "quux": null
    }
    }
    object {foo {string hello} bar {number 42} quux {literal null}}

## <a name='subsection11'></a>ENCODING EXAMPLES

Encode an array of array of numbers\.

    % ::xjson::encode {array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}} 0 {}
    [[1,2],[3,4]]

Encode an object of various types\.

    % ::xjson::encode {object {foo {string hello} bar {number 42} quux {literal null}}} 0 {}
    {"foo":"hello","bar":42,"quux":null}

Same with pretty printing\.

    % ::xjson::encode {object {foo {string hello} bar {number 42} quux {literal null}}}
    {
        "foo":  "hello",
        "bar":  42,
        "quux": null
    }

Encode with pre\-encoded data\.

    % set json {"hello"}
    % ::xjson::encode [list object [list foo [list encoded $json] bar {number 42} quux {literal null}]] 0 {}
    {"foo":"hello","bar":42,"quux":null}

Encode with nested decoded data\.

    % set type decoded
    % set data {string hello}
    % ::xjson::encode [list object [list foo [list $type $data] bar {number +42} quux {literal null}]] 0 {}
    {"foo":"hello","bar":42,"quux":null}

## <a name='subsection12'></a>RECODING EXAMPLES

Recode pre\-encoded data\.

    % set json {"oof rab"}
    % ::xjson::recode [list object [list foo [list encoded $json] bar {number +42} quux {literal null}]]
    object {foo {string {oof rab}} bar {number 42} quux {literal null}}

Recode with nested decoded data\.

    % set type decoded
    % set data {string "oof rab"}
    % ::xjson::recode [list object [list foo [list $type $data] bar {number +42} quux {literal null}]]
    object {foo {string {oof rab}} bar {number 42} quux {literal null}}

## <a name='subsection13'></a>DIFF EXAMPLES

Feed two sets of slightly different JSON data into the decoder and remember the
result\.

    % set old [::xjson::decode {
        {
            "articles": [
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
            ]
        }
    }]

    % set new [::xjson::decode {
        {
            "articles": [
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
            ]
        }
    }]

Calculate the patch data\.

    % ::xjson::diff $old $new
    keys {articles {indices {0 {keys {extra {add {literal true}}}} 2 {remove {{object {id {number 139} name {string Wunschpizza} price {number 12.7}}} {object {id {number 201} name {string Rucola} extra {literal true} price {number 1}}}}} 2 {insert {{object {id {number 138} name {string {Pizza Hawaii}} price {number 12.0}}} {object {id {number 139} name {string Wunschpizza} price {number 13.5}}} {object {id {number 201} name {string Rucola} price {number 1}}}}}}}}

## <a name='subsection14'></a>PATCH EXAMPLES

Feed JSON data into the decoder and remember the result\.

    % set old [::xjson::decode {
        {
            "articles": [
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
            ]
        }
    }]

Dig out matching patch data\.

    % set patch {keys {articles {indices {0 {keys {extra {add {literal true}}}} 2 {remove {{object {id {number 139} name {string Wunschpizza} price {number 12.7}}} {object {id {number 201} name {string Rucola} extra {literal true} price {number 1}}}}} 2 {insert {{object {id {number 138} name {string {Pizza Hawaii}} price {number 12.0}}} {object {id {number 139} name {string Wunschpizza} price {number 13.5}}} {object {id {number 201} name {string Rucola} price {number 1}}}}}}}}}

Apply the patch and encode it\.

    % ::xjson::encode [::xjson::patch $old $patch]
    {
        "articles": [
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
        ]
    }

## <a name='subsection15'></a>JSON VALIDATION AND DATA COLLECTING EXAMPLE

Create a collector class with the class factory and the builtin methods\. Even
for advanced usage, you only ever need to do this once\. More than once only if
you want to create multiple collector classes with a different set of builtin
and your own collection methods, or different options\.

    % ::xjson::makeCollectorClass ::myCollectorClass

Create a collector object with a schema\. You need to do this once per different
schema you want to use\.

    % set ::mycollector [::myCollectorClass #auto {
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
    }]

Feed JSON data into the decoder, and the decoded json data into the collector
object\.

    % $::mycollector collect [::xjson::decode {
        {
            "articles": [
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
            ]
        }
    }]
    articles {101 {extra false name {Pizzapane bianca} price 4.95} 120 {extra false name {Pizza Regina} price 9.80} 139 {extra false name Wunschpizza price 12.70} 201 {extra true name Rucola price 1.00}}

## <a name='subsection16'></a>JSON COMPOSING EXAMPLE

Create a composer class with the class factory and the builtin methods\. Even for
advanced usage, you only ever need to do this once\. More than once only if you
want to create multiple composer classes with a different set of builtin and
your own composer methods, or different options\.

    % ::xjson::makeComposerClass ::myComposerClass

Create a composer object with a schema\. You need to do this once per different
schema you want to use\.

    % set ::mycomposer [::myComposerClass #auto {
        array {
            object {
                id   integer
                name string
            }
        }
    }]

Feed Tcl data into the composer object, and the result into the encoder\.

    % ::xjson::encode [$::mycomposer compose {{id 7 name foo} {id 3 name bar}}]
    [
        {
            "id":   7,
            "name": "foo"
        },
        {
            "id":   3,
            "name": "bar"
        }
    ]

## <a name='subsection17'></a>JSON RECOMPOSING EXAMPLE

This toy example decodes and validates a JSON input, collects the data, then
recomposes the data into JSON\.

    % ::xjson::makeCollectorClass ::myCollectorClass
    % ::xjson::makeComposerClass ::myComposerClass

    % set ::mycollector [::myCollectorClass #auto {
    dictbyindex 1 {array {object -values {id integer name {stringop -toupper {0 end} string} comment string}}}
    }]

    % set ::mycomposer [::myComposerClass #auto {
    dictbyindex 1 {array {object -values {id integer name {stringop -tolower {0 end} string} comment string}}}
    }]

    % set step0 {[{"id": 1, "name": "abc", "comment": "foo"}, {"id": 981, "name": "xyz", "comment": "bar"}]}
    [{"id": 1, "name": "abc", "comment": "foo"}, {"id": 981, "name": "xyz", "comment": "bar"}]

    % set step1 [::xjson::decode $step0]
    array {{object {id {number 1} name {string abc} comment {string foo}}} {object {id {number 981} name {string xyz} comment {string bar}}}}

    % set step2 [$mycollector collect $step1]
    ABC {1 foo} XYZ {981 bar}

    % set step3 [$mycomposer compose $step2]
    array {{object {id {number 1} name {string abc} comment {string foo}}} {object {id {number 981} name {string xyz} comment {string bar}}}}

    % set step4 [::xjson::encode $step3 0 {}]
    [{"id":1,"name":"abc","comment":"foo"},{"id":981,"name":"xyz","comment":"bar"}]

# <a name='keywords'></a>KEYWORDS

diff, json, patch, tcl, validation

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2021 Jan Kandziora <jjj@gmx\.de>, BSD\-2\-Clause license

