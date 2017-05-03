#include-once
Opt('MustDeclareVars', 1)
#include <File.au3>
#include "JSON.au3"
#include "http.au3"

Global $g_Debug = Not @Compiled
Global $g_logFile = @ScriptDir & "/live.log"
Global $g_configFile = @ScriptDir & "/live.ini"

Global $g_hostName, $g_hostId, $g_robotName, $g_robotKey, $g_roomId, $g_onlivingPlayer
Global $g_enableChat, $g_enableSpeech, $g_speechEngine, $g_enableBlock, $g_blockSeconds, $g_kickOut
Global $g_thankFlower,$g_thankGift,$g_flowerMsgTemplate,$g_giftMsgMsgTemplate, $g_responseGrade, $g_enableAutoLock
Global $g_UserRankList, $g_Gifts, $g_blockKeysFile, $g_PlayersFile
Global $g_Version = ""
Global $g_VodPath = @ScriptDir

Global $g_ErrorHandler = ObjEvent("AutoIt.Error", "LogCOMError")
Const $baseSection="Live"

LoadConfig()

Func LoadConfig()
	Local $iniFile = $g_configFile
	Const $urlPrefix="http://star.longzhu.com/"
	
	Local $room = IniRead($iniFile, $baseSection, "Room", "")
	If ($room == "") Then
		MsgBox(16, "", "配置文件出错，请修改配置文件填写直播间")
		Return False
	EndIf
	Local $roomSecion =  "Room_" & $room
	$g_roomId = IniRead($iniFile, $roomSecion, "RoomId", "")
	
	If($g_roomId == "") Then
		Local $roomUrl = $urlPrefix & $room
		Local $rtnHtml =_HttpGet($roomUrl)

		;"var roomInfo ="  "};" & @CR
		Local $signS = "var roomInfo ="
		Local $s = StringInStr($rtnHtml, $signS)
		If ($s < 1) Then
			MsgBox(16, "", "读取房间网页信息出错，或者版本不匹配")
			Exit
		EndIf
		;DebugOut($rtnHtml)
		Local $e = StringInStr($rtnHtml, "};", 0, 1, $s)
		
		If ($e < $s Or @error == 1) Then
			MsgBox(16, "", "读取房间网页信息出错，或者版本不匹配")
			Exit
		EndIf
		Local $json = StringMid($rtnHtml, $s + StringLen($signS), $e - $s - StringLen($signS) + 1)
		;$json = StringReplace($json, """", "'")
		;$json = StringReplace($json, "};", "}")
		;DebugOut($json)
		;DebugOut($rtnHtml)
		Local $config = _JSONDecode($json)
		If (Not _JSONIsObject($config)) Then
			MsgBox(16, "", "解析房间Json数据出错")
			Exit
		EndIf
		$g_hostName = _JSONGet($config, "Name")
		$g_hostId = _JSONGet($config, "UserId")
		$g_roomId = _JSONGet($config, "RoomId")
		;save
		IniWrite($iniFile, $roomSecion, "RoomId", $g_roomId)
		IniWrite($iniFile, $roomSecion, "HostId", $g_hostId)
		IniWrite($iniFile, $roomSecion, "HostName", $g_hostName)
	EndIf
	
	$g_robotName = IniRead($iniFile, $roomSecion, "RobotName", "")
	$g_robotKey = IniRead($iniFile, $roomSecion, "RobotKey", "")
	$g_enableChat =  IniRead($iniFile, $roomSecion, "EnableChat", 1)
	$g_responseGrade =  IniRead($iniFile, $roomSecion, "ResponseGrade", 1)
	$g_enableSpeech = IniRead($iniFile, $roomSecion, "EnableSpeech", 1)
	$g_speechEngine = IniRead($iniFile, $roomSecion, "SpeechEngine", 0)
	$g_enableBlock = IniRead($iniFile, $roomSecion, "EnableBlock", 1)
	$g_blockSeconds = IniRead($iniFile, $roomSecion, "BlockSeconds", 0)
	$g_kickOut = IniRead($iniFile, $roomSecion, "KickoutBlock", 0)
	$g_enableAutoLock = IniRead($iniFile, $roomSecion, "EnableAutoLock", 1)
	$g_thankFlower = IniRead($iniFile, $roomSecion, "FlowerThank", 1)
	$g_thankGift = IniRead($iniFile, $roomSecion, "GiftThank", 1)
	$g_flowerMsgTemplate = IniRead($iniFile, $roomSecion, "FlowerMsgTemplate", "")
	$g_giftMsgMsgTemplate = IniRead($iniFile, $roomSecion, "GiftMsgTemplate", "")
	$g_blockKeysFile = IniRead($iniFile, $roomSecion, "BlockKeysFile", "")
	$g_PlayersFile = IniRead($iniFile, $roomSecion, "PlayersFile", "")
	$g_VodPath = IniRead($iniFile, $roomSecion, "VodPath", @ScriptDir & "\vod\")
	$g_Version = FileGetVersion(@AutoItExe)
	;load gifts
	Local $giftAllUrl = "http://configapi.plu.cn/item/getallitems"
	Local $rtnJson =_HttpGet($giftAllUrl)
	;ConsoleWrite($rtnJson)
	$g_Gifts = _JSONDecode($rtnJson, "", True)
	Return True
EndFunc

Func GetRoomConfig($key)
	Local $room = IniRead($g_configFile, $baseSection, "Room", "")
	If ($room == "") Then
		Return ""
	EndIf
	Local $roomSecion =  "Room_" & $room
	Local $value = IniRead($g_configFile, $roomSecion, $key, "")
	Return $value
EndFunc

Func SetRoomConfig($key, $value)
	Local $room = IniRead($g_configFile, $baseSection, "Room", "")
	If ($room == "") Then
		Return ""
	EndIf
	Local $roomSecion =  "Room_" & $room
	IniWrite($g_configFile, $roomSecion, $key, $value)
EndFunc


Func LogMsg($strMsg)
	_FileWriteLog($g_logFile, $strMsg)
EndFunc

Func LogCOMError($oError)
	LogMsg(@ScriptName & " (" & $oError.scriptline & ") : ==> COM Error intercepted: 0x" & Hex($oError.number) & @CRLF & _
		@TAB & "windescription:" & @TAB & $oError.windescription & @CRLF & _
		@TAB & "description: " & @TAB & $oError.description & @CRLF & _
		@TAB & "source: " & @TAB & @TAB & $oError.source & @CRLF & _
		@TAB & "lastdllerror: " & @TAB & $oError.lastdllerror & @CRLF & _
		@TAB & "retcode: " & @TAB & "0x" & Hex($oError.retcode) & @CRLF & @CRLF)
EndFunc