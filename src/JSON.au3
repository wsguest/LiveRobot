#include-once

#comments-start
	JSON.au3 每 an RFC4627-compliant JSON UDF Library
		written by Gabriel Boehme, version 0.9.1 (2009-10-19)
		for AutoIt v3.3.0.0 or greater

	thanks to:
		Douglas Crockford, for writing the original JSON conversion code in Javascript (circa 2005-07-15),
			which provided the starting point for this library

	general notes:
		? visit http://www.JSON.org/ for more information about JSON
		? this library conforms to the official JSON specifications given in RFC4627
			? http://www.ietf.org/rfc/rfc4627.txt?number=4627

	system dependencies:
		? the Scripting.Dictionary ActiveX/COM object
			? used internally for testing key uniqueness in JSON objects, and generating empty AutoIt arrays
			? should be available on Windows 98 or later, or any Windows system with IE 5 or greater installed
			? Scripting.Dictionary documentation can be found online at:
				? http://www.devguru.com/Technologies/vbscript/quickref/dictionary.html
				? http://www.csidata.com/custserv/onlinehelp/VBSdocs/vbs390.htm
				? http://msdn2.microsoft.com/en-us/library/x4k5wbx4.aspx

	notes on decoding:
		? this decoder implements all required functionality specified in RFC4627
		? notes on decoding certain JSON data types:
			? null
				? AutoIt currently has no native ※null§-type value
				? this library uses $_JSONNull to represent null, defined using the ※default§ keyword
					? be sure to use the JSON null abstractions provided within this library, as this definition of ※null§ may change in future
			? arrays
				? JSON arrays are decoded ※as-is§ to one-dimensional AutoIt arrays
				? empty arrays ARE possible
					? AutoIt does not currently allow us to define empty arrays within the language itself
					? nevertheless, they can be returned from functions, and processed like any other array
					? empty JSON arrays will be returned as empty AutoIt arrays
			? objects
				? a special two-dimensional array is used to represent a JSON object
					? $o[$i][0] = the key, $o[$i][1] = the value, for any $i >= 1
						? this should provide compatibility with the 2D array-handling functions in the standard Array.au3 UDF
					? to uniquely identify the 2D array as a JSON object, $o[0] will always contain the following:
						? $o[0][0] = $_JSONNull, $o[0][1] = 'JSONObject'
				? a decoding error occurs if the JSON text specifies an object with duplicate key values [RFC4627:2.2]
					? this error can be suppressed by using the optional $allowDuplicatedObjectKeys parameter
						? this means that the LAST value specified for that key ※wins§ (i.e., the earlier value for that key is overwritten)
		? additionally, the following (non-RFC4627-compliant) decoding extensions have been implemented:
			? objects and arrays
				? whitespace may substitute for commas between elements
					? this eliminates the annoyance of having to manage commas when manually updating indented JSON text
			? objects
				? keys can be specified without quotes, as long as they＊re alphanumeric (i.e., composed of only ASCII letters, numbers, underscore)
				? unquoted keys beginning with a digit (0-9) will first be decoded as numbers, then converted to string
			? strings
				? allowed to be delimited by either single or double quotes
				? additional escape sequences allowed:
					? \' single quote 每 allows single quotes to be specified within a single-quoted string
					? \v vertical tab 每 equivalent to \u000B
			? numbers
				? allowed to have leading zeroes, which are ignored (i.e., they do NOT signal an octal number)
				? allowed to have a leading plus sign
				? hexadecimal integer notation (0x) is allowed
					? hex integers are always interpreted as unsigned
					? a negative sign should be used to indicate negative hex integers (e.g., -0xF = -15)
			? Javascript-style comments
				? // Javascript line comments are allowed
				? /* Javascript block comments are allowed */
			? whitespace between identifiers
				? \u0020 (space) and \u0009 thru \u000D (tab thru carriage return) are regarded as whitespace
				? this matches the definition of the native AutoIt3 stringIsSpace() function, which is used to determine whitespace in this library

	notes on encoding:
		? by default, this encoder conforms strictly to RFC4627 when producing output
		? notes on encoding AutoIt data types:
			? arrays
				? all one-dimensional AutoIt arrays will be encoded ※as-is§ to JSON arrays
				? for two-dimensional AutoIt arrays, only those representing JSON objects are supported
					? all JSON object keys ($a[$i][0] of the 2D array) will be encoded as strings, as required by RFC4627
					? if duplicate key strings are encountered, the FIRST one ※wins§ (i.e., later key duplicates will be ignored)
			? strings
				? as JSON is a unicode data format, it is assumed that nearly all characters can be encoded as themselves
				? a RegExp is used internally to escape certain characters (control characters, etc.)
			? numbers
				? the default AutoIt number-to-string conversion is used, which produces JSON-compatible output
			? booleans
				? encoded normally
			? $_JSONNull
				? encoded as ※null§ (obviously)
			? anything else
				? any unsupported data type will be quietly encoded as ※null§, and will flag a warning
					? BitAnd(@error,1) will return 1, and @extended will contain a count of the total number of unsupported values encountered
				? use a translator function to convert unsupported values to supported values when encoding
		? NON-RFC4627-COMPLIANT OPTION: when indenting, the optional $omitCommas parameter can be used
			? produces indented output WITHOUT commas between object or array elements
			? complements the ability of this decoder to allow whitespace to substitute for commas (see above)

	to do:
		? continue revising & testing error handling (bit of a mess at the moment)
			? continue adding $_JSONErrorMessage asssignments
				? check against VB version, to mirror the same level of detailed error reporting where applicable
			? figure out how to make better use of AutoIt error handling in general
		? start adding UDF function comments (see String.au3 or Array.au3 for examples)
		? remove dependency on Scripting.Dictionary?
			? we＊d need to figure out other ways to:
				? efficiently test key uniqueness for JSON objects
				? obtain empty AutoIt arrays

	legal:
		Copyright ? 2007-2009 Gabriel Boehme

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the ※Software§), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included
			in all copies or substantial portions of the Software.

		The Software shall be used for Good, not Evil.

		THE SOFTWARE IS PROVIDED ※AS IS§, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.
#comments-end

;===============================================================================
; JSON general functions
;===============================================================================

; since AutoIt does not have a native ※null§ value, we currently use ※default§ to uniquely identify null values
; always use _JSONIsNull() to test for null, as this definition may change in future
global const $_JSONNull=default

func _JSONIsNull($v)
	; uniquely identify $_JSONNull
	return $v==default
endfunc

;-------------------------------------------------------------------------------
; returns a new array, optionally populated with the parameters specified
; if no parameters are specified, returns an empty array 每 very handy as AutoIt doesn＊t let you do this natively
;-------------------------------------------------------------------------------
func _JSONArray($p0=0,$p1=0,$p2=0,$p3=0,$p4=0,$p5=0,$p6=0,$p7=0,$p8=0,$p9=0,$p10=0,$p11=0,$p12=0,$p13=0,$p14=0,$p15=0,$p16=0,$p17=0,$p18=0,$p19=0,$p20=0,$p21=0,$p22=0,$p23=0,$p24=0,$p25=0,$p26=0,$p27=0,$p28=0,$p29=0,$p30=0,$p31=0)
	if @NumParams then
		; populate an array with the given values and return it
		local $a[32]=[$p0,$p1,$p2,$p3,$p4,$p5,$p6,$p7,$p8,$p9,$p10,$p11,$p12,$p13,$p14,$p15,$p16,$p17,$p18,$p19,$p20,$p21,$p22,$p23,$p24,$p25,$p26,$p27,$p28,$p29,$p30,$p31]
		redim $a[@NumParams]
		return $a
	endif
	; return an empty array
	local $d=objCreate('Scripting.Dictionary')
	return $d.keys() ; this empty Dictionary object will return an empty array of keys
endfunc

func _JSONIsArray($v)
	return isArray($v) and ubound($v,0)==1
endfunc

;-------------------------------------------------------------------------------
; allows the programmer to more easily invoke a Scripting.Dictionary object for JSON use
; can optionally specify key/value pairs: _JSONObject('key1','value1','key2','value2')
;-------------------------------------------------------------------------------
func _JSONObject($p0=0,$p1=0,$p2=0,$p3=0,$p4=0,$p5=0,$p6=0,$p7=0,$p8=0,$p9=0,$p10=0,$p11=0,$p12=0,$p13=0,$p14=0,$p15=0,$p16=0,$p17=0,$p18=0,$p19=0,$p20=0,$p21=0,$p22=0,$p23=0,$p24=0,$p25=0,$p26=0,$p27=0,$p28=0,$p29=0,$p30=0,$p31=0)
	if @NumParams then
		local $a[32]=[$p0,$p1,$p2,$p3,$p4,$p5,$p6,$p7,$p8,$p9,$p10,$p11,$p12,$p13,$p14,$p15,$p16,$p17,$p18,$p19,$p20,$p21,$p22,$p23,$p24,$p25,$p26,$p27,$p28,$p29,$p30,$p31]
		redim $a[@NumParams]
		return _JSONObjectFromArray($a)
	endif
	return _JSONObjectFromArray(0)
endfunc

func _JSONObjectFromArray($a)
	local $o[1][2]=[[$_JSONNull,'JSONObject']],$len=ubound($a)
	if $len then
		; populate with the given key/value pairs
		redim $o[floor($len/2)+1][2]
		local $oi=1
		local $d=objCreate('Scripting.Dictionary') ; used to check for duplicate keys
		for $ai=1 to $len-1 step 2
			local $k=string($a[$ai-1])
			if $d.exists($k) then
				; duplicate key specified
				return setError(1,$d.count+1,0)
			endif
			$d.add($k,true) ; keep track of the keys in use
			$o[$oi][0]=$k
			$o[$oi][1]=$a[$ai]
			$oi+=1
		next
	endif
	return $o
endfunc

func _JSONIsObject($v)
	if isArray($v) and ubound($v,0)==2 and ubound($v,2)==2 then
		return _JSONIsNull($v[0][0]) and $v[0][1]=='JSONObject'
	endif
	return false
endfunc

; variable containing more detailed error information
global $_JSONErrorMessage=''

; internally-used variables for decoding/encoding
local $__JSONTranslator
local $__JSONReadNextFunc,$__JSONOffset,$__JSONAllowDuplicatedObjectKeys
local $__JSONCurr,$__JSONWhitespaceWasFound
local $__JSONDecodeString,$__JSONDecodePos
local $__JSONIndentString,$__JSONIndentLen,$__JSONComma,$__JSONColon
local $__JSONEncodeErrFlags,$__JSONEncodeErrCount

;===============================================================================
; JSON decoding user functions
;===============================================================================

;-------------------------------------------------------------------------------
; reads a single JSON value from a text file
;-------------------------------------------------------------------------------
func _JSONDecodeWithReadFunc($funcName,$translator='',$allowDuplicatedObjectKeys=false,$postCheck=false)
	; reset the error message
	$_JSONErrorMessage=''

	if not __JSONSetTranslator($translator) then
		return setError(999,0,0)
	endif

	$__JSONReadNextFunc=$funcName
	$__JSONOffset=0

	$__JSONAllowDuplicatedObjectKeys=$allowDuplicatedObjectKeys

	; read the first character
	__JSONReadNext()
	if @error then
		return setError(@error,@extended,0)
	endif

	; decode
	local $v=__JSONDecodeInternal()
	if @error then
		return setError(@error,@extended,0)
	endif

	if $postCheck then
		; make sure there＊s nothing left to decode afterwards; if there is, consider it an error
		if __JSONSkipWhitespace() then
			$_JSONErrorMessage='string contains unexpected text after the decoded JSON value'
			return setError(99,0,0)
		endif
	endif

	if $translator then
		$v=__JSONDecodeTranslateWalk($_JSONNull,$_JSONNull,$v)
	endif
	if @error then
		return setError(@error,@extended,$v)
	endif

	return $v
endfunc

;-------------------------------------------------------------------------------
; decodes a JSON string containing a single JSON value
;-------------------------------------------------------------------------------
func _JSONDecode($s,$translator='',$allowDuplicatedObjectKeys=false,$startPos=1)
	$__JSONDecodeString=string($s)
	$__JSONDecodePos=$startPos
	local $v=_JSONDecodeWithReadFunc('__JSONReadNextFromString',$translator,$allowDuplicatedObjectKeys,true)
	if @error then
		return setError(@error,@extended,$v)
	endif
	return $v
endfunc

;-------------------------------------------------------------------------------
; decodes a JSON string containing one or more JSON values, returning the results in an array
;-------------------------------------------------------------------------------
func _JSONDecodeAll($s,$translator='',$allowDuplicatedObjectKeys=false)
	; since we do not require commas for decoding,
	; we can simply enclose the JSON text in brackets, and decode the series of JSON values as an array
	local $v=_JSONDecode('[' & $s & @LF & ']',$translator,$allowDuplicatedObjectKeys)
	if @error then
		return setError(@error,@extended,$v)
	endif
	return $v
endfunc


;===============================================================================
; JSON encoding user functions
;===============================================================================

;-------------------------------------------------------------------------------
; encodes a value to JSON string
;
; if $indent is specified, the encoded string will contain indentations and line breaks to show the data structure
; $linebreak is used to specify the newline separator desired when indenting
;-------------------------------------------------------------------------------
func _JSONEncode($v,$translator='',$indent='',$linebreak=@CRLF,$omitCommas=false)
	; reset the error message
	$_JSONErrorMessage=''

	if not __JSONSetTranslator($translator) then
		return setError(999,0,0)
	endif

	if $indent and $linebreak then
		; we＊re indenting
		if isBool($indent) then
			$__JSONIndentString=@TAB
		else
			$__JSONIndentString=string($indent)
		endif
		$__JSONIndentLen=stringLen($__JSONIndentString)

		; pad colon with a space
		$__JSONColon=': '

		; omit commas if requested (IMPORTANT: this is NOT an RFC4627-compliant option!)
		if $omitCommas then
			$__JSONComma=''
		else
			$__JSONComma=','
		endif
	else
		; not indenting
		$indent=''
		$linebreak=''
		$__JSONColon=':'
		$__JSONComma=','
	endif

	; reset our ※warning§ error flags
	$__JSONEncodeErrFlags=0
	$__JSONEncodeErrCount=0

	local $s=__JSONEncodeInternal($_JSONNull,$_JSONNull,$v,$linebreak) & $linebreak ; start indentation with the linebreak character
	if @error then
		; a show-stopping error of some kind
		return setError(@error,@extended,'')
	endif
	if $__JSONEncodeErrCount then
		; return encoded JSON string, but also indicate the presence of errors resulting in values changed to null or omitted during encoding
		return setError($__JSONEncodeErrFlags,$__JSONEncodeErrCount,$s)
	endif
	; no errors encountered
	return $s
endfunc


;===============================================================================
; JSON helper functions
;===============================================================================

func __JSONSetTranslator($translator)
	if $translator then
		; test it first
		local $dummy=call($translator,0,0,0)
		if @error==0xDEAD and @extended==0xBEEF then
			$_JSONErrorMessage='translator function not defined, or defined with wrong number of parameters'
			return false
		endif
	endif
	$__JSONTranslator=$translator
	return true
endfunc

;===============================================================================
; JSON decoding helper functions
;===============================================================================

func __JSONReadNext($numChars=1)
	$__JSONCurr=call($__JSONReadNextFunc,$numChars)
	if @error then
		if @error==0xDEAD and @extended==0xBEEF then
			$_JSONErrorMessage='read function not defined, or defined with wrong number of parameters'
		endif
		return setError(@error,@extended,0)
	endif
	$__JSONOffset+=stringLen($__JSONCurr) ; now pointing to the offset for the next read
	return $__JSONCurr
endfunc

func __JSONReadNextFromString($numChars)
	; move to the next char and return it
	local $s=stringMid($__JSONDecodeString,$__JSONDecodePos,$numChars)
	$__JSONDecodePos+=$numChars
	return $s
endfunc

func __JSONSkipWhitespace()
	$__JSONWhitespaceWasFound=false
	while $__JSONCurr
		if stringIsSpace($__JSONCurr) then
			; whitespace, skip
			$__JSONWhitespaceWasFound=true
		elseif $__JSONCurr=='/' then
			; check for comments to skip (decoding extension)
			switch __JSONReadNext()
			case '/'
				; line comment, skip until end-of-line (or no more characters)
				while __JSONReadNext() and not stringRegExp($__JSONCurr,"[\n\r]",0)
				wend
				if $__JSONCurr then
					$__JSONWhitespaceWasFound=true
				else
					; we＊ve reached the end
					return ''
				endif
			case '*'
				; start of block comment, skip until end of block comment found
				__JSONReadNext()
				while $__JSONCurr
					if $__JSONCurr=='*' then
						if __JSONReadNext()=='/' then
							; end of block comment found
							exitloop
						endif
					else
						__JSONReadNext()
					endif
				wend
				if not $__JSONCurr then
					$_JSONErrorMessage='unterminated block comment'
					exitloop
				endif
			case else
				$_JSONErrorMessage='bad comment syntax'
				exitloop
			endswitch
		else
			; this is neither whitespace nor a comment, so we return it
			return $__JSONCurr
		endif

		; if we make it here, we＊re still looping, so proceed to the next character
		__JSONReadNext()
	wend

	return setError(2,0,0)
endfunc

func __JSONDecodeObject()
	local $d=objCreate('Scripting.Dictionary'),$key
	local $o=_JSONObject(),$len=1,$i

	if $__JSONCurr=='{' then
		__JSONReadNext()
		if __JSONSkipWhitespace()=='}' then
			; empty object
			__JSONReadNext()
			return $o
		endif

		while $__JSONCurr
			$key=__JSONDecodeObjectKey()
			if @error then
				return setError(@error,@extended,0)
			endif

			if __JSONSkipWhitespace()<>':' then
				$_JSONErrorMessage='expected ":", encountered "' & $__JSONCurr & '"'
				exitloop
			endif

			if $d.exists($key) then
				; this key is defined more than once for this object
				if $__JSONAllowDuplicatedObjectKeys then
					; replace the current key value with the upcoming value
					$i=$d.item($key)
				else
					$_JSONErrorMessage='duplicate key specified for object: "' & $key & '"'
					exitloop
				endif
			else
				; adding a new key/value pair
				$i=$len
				$len+=1
				redim $o[$len][2]

				$o[$i][0]=$key
				$d.add($key,$i) ; keep track of key index
			endif

			__JSONReadNext()
			$o[$i][1]=__JSONDecodeInternal()
			if @error then
				return setError(@error,@extended,0)
			endif

			switch __JSONSkipWhitespace()
			case '}'
				; end of object
				__JSONReadNext()
				return $o
			case ','
				__JSONReadNext()
				__JSONSkipWhitespace()
				If $__JSONCurr == '}' Then
					__JSONReadNext()
					return $o
				EndIf
			case else
				if not $__JSONWhitespaceWasFound then
					; badly-formatted object
					$_JSONErrorMessage='expected "," or "}", encountered "' & $__JSONCurr & '"'
					exitloop
				endif
			endswitch
		wend
	endif

	return setError(3,0,0)
endfunc

func __JSONDecodeObjectKey()
	if $__JSONCurr=='"' or $__JSONCurr=="'" then
		; decode string as normal
		return __JSONDecodeString()
	endif

	if stringIsDigit($__JSONCurr) then
		; decode number as normal, returning string representation of number to use as key
		return string(__JSONDecodeNumber())
	endif

	; decode quoteless key string
	local $s=''
	while(stringIsAlNum($__JSONCurr) or $__JSONCurr=='_')
		$s &= $__JSONCurr
		__JSONReadNext()
	wend
	if not $s then
		$_JSONErrorMessage='expected object key, encountered "' & $__JSONCurr & '"'
		return setError(13,0,0)
	endif
	return $s
endfunc

func __JSONDecodeArray()
	local $a=_JSONArray(),$len=0

	if $__JSONCurr=='[' then
		__JSONReadNext()
		if __JSONSkipWhitespace()==']' then
			; empty array
			__JSONReadNext()
			return $a
		endif

		while $__JSONCurr
			$len+=1
			redim $a[$len]
			$a[$len-1]=__JSONDecodeInternal()
			if @error then
				return setError(@error,@extended,0)
			endif

			switch __JSONSkipWhitespace()
			case ']'
				; end of array
				__JSONReadNext()
				return $a
			case ','
				__JSONReadNext()
				__JSONSkipWhitespace()
				If $__JSONCurr == ']' Then
					__JSONReadNext()
					return $a
				EndIf
			case else
				if not $__JSONWhitespaceWasFound then
					; badly-formatted array
					$_JSONErrorMessage='expected "," or "]", encountered "' & $__JSONCurr & '"'
					exitloop
				endif
			endswitch
		wend
	endif

	return setError(4,0,0)
endfunc

func __JSONDecodeString()
	local $s='',$q=$__JSONCurr ; save our beginning quote char so we know what we＊re matching

	if $q=='"' or $q=="'" then
		while $__JSONCurr
			__JSONReadNext()
			select
			case $__JSONCurr==$q
				; we＊ve reached the matching end quote char, so we＊re done
				__JSONReadNext()
				return $s
			case $__JSONCurr=='\'
				; interpret the escaped char
				switch __JSONReadNext()
				case '\','/','"',"'"
					$s &= $__JSONCurr
				case 't'
					$s &= @TAB
				case 'n'
					$s &= @LF
				case 'r'
					$s &= @CR
				case 'f'
					$s &= chrw(0xC) ; form feed / page break
				case 'b'
					$s &= chrw(0x8) ; backspace
				case 'v'
					$s &= chrw(0xB) ; vertical tab (decoding extension)
				case 'u'
					; unicode escape sequence
					if stringIsXDigit(__JSONReadNext(4)) then
						$s &= chrw(dec($__JSONCurr))
					else
						; invalid unicode escape sequence
						exitloop
					endif
				case else
					; unrecognized escape character
					exitloop
				endswitch
			case ascw($__JSONCurr) >= 0x20 ; always use ascw() to compare on unicode value (locale-specific string compares seem to be unreliable)
				; append this character
				$s &= $__JSONCurr
			case else
				; error 每 control characters should always be escaped within a string, we should never encounter them raw like this
				exitloop
			endselect
		wend
	endif

	return setError(5,0,0)
endfunc

func __JSONDecodeHexNumber($negative)
	; we decode hex integers ※manually§ like this, to avoid the limitations of AutoIt＊s built-in 32-bit signed integer interpretation
	local $n=0

	while stringIsXDigit(__JSONReadNext())
		$n=$n*0x10+dec($__JSONCurr)
	wend

	if $negative then
		return -$n
	endif
	return $n
endfunc

func __JSONDecodeNumber()
	local $s=''

	if $__JSONCurr=='+' or $__JSONCurr=='-' then
		; leading sign
		$s &= $__JSONCurr
		__JSONReadNext()
	endif

	; code added to allow parsing of 0x hex integer notation (decoding extension)
	if $__JSONCurr=='0' then
		$s &= $__JSONCurr
		__JSONReadNext()
		if stringLower($__JSONCurr)=='x' then
			; we have a hex integer
			return __JSONDecodeHexNumber(stringLeft($s,1)=='-')
		endif
	endif

	; decimal number, collect digits
	while stringIsDigit($__JSONCurr)
		$s &= $__JSONCurr
		__JSONReadNext()
	wend

	if $__JSONCurr=='.' then
		; decimal point found, collect digits
		$s &= $__JSONCurr
		while stringIsDigit(__JSONReadNext())
			$s &= $__JSONCurr
		wend
	endif

	if stringLower($__JSONCurr)=='e' then
		; exponent found, collect sign and digits
		$s &= $__JSONCurr
		__JSONReadNext()
		if $__JSONCurr=='+' or $__JSONCurr=='-' then
			$s &= $__JSONCurr
			__JSONReadNext()
		endif
		while stringIsDigit($__JSONCurr)
			$s &= $__JSONCurr
			__JSONReadNext()
		wend
		; number() doesn＊t handle exponential notation, so we use execute() here
		return execute($s)
	endif

	return number($s)
endfunc

func __JSONDecodeLiteral()
	switch $__JSONCurr
	case 't'
		if __JSONReadNext(3)=='rue' then
			__JSONReadNext()
			return true
		endif
	case 'f'
		if __JSONReadNext(4)=='alse' then
			__JSONReadNext()
			return false
		endif
	case 'n'
		if __JSONReadNext(3)=='ull' then
			__JSONReadNext()
			return $_JSONNull
		endif
	endswitch

	return setError(7,0,0)
endfunc

func __JSONDecodeInternal()
	local $v
	switch __JSONSkipWhitespace()
	case '{'
		$v=__JSONDecodeObject()
	case '['
		$v=__JSONDecodeArray()
	case '"',"'" ; allow strings to be single- or double-quoted (decoding extension)
		$v=__JSONDecodeString()
	case '0' to '9','-','+' ; allow numbers to start with a plus sign (decoding extension)
		$v=__JSONDecodeNumber()
	case else
		$v=__JSONDecodeLiteral()
	endswitch
	if @error then
		return setError(@error,@extended,$v)
	endif
	return $v
endfunc

; here, we walk through the raw results from our JSON decoding, calling the translator function for each value
func __JSONDecodeTranslateWalk(const byRef $holder, const byRef $key,$value)
	local $v

	if isArray($value) then
		if _JSONIsObject($value) then
			for $i=1 to ubound($value)-1
				$v=__JSONDecodeTranslateWalk($value,$value[$i][0],$value[$i][1])
				switch @error
				case 0
					; no error, assign returned value
					$value[$i][1]=$v
				case 4627
					; remove this key/value pair
					$value[$i][0]=$_JSONNull ; wipe out key (placeholder logic for now)
				case else
					; an error
					return setError(@error,@extended,0)
				endswitch
			next
		else ; this can only be a one-dimensional array
			for $i=0 to ubound($value)-1
				$v=__JSONDecodeTranslateWalk($value,$i,$value[$i])
				switch @error
				case 0
					; no error, assign returned value
					$value[$i]=$v
				case 4627
					; we can＊t completely remove values from arrays (as that could disrupt element positioning), so set to JSON null instead
					$value[$i]=$_JSONNull
				case else
					; an error
					return setError(@error,@extended,0)
				endswitch
			next
		endif
	endif

	$v=call($__JSONTranslator,$holder,$key,$value)
	if @error then
		return setError(@error,@extended,0)
	endif
	return $v
endfunc


;===============================================================================
; JSON encoding helper functions
;===============================================================================

func __JSONEncodeObject($o, const byRef $indent)
	local $result='',$inBetween=$__JSONComma & $indent,$d=objCreate('Scripting.Dictionary')

	for $i=1 to ubound($o)-1
		local $key=$o[$i][0]
		if not _JSONIsNull($key) then ; avoid ※deleted§ keys
			$key=string($key)
			if $d.exists($key) then
				; duplicate key 每 add flag to error status and ignore value (earlier value for this key ※wins§)
				$__JSONEncodeErrFlags=BitOr($__JSONEncodeErrFlags,2)
				$__JSONEncodeErrCount+=1
			else
				$d.add($key,true) ; keep track of the keys in use
				local $s=__JSONEncodeInternal($o,$key,$o[$i][1],$indent)
				if @error then
					return setError(@error,@extended,$result)
				endif
				if $s then
					$result &= $inBetween & __JSONEncodeString($key) & $__JSONColon & $s
				endif
			endif
		endif
	next
	if $indent and $result then
		; we＊re indenting, and we don＊t have an empty JSON object, so append the appropriate closing indentation
		$result &= stringTrimRight($indent,$__JSONIndentLen)
	endif

	; remove the initial comma and return the result
	return '{' & stringTrimLeft($result,stringLen($__JSONComma)) & '}'
endfunc

func __JSONEncodeArray($a, const byRef $indent)
	local $result='',$inBetween=$__JSONComma & $indent

	if ubound($a) then
		for $i=0 to ubound($a)-1
			local $s=__JSONEncodeInternal($a,$i,$a[$i],$indent)
			if @error then
				return setError(@error,@extended,$result)
			endif
			if not $s then
				; we can＊t completely remove values from arrays (as that could disrupt element positioning), so set to null instead
				$s='null'
			endif
			$result &= $inBetween & $s
		next
		if $indent then
			; we＊re indenting, so append the appropriate closing indentation
			$result &= stringTrimRight($indent,$__JSONIndentLen)
		endif
	endif

	; remove the initial comma and return the result
	return '[' & stringTrimLeft($result,stringLen($__JSONComma)) & ']'
endfunc

func __JSONEncodeString($s)
	local const $escape='[\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]'
	local $result,$ch,$u

	; use a regExp replace to escape any backslash or double-quote characters
	; (also implicitly converts $s to a string, if it isn＊t one already)
	$s=stringRegExpReplace($s,'([\"\\])','\\\0')

	if stringRegExp($s,$escape,0) then
		; we have control characters to escape, so we need to reconstruct the string to encode them
		$result=''

		for $i=1 to stringLen($s)
			$ch=stringMid($s,$i,1)

			if stringRegExp($ch,$escape,0) then
				; encode
				$u=ascw($ch)
				switch $u
				case 0x9 ; tab
					$ch='\t'
				case 0xA ; newline
					$ch='\n'
				case 0xD ; carriage return
					$ch='\r'
				case 0xC ; form feed / page break
					$ch='\f'
				case 0x8 ; backspace
					$ch='\b'
				case else
					; encode as unicode character number
					$ch='\u' & hex($u,4)
				endswitch
			endif

			; write our encoded character
			$result &= $ch
		next
	else
		; no control chars present, so our string is already encoded properly
		$result=$s
	endif

	return '"' & $result & '"'
endfunc

func __JSONEncodeInternal(const byRef $holder, const byRef $k,$v,$indent)
	; encode a variable into its JSON string representation
	local $s

	if $indent then
		; append another indentation to the given indent string, and check how deep we are
		$indent &= $__JSONIndentString
		; arbitrary maximum depth check to help identify cyclical data structure errors (e.g., a dictionary containing itself)
		if stringLen($indent)/$__JSONIndentLen > 255 then
			$_JSONErrorMessage='max depth exceeded 每 possible data recursion'
			return setError(1,0,0)
		endif
	endif

	if $__JSONTranslator then
		; call the translator function first
		$v=call($__JSONTranslator,$holder,$k,$v)
		switch @error
		case 0
			; no error
		case 4627
			; signal to remove this value entirely from encoded output, if possible
			return ''
		case else
			; some other error
			return setError(@error,@extended,'')
		endswitch
	endif

	select
	case _JSONIsObject($v)
		$s=__JSONEncodeObject($v,$indent)

	case _JSONIsArray($v)
		$s=__JSONEncodeArray($v,$indent)

	case isString($v)
		$s=__JSONEncodeString($v)

	case isNumber($v)
		; AutoIt＊s native number-to-string conversion will produce valid JSON-compatible numeric output
		$s=string($v)

	case isBool($v)
		$s=stringLower($v)

	case _JSONIsNull($v)
		$s='null'

	case else
		; unsupported variable type; encode as null, flag presence of error
		$__JSONEncodeErrFlags=BitOr($__JSONEncodeErrFlags,1)
		$__JSONEncodeErrCount+=1
		$s='null'

	endselect

	if @error then
		return setError(@error,@extended,$s)
	endif
	return $s
endfunc

Func _JSONGet($json, $path, $seperator = ".")
   Local $seperatorPos,$current,$next,$l
   $seperatorPos = StringInStr($path, $seperator)
   If $seperatorPos > 0 Then
	  $current = StringLeft($path, $seperatorPos - 1)
	  $next = StringTrimLeft($path, $seperatorPos + StringLen($seperator) - 1)
   Else
	  $current = $path
	  $next = ""
   EndIf

   If _JSONIsObject($json) Then
	  $l = UBound($json, 1)
	  For $i = 0 To $l - 1
		 If $json[$i][0] == $current Then
			If $next == "" Then
			   return $json[$i][1]
			Else
			   return _JSONGet($json[$i][1], $next, $seperator)
			EndIf
		 EndIf
	  Next
   ElseIf IsArray($json) And UBound($json, 0) == 1 And UBound($json, 1) > $current Then
	  If $next == "" Then
		 return $json[$current]
	  Else
		 return _JSONGet($json[$current], $next, $seperator)
	  EndIf
   EndIf
   return $_JSONNull
EndFunc

Func _JSONSet($writeValue, ByRef $json, $path, $seperator = ".")
    Local $seperatorPos, $current, $next, $l
    $seperatorPos = StringInStr($path, $seperator)

    If $seperatorPos > 0 Then
        $current = StringLeft($path, $seperatorPos - 1)
        $next = StringTrimLeft($path, $seperatorPos + StringLen($seperator) - 1)
    Else
        $current = $path
        $next = ""
    EndIf

    If _JSONIsObject($json) Then
        $l = UBound($json, 1)
        Local $matchFound = False
        For $i = 0 To $l - 1
            If $json[$i][0] == $current Then
                $matchFound = True
                If $next == "" Then
                    $json[$i][1] = $writeValue
                    Return
                Else
                    _JSONSet($writeValue, $json[$i][1], $next, $seperator)
                    Return
                EndIf
            EndIf
        Next
        If Not $matchFound Then
            ReDim $json[UBound($json)+1][2]
            If $next == "" Then
                $json[UBound($json)-1][0] = $current
                $json[UBound($json)-1][1] = $writeValue
            Else
                $json[UBound($json)-1][0] = $current
                Local $newjsonobject[1][2]
                $newjsonobject[0][0] =""
                $newjsonobject[0][1] ='JSONObject'
                $json[UBound($json)-1][1] = $newjsonobject
                _JSONSet($writeValue, $json[UBound($json)-1][1], $next, $seperator)
                Return
            EndIf
        EndIf
    ElseIf IsArray($json) And UBound($json, 0) == 1 Then
        If UBound($json, 1) > $current Then
            If $next == "" Then
                ;$json[$current]
                Return
            Else
                _JSONSet($writeValue, $json[$current], $next, $seperator)
                Return
            EndIf
        Else
            ReDim $json[$current+1]
            Local $newjsonobject[1][2]
            $newjsonobject[0][0] =""
            $newjsonobject[0][1] ='JSONObject'
            $json[$current] = $newjsonobject
            If $next == "" Then
                ;$json[$current]
                Return
            Else
                _JSONSet($writeValue, $json[$current], $next, $seperator)
                Return
            EndIf
        EndIf
    Else
        return $_JSONNull
    EndIf
EndFunc