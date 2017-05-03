#cs
$url = "http://mbgo.plu.cn/chatroom/sendmsg2?group=2185&content=%E6%95%99%E4%B8%BB%E5%9C%A8%E5%90%97&color=0xff0000&style=1&callback=_callbacks_._1djsf0zixn9e4gz"
$x = _HttpGet($url)
ConsoleWrite($x)
#ce

#include-once

Func _HttpGet($url, $timeout = 30)
	Local $oXmlHttp = ObjCreate("Microsoft.XMLHTTP")
	$oXmlHttp.Open("GET", $url , True)
	$oXmlHttp.Send()
	Local $i = $timeout * 4, $rtn = ""
	While($oXmlHttp.readyState <> 4 And $i > 0)
	  Sleep(250)
	  $i = $i - 1
	WEnd
	If($i > 0 And $oXmlHttp.readyState == 4) Then
		$rtn = $oXmlHttp.ResponseText
	EndIf
	$oXmlHttp = 0
	Return $rtn
EndFunc

Func _HttpPost($url, $data, $timeout = 30)
	Local $oXmlHttp = ObjCreate("Microsoft.XMLHTTP")
	$oXmlHttp.Open("POST", $url , True)
	$oXmlHttp.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
	$oXmlHttp.Send($data)
	Local $i = $timeout * 4, $rtn = ""
	While($oXmlHttp.readyState <> 4 And $i > 0)
	  Sleep(250)
	  $i = $i - 1
	WEnd
	If($i > 0 And $oXmlHttp.readyState == 4) Then
		$rtn = $oXmlHttp.ResponseText
	EndIf
	$oXmlHttp = 0
	Return $rtn
EndFunc

Func _HttpGetX($url, $timeout = 30, $refer = "", $cookie=" ")
	Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1") ;Microsoft.XMLHTTP
	$oHTTP.Open("GET", $url , False)
	$oHTTP.SetTimeouts (60000, 60000, $timeout * 1000, $timeout * 1000)
	$oHTTP.SetRequestHeader("Referer", $refer)
	$oHTTP.SetRequestHeader("Cookie", $cookie)
	$oHTTP.Send()
	If $oHTTP.Status <> 200 Then Return ""
	Local $rtn = $oHTTP.ResponseText
	$oHTTP = 0
	Return $rtn
EndFunc

Func _HttpPostX($url, $data, $timeout = 30, $refer = "", $cookie=" ")
	Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")
	$oHTTP.Open("POST", $url , False)
	$oHTTP.SetTimeouts (60000, 60000, $timeout * 1000, $timeout * 1000)
	$oHTTP.SetRequestHeader("Referer", $refer)
	$oHTTP.SetRequestHeader("Cookie", $cookie)
	$oHTTP.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
	$oHTTP.Send($data)
	If $oHTTP.Status <> 200 Then Return ""
	Local $rtn = $oHTTP.ResponseText
	$oHTTP = 0
	Return $rtn
EndFunc


;ConsoleWrite(_urlDecode(_urlEncode("§∏°Óvê€æy©YL")) & @CRLF)
Func _EncodeURL($str, $plus = True)
    Local $i, $return, $tmp, $exp
    $return = ""
    $exp = "[a-zA-Z0-9-._~]"
    If $plus Then
        $str = StringReplace ($str, " ", "+")
        $exp = "[a-zA-Z0-9-._~+]"
    EndIf
    For $i = 1 To StringLen($str)
        $tmp = StringMid($str, $i, 1)
        If StringRegExp($tmp, $exp, 0) = 1 Then
            $return &= $tmp
        Else
            $return &= StringMid(StringRegExpReplace(StringToBinary($tmp, 4), "([0-9A-Fa-f]{2})", "%$1"), 3)
        EndIf
    Next
    Return $return
EndFunc

Func _DecodeURL($str)
    Local $i, $return, $tmp
    $return = ""
    $str = StringReplace ($str, "+", " ")
    For $i = 1 To StringLen($str)
        $tmp = StringMid($str, $i, 3)
        If StringRegExp($tmp, "%[0-9A-Fa-f]{2}", 0) = 1 Then
            $i += 2
            While StringRegExp(StringMid($str, $i+1, 3), "%[0-9A-Fa-f]{2}", 0) = 1
                $tmp = $tmp & StringMid($str, $i+2, 2)
                $i += 3
            Wend
            $return &= BinaryToString(StringRegExpReplace($tmp, "%([0-9A-Fa-f]*)", "0x$1"), 4)
        Else
            $return &= StringMid($str, $i, 1)
        EndIf
    Next
    Return $return
EndFunc
