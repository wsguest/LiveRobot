#include-once
Opt('MustDeclareVars', 1)
#include "JSON.au3"
#include "http.au3"
Const $chatUrl = "http://www.tuling123.com/openapi/api?key=%s&userid=%s&info=%s"

;_DebugSetup("plu",False, 2, "", True)
;ConsoleWrite(StringRegExpReplace(GetAnswer("½²¸öÐ¦»°"), "<.+>", ""))

Func GetAnswer($question, $userid = 0, $key="")
	Local $url = StringFormat( $chatUrl, $key, $userid, _EncodeURL($question))
    Local $rtn = _HttpGet($url)
   If $rtn = "" Then
		Return Default
    EndIf
   ;_DebugOut($rtn)
   Local $objRtn = _JSONDecode($rtn)
   if(Not _JSONIsObject($objRtn)) Then
	  Return Default
   Else
	  Local $code = _JSONGet($objRtn, "code")
	  Switch $code
	  Case 100000
		 Return _JSONGet($objRtn, "text")
	  Case 200000
		  Return _JSONGet($objRtn, "text") & ":" & _JSONGet($objRtn, "url")
	  Case 301000
		  Return _JSONGet($objRtn, "text") & ":" & _JSONGet($objRtn, "list.0.detailurl")
	  Case 304000
		  Return _JSONGet($objRtn, "text") & "µØÖ·:" & _JSONGet($objRtn, "list.0.detailurl")
	  EndSwitch
	  Return Default
   EndIf
EndFunc

;replace {i} in answer with $values[i]
Func FormatAnswer($answer, $p1 = 0, $p2=0, $p3=0, $p4 = 0, $p5=0, $p6=0)
   if(@NumParams < 2) Then
	  Return $answer
   EndIf

   Local $index
   For $index = 1 to @NumParams
	  $answer = StringReplace($answer, "{" & $index & "}", Eval("p" & $index))
   Next
   Return StringRegExpReplace($answer, "<.+>", " ")
EndFunc