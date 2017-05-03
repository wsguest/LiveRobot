#include-once
Opt('MustDeclareVars', 1)
#include "wmplayer.au3"
#include "json.au3"
#include "http.au3"
Global $gttsUrl[2];
$gttsUrl[0] = "http://translate.google.cn/translate_tts?ie=UTF-8&tl=zh-CN&total=1&idx=%d&tk=%s&client=t&textlen=%d&q=%s"
$gttsUrl[1] = "http://tsn.baidu.com/text2audio?lan=zh&cuid=6373090&ctp=1&per=%d&tok=%s&texlen=%d&tex=%s"
Global $g_Speech 

#cs
Speak("测试语音，正在播放bisu") ;google
While(_wmpgetvalue($g_Speech, "playstate") <> 1)
	;ConsoleWrite(_wmpgetvalue($g_Speech, "playstate") & @CR)
   Sleep(500)
WEnd
Speak("你好世界", 1, 0) ;baidu
Sleep(3000)
While(_wmpgetvalue($g_Speech, "playstate") <> 1)
	;ConsoleWrite(_wmpgetvalue($g_Speech, "playstate") & @CR)
   Sleep(500)
WEnd
#ce

Func Speak($strText, $engine = 0, $role = 0)
   if(StringLen($strText) < 2) Then
	  Return
   EndIf
   if(Not IsObj($g_Speech)) Then
	  $g_Speech = _wmpcreate()
   EndIf
   Local $token = 121966
   If($engine ==  1) Then $token = _getBaiduToken()
   Local $url = StringFormat($gttsUrl[$engine], $role, $token, StringLen($strText), _EncodeURL($strText) & _TL($strText))
   ;ConsoleWrite($url & @CR)
   _wmploadmedia($g_Speech, $url)
EndFunc

Func _getBaiduToken()
	Local $aurl = "https://openapi.baidu.com/oauth/2.0/token?grant_type=client_credentials&client_id=6c53ffkwfWNkHUkUbaKAb7KK&client_secret=MwWOLQXbVvysa7YnoQy58SuceCSIGqb7"
	Local $rtnJson = _HttpGet($aurl)
	Local $info = _JSONDecode($rtnJson)
	If (Not _JSONIsObject($info)) Then
		Return ""
	EndIf
	Local $token = _JSONGet($info, "access_token")
	Return $token;
EndFunc
Func _RL($a, $b)
	For $c= 0 To StringLen($b)-3 Step 3
		Local $d = StringMid($b, $c+3, 1)
		Local $d2 = StringMid($b, $c+2, 1)
		Local $d1 = StringMid($b, $c+1, 1)
		$d = (StringCompare($d, "a")>=0) ? AscW($d) - 87 : Number($d)
		$d = (StringCompare($d2, "+") == 0) ? _BitShift($a, $d) : BitShift($a, -$d)
		$a = (StringCompare($d1, "+") == 0) ? BitAND($a + $d, 4294967295) : BitXOR($a, $d)
	Next
	Return $a
EndFunc

Func _BitShift($iNum, $iShift)
    If ($iShift <= -32) Or ($iShift >= 32) Then Return SetError(1, 0, $iNum)
    If $iShift = 0 Then Return $iNum
    If $iShift < 0 Then
        Return BitShift($iNum, $iShift)
    Else
        If $iNum < 0 Or $iNum > 2147483647 Then Return BitOR(BitShift(BitAND($iNum, 0x7FFFFFFF), $iShift), 2 ^ (31 - $iShift)) ;<--- modified
    EndIf
    Return BitShift($iNum, $iShift)
EndFunc

Func _TL($a)
	Dim $d[1]
	Local $e = 0
	Local $b = 406419
	Local $c = 37275125
	Local $l = StringLen($a)
	For $f = 1 To $l
		Local $g = AscW(StringMid($a, $f, 1))
		If($g < 128) Then
			$d[$e] = $g
		ElseIf($g < 2048) Then
			$d[$e] = BitOR(BitShift($g, 6), 192)
		ElseIf (BitAND($g, 64512) == 55296) And $f < $l And (BitAND(AscW(StringMid($a, $f+1, 1)), 64512) == 56320) Then
			$f = $f + 1
			$g = 65536 + BitShift(BitAND($g, 1023), -10) + BitAND(AscW(StringMid($a, $f, 1)), 1023)
			$d[$e] = BitOR(BitShift($g, 18), 240)
			$e = $e + 1
			ReDim $d[$e + 1]
			$d[$e] = BitOR(BitAND( BitShift($g, 12), 63), 128)
		Else
			$d[$e] = BitOR(BitShift($g, 12), 224)
			$e = $e + 1
			ReDim $d[$e + 1]
			$d[$e] = BitOR(BitAND(BitShift($g, 6), 63), 128)
			$e = $e + 1
			ReDim $d[$e + 1]
			$d[$e] = BitOR(BitAND($g, 63), 128)
		EndIf
		$e = $e + 1
		ReDim $d[$e + 1]
	Next
	Local $aa = $b
	For $e = 0 To UBound($d) - 2
		$aa = $aa + $d[$e]
		$aa = _RL($aa,"+-a^+6")
	Next
	$aa = _RL($aa, "+-3^+b+-f")
	$aa = BitXOR($aa, $c)
	If($aa < 0) Then $aa = BitAND($aa, 2147483647) + 2147483648;
	$aa = Mod($aa, 1E6)
	Return "&tk=" & $aa & "." & BitXOR($aa, $b)
EndFunc

