
#include-once
#include <WinAPI.au3>
#include "json.au3"
; 窗口标题
Const $OnlineTitle = "Online List"
Const $ViewTitle = "Online View"
; 发送控制消息
Const $MSG_UPDATE = "UpdateOnline"
Const $MSG_PREVIEW = "Preview"
Const $PLYAER_FILE = @ScriptDir & "\players.js"
;Const $SNAPSHOT_PATH = @ScriptDir & "\images\"

Func _UpdateOnline()
	Local $hWnd = WinGetHandle($OnlineTitle)
	If @error <> 0 Then Return
	Local $WM_UPDATE = _WinAPI_RegisterWindowMessage($MSG_UPDATE)
	_WinAPI_PostMessage($hWnd, $WM_UPDATE, 0, 0)
EndFunc

Func _ShowOnline($show = True)
	Local $flag = @SW_SHOW
	If(Not $show) Then $flag = @SW_HIDE
	WinSetState($OnlineTitle, "", $flag)
	WinSetOnTop($OnlineTitle, "", $WINDOWS_ONTOP)
EndFunc

Func _GetOnlinePlayers()
	;返回第一个元素为数量，大于2个才处理，要去掉空白字符
	Local $text = ControlGetText($OnlineTitle, "", "[CLASS:Static; INSTANCE:2]")
	If($text == "") Then Return ""
	;ConsoleWrite($text)
	Local $players = StringSplit($text, @CR)
	Return $players
EndFunc

Func _ShowPreview($show = True)
	Local $hWnd = WinGetHandle($OnlineTitle)
	Local $p = 1
	If(Not $show) Then $p = 0
	Local $WM_PREVIEW = _WinAPI_RegisterWindowMessage($MSG_PREVIEW)
	_WinAPI_PostMessage($hWnd, $WM_PREVIEW, $p, 0)
EndFunc

Func _UpdatePlayersStatus(ByRef $playersArray)
	For $i=0 to UBound($playersArray) - 1
		Local $player = $playersArray[$i]
		Local $id = _JSONGet($player, "id")
		Local $broadNo = _GetBroadNo($id)
		_JSONSet($broadNo, $playersArray,  $i & ".broadNo")
	Next
EndFunc

Func _GetBroadNo($playerId)
; return 0 when offline
	Const $liveUrl = "http://sch.afreeca.com/api.php?m=liveSearch&v=1.0&szType=json&nListCnt=1&szKeyword="
	Local $broadNo = 0
	Local $oXmlHttp = ObjCreate("WinHttp.WinHttpRequest.5.1")
	$oXmlHttp.Open("GET", $liveUrl & $playerId, True)
	$oXmlHttp.Send()
	if($oXmlHttp.WaitForResponse(5)) Then; 5 secs timeout for each
		Local $rtn = $oXmlHttp.ResponseText
		;ConsoleWrite($rtn)
		Local $result = _JSONDecode($rtn)
		$broadNo = _JSONGet($result, "REAL_BROAD.0.broad_no")
		If($broadNo == Default) Then
			$broadNo = 0
		Else
			Local $id = _JSONGet($result, "REAL_BROAD.0.user_id")
			If($id == Default Or $id <> $playerId) Then $broadNo = 0
		EndIf
	Endif
	$oXmlHttp = 0
	Return $broadNo
 EndFunc

Func _GetBroadNo2($playerId)
	Const $livePostUrl = "http://live.afreecatv.com:8057/api/get_broad_state_list.php"
	Const $data = "uid=" & $playerId
	Const $referer = "http://www.afreeca.com/" & $playerId
	Local $broadNo = 0
	Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")
	$oHTTP.Open("POST", $livePostUrl , False)
	$oHTTP.SetTimeouts (60000, 60000, 5000, 5000)
	$oHTTP.SetRequestHeader("Referer", $referer)
	$oHTTP.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
	$oHTTP.Send($data)
	If $oHTTP.Status <> 200 Then Return $broadNo
	Local $rtn = $oHTTP.ResponseText
	Local $result = _JSONDecode($rtn)
	$broadNo = _JSONGet($result, "CHANNEL.BROAD_INFOS.0.list.0.nBroadNo")
	If($broadNo == Default Or $broadNo == "") Then
		$broadNo = 0
	Else
		Local $state = _JSONGet($result, "CHANNEL.BROAD_INFOS.0.list.0.nState")
		If($state == Default Or $state <> 1) Then $broadNo = 0
	EndIf
	$oHTTP = 0
	Return $broadNo
 EndFunc

Func _DownloadSnapshot($bjName, $broadNo)
	Local $file = @TempDir & $bjName & ".jpg"
	Local $url = "http://liveimg.afreecatv.co.kr/" & $broadNo & ".jpg"
	InetGet($url, $file, 1)
	Return $file
EndFunc