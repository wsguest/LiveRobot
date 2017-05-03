#include-once
#include "JSON.au3"
#include <Date.au3>
#include <Array.au3>
#include <ScreenCapture.au3>
#include "onlineClient.au3"
#include "config.au3"

;;push stream to url
;livestreamer -O -v afreeca.com/sblyh119 best | ffmpeg -i - -c:a libvo_aacenc -ab 64k -ar 44100 -c:v libx264 -f flv rtmp://pub.bogou.tv/cclive/********
;--plugins-dir " & @ScriptDir & "
;player="C:\Program Files\VideoLAN\VLC\vlc.exe" --file-caching=10000  --network-caching=10000 --audio-desync '-200'  --fullscreen
Const $streamerCmd = "livestreamer.exe --retry-open 2 --hls-live-edge 10 --hls-segment-attempts 60 --hls-segment-threads 10" & _
		" --hls-segment-timeout 2 --hls-timeout 60 --ringbuffer-size 32M afreeca.com/%s best"
Const $streamerRecordCmd = "livestreamer.exe --retry-open 5 star.longzhu.com/%s best -f -o %s"
Local $streamerRecordId = 0
Local $streamerId = 0
Const $vlcExe = "vlc.exe"
Const $vlcTitle = "fd://0 - VLC media player"
Local $vlcId = 0
;在线选手设置

Global $g_currentPlayer="failed ";正在播放的选手
Local $broadcastStatus = "normal "
Local $allPlayers;所有选手数据
;关闭之前的窗口
WinClose($vlcTitle)
ProcessClose($vlcExe)
;加载选手名单
_LoadPlayers()

;_BroadcastAnyPlayer()
;_Broadcast("冠军")
;Sleep(5000)
;_Broadcast("pusan大叔")
;_AddBnid("bisu", "1102")
;;_DebugOut(_GetPayerIdByName("小激动killer"))
;;_DebugOut( _GetNameByBnid("hong"))
;_ArrayDisplay(_GetOnlinePlayers(True))
#cs
While(True)
   Sleep(5000);
   Local $p = IsPlayingGame();
   ConsoleWrite(_NowCalc() & " Playing: " & $p & @CRLF)
WEnd
#ce
Func _LoadPlayers()
	Local $allData = _JSONDecode(FileRead($g_PlayersFile))
	$allPlayers = _JSONGet($allData, "players")
	;_DebugOut("player list loaded")
	$allData = 0
EndFunc
Func _SavePlayers()
	Local $jsonText = _JSONEncode($allPlayers, '', @TAB)
	$jsonText = '{"players":' & @CRLF & $jsonText & @CRLF & '}'
	Local $ph = FileOpen($g_PlayersFile, $FO_OVERWRITE)
	FileWrite($ph, $jsonText)
	FileClose($ph)
EndFunc

Func _UpdatePlayers($forceUpdate = False)
	Static $UpdateTime = _NowCalc()
	If((Not $forceUpdate) And _DateDiff("s", $UpdateTime, _NowCalc()) < 300) Then Return;300秒内不再更新
	_UpdatePlayersStatus($allPlayers)
	$UpdateTime = _NowCalc()
EndFunc

Func _GetOnlinePlayersX($force = False)
	_UpdatePlayers($force)
	Local $onlinePlayers[1]
	$onlinePlayers[0] = 0 ;number
	Local $i
	For $i=0 to UBound($allPlayers) - 1
		Local $broadNo = _JSONGet($allPlayers[$i], "broadNo")
		;_ArrayDisplay($allPlayers[$i])
		;ConsoleWrite("bn:" & $broadNo & @CRLF)
		If($broadNo <> 0 And $broadNo <> Default) Then
			Local $name = _JSONGet($allPlayers[$i], "name")
			_ArrayAdd($onlinePlayers, $name)
			$onlinePlayers[0] += 1
		EndIf
	Next
	Return $onlinePlayers
EndFunc

Func _IsPlayerName(Byref $playerName, $checkOnline = False)
	If(StringLen($playerName) < 2) Then Return False
	If(StringLeft($playerName, 1) == "/") Then Return True
	Local $i
	For $i=0 to UBound($allPlayers) - 1
		Local $name = _JSONGet($allPlayers[$i], "name")
		if(StringInStr($name, $playerName) > 0) Then
			$playerName = $name
			If(Not $checkOnline) Then
				Return True
			Else
				Local $id = _JSONGet($allPlayers[$i], "id")
				Return _IsOnline($id)
			EndIf
		EndIf
	Next
	Return False
EndFunc

Func _GetPlayerIdByName($playerName)
	$playerName = StringStripWS($playerName, 1+2)
	If(StringLeft($playerName, 1) == "/") Then  Return StringMid($playerName, 2)
	Local $i
	For $i=0 to UBound($allPlayers) - 1
		Local $name = _JSONGet($allPlayers[$i], "name")
		if(StringCompare($name, $playerName) == 0) Then
			Local $id = _JSONGet($allPlayers[$i], "id")
			Return $id
		EndIf
	Next
	Return ""
EndFunc

Func _GetNameByBnid($bnid)
	Local $i, $j, $names = "  ";for last trim 2
	$bnid = StringStripWS($bnid, 1+2)
	For $i=0 to UBound($allPlayers) - 1
		Local $bnids = _JSONGet($allPlayers[$i], "bnid")
		For $j = 0 to UBound($bnids) - 1
			Local $bid = $bnids[$j]
			if(StringInStr($bid, $bnid) > 0) Then
				Local $name = _JSONGet($allPlayers[$i], "name")
				$names = $names & $name & "(" & $bid & "), "
			EndIf
		Next
	Next
	Return StringTrimRight($names, 2)
EndFunc

Func _AddBnid($playerName, $bnid)
	If( Not _IsPlayerName($playerName)) Then Return
	$bnid = StringStripWS($bnid, 1+2)
	If(StringLen($bnid) < 1) Then Return

	Local $i, $j, $names = "  ";for last trim 2

	For $i= 0 to UBound($allPlayers) - 1
		Local $name = _JSONGet($allPlayers[$i], "name")
		If(StringCompare($name, $playerName) <> 0) Then ContinueLoop ; find the player
		Local $bnids = _JSONGet($allPlayers[$i], "bnid")
		For $j = 0 to UBound($bnids) - 1
			Local $bid = $bnids[$j]
			If(StringCompare($bid, $bnid) == 0) Then Return ; exists
		Next
		_ArrayAdd($bnids, $bnid)
		_JSONSet($bnids, $allPlayers,  $i & ".bnid")
		_SavePlayers()
		ExitLoop
	Next
EndFunc

Func _IsOnline($playerId)
	Local $broadNo = _GetBroadNo($playerId)
	Return $broadNo <> 0
EndFunc
;播放某个选手，总计等待时间在90秒以内，检测失败应该至少90秒
; -1=error name, -2=error Id, -3=not online, -4=run failed, -5=player not fullscreen
Func _Broadcast($playerName, $force = False)
	If(StringLen($playerName) < 1) Then Return -1
	;强制结束
	if((Not $force) And ($g_currentPlayer == $playerName) And ProcessExists($vlcId)) Then
		Return 3
	ElseIf(_IsBroadcasting()) Then
		Return 2
	EndIf

	;如果以/打头则直接切换
	Local $playerId = _GetPlayerIdByName($playerName)
	If($playerId == "") Then Return -2
	If(_IsOnline($playerId) ==  False) Then Return -3;

	;start streamer, when success, player(vlc, mpc) will be opened
	Local $new_streamerId = 0
	Local $orgProcList = ProcessList($vlcExe); for check new player process
	$broadcastStatus = "starting " & $playerName
	Local $cmd = StringFormat($streamerCmd, $playerId)
	$new_streamerId = Run($cmd, "", @SW_HIDE)
	If($new_streamerId == 0) Then
		$broadcastStatus = "failed " & $playerName
		Return -4
	EndIf
	;wait new player window
	Local $new_vlcId = 0, $maxWaitTime = 240
	Do
		Sleep(250)
		Local $procList = ProcessList($vlcExe)
		For $i = 1 To $procList[0][0]
			Local $pId = $procList[$i][1], $j
			For $j = 1 To $orgProcList[0][0]
				If($pId == $orgProcList[$j][1]) Then ExitLoop
			Next
			If($j > $orgProcList[0][0]) Then
				$new_vlcId = $pId
				ExitLoop ; $i
			EndIf
		Next
		$orgProcList = $procList; update last list
		$maxWaitTime -= 1
	Until ($new_vlcId <> 0) Or (Not ProcessExists($new_streamerId)) Or ($maxWaitTime < 1)
	If($new_vlcId == 0) Then ; streamer exit or wait timeout
		$broadcastStatus = "failed " & $playerName
		ProcessClose($new_streamerId);close streamer
		Return -5
	EndIf
	;close old vlc, old streamer will be closed automatically
	ProcessClose($streamerId)
	ProcessClose($vlcId)
	; record new process info
	$vlcId = $new_vlcId
	$streamerId = $new_streamerId
	$g_currentPlayer = $playerName
	SetRoomConfig("LastPlayer", $g_currentPlayer)
	$broadcastStatus = "normal " & $playerName
	;#cs
	;fullscreen
	Local $maxWaitFullScreen = 10, $s = 1, $hv = WinGetHandle($vlcTitle)
	SendKeepActive($hv)
	Do
		;send("!{alt}")
		;send("f")
		Sleep(1000)
		Local $aStyle = DllCall("user32.dll", "long", "GetWindowLong", "hwnd", $hv, "int", -16)
		$s = BitAnd($aStyle[0], 0x40000)
		$maxWaitFullScreen -= 1
	Until ($s == 0) Or ($maxWaitFullScreen < 1)
	if($maxWaitFullScreen < 1 and $s <> 0) Then ;10秒之内没搞定再等5s
		Sleep(5000)
		;send("!{alt}")
		;send("f")
	EndIf
	SendKeepActive("")
	;#ce
	Return 1
EndFunc

Func _IsBroadcastFailed()
	Return (StringInStr($broadcastStatus, "failed") > 0)
EndFunc
Func _IsBroadcasting()
	Return (StringInStr($broadcastStatus, "starting") > 0)
EndFunc
Func _CheckBroadcastStatus($periodSecond)
	If _IsBroadcasting() Then Return True
	If _IsBroadcastFailed() Then Return False
	If(Not ProcessExists($streamerId)) Then Return False
	If(Not ProcessExists($vlcId)) Then Return False
	Return True
EndFunc

Func _BroadcastAnyPlayer()
	;上一选手优先
	if(StringLen($g_currentPlayer) < 1) Then $g_currentPlayer = GetRoomConfig("LastPlayer")
	If(_Broadcast($g_currentPlayer, True) > 0) Then Return
	_UpdatePlayersStatus($allPlayers)
	Local $i
	;从头开始试着播放
	For $i=0 to UBound($allPlayers) - 1
		Local $broadNo = _JSONGet($allPlayers[$i], "broadNo")
		Local $name = _JSONGet($allPlayers[$i], "name")
		If ($broadNo <> 0 And $broadNo <> Default) Then
			if (_Broadcast($name, True) > 0) Then ExitLoop
		Endif
	Next
EndFunc

Func StartRecord($domain, $filePath)
	If(ProcessExists($streamerRecordId)) Then Return Return True
	Local $cmd = StringFormat($streamerRecordCmd, $domain, $filePath)
	$streamerRecordId = Run($cmd, "", @SW_HIDE)
	Sleep(3000)
	If(ProcessExists($streamerRecordId)) Then
		Return True
	Else
		Return False
	EndIf
EndFunc

Func StopRecord()
	ProcessClose($streamerRecordId)
EndFunc

;1280x760 16:9 support
Func IsPlayingGame($threshold = 80, $any = True)
   Local $hwnd = WinGetHandle($vlcTitle)
   if(@error) Then Return False

   Local $path = @ScriptDir & "\cv\"
   Local $file = $path & "screen.png"
   Local $template = $path & "template"
   Local $checker =  $path & "TemplateMatch.exe"
   Local $marginLeft = 4
   Local $marginRight = 160
   Local $marginTop = 0
   Local $marginBottom = 0
   Local $apos = WinGetPos($vlcTitle)
   Local $videoWidth = $apos[2]; @DesktopWidth - $marginLeft - $marginRight; 800
   Local $videoHeight = $apos[3];@DesktopHeight - $marginTop - $marginBottom; 600
   Local $left = $apos[0] + $marginLeft
   Local $top = Ceiling($videoHeight * 12.5 / 20 + $apos[1] + $marginTop)
   Local $right = Ceiling($videoWidth * 7 / 20 + $left - 1)
   Local $bottom = Floor($videoHeight * 2 / 20 + $top - 1)

	_ScreenCapture_Capture($file, $left, $top, $right, $bottom)
	For $i = 0 To 3
		Local $rtn = RunWait($checker & " """ & $template & $i & ".png"" """ & $file & """", "", @SW_HIDE)
		ConsoleWrite(" T" & $i & ":" & $rtn & " -> ")
		If($any) Then
			if (Int($rtn) > $threshold) Then
				Return True
			EndIf
		Else
			if (Int($rtn) < $threshold) Then
				Return False
			EndIf
		EndIf
	Next
	Return (Not $any)
EndFunc