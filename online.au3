#Region ;**** 由 AccAu3Wrapper_GUI 创建指令 ****
#AccAu3Wrapper_Icon=icons\win2.ico
#AccAu3Wrapper_Outfile=online.exe
#AccAu3Wrapper_UseX64=n
#AccAu3Wrapper_Res_Fileversion=2.0.1
#AccAu3Wrapper_Res_Language=2052
#AccAu3Wrapper_Res_requestedExecutionLevel=None
#EndRegion ;**** 由 AccAu3Wrapper_GUI 创建指令 ****
#include <Date.au3>
#include <Timers.au3>
#include<Array.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <ColorConstants.au3>
#include<FontConstants.au3>
#include <WinAPI.au3>
#include "onlineClient.au3"


Opt('MustDeclareVars', 1)
Opt('TrayIconHide', 1)

Const $LOGOPIC = "mp.jpg"

Const $LIST_TIMEOUT = 301234
Const $PREVIEW_TIMEOUT = 30000;15 secs
Const $SNAPSHOT_WIDTH = 240
Const $SNAPSHOT_HEIGHT = 180
Const $fontFamily = "微软雅黑" ;
Const $fontSize = 12
Const $listWidth = 160
Const $listLeft = @DesktopWidth - $listWidth - 0
Const $listTop = 0
Const $listHeight = @DesktopHeight - $listTop - 220

Local $hGUIList = 0
Local $hGUIView = 0
Local $hInfo = 0
Local $exit = False
Local $allPlayers = Default

Main()

Func Main()
	WinClose($OnlineTitle)
	HotKeySet("{ESC}", "Terminate")
	Local $msgId = _WinAPI_RegisterWindowMessage($MSG_UPDATE)
	GUIRegisterMsg($msgId, "__UpdateOnline"); update list
	$msgId = _WinAPI_RegisterWindowMessage($MSG_PREVIEW)
	GUIRegisterMsg($msgId, "__ShowPrivew"); Show Preview window
	__LoadPlayers()
	$hGUIList = __CreateOnlineUI($listWidth, $listHeight, $listLeft, $listTop)
	;$hGUIView = __CreatePreviewUI(@DesktopWidth , $listHeight)
	Do
		Local $msg = GUIGetMsg()
		Select
			Case ($msg == 0)
				DllCall("user32.dll", "int", "WaitMessage")
			Case ($msg == $GUI_EVENT_CLOSE)
				ExitLoop
		EndSelect
	Until $exit
	__DistroyOnlineUI($hGUIList)
	__DistroyOnlineUI($hGUIView)
EndFunc

Func Terminate()
   $exit = True
EndFunc

Func __LoadPlayers()
	Local $allData = _JSONDecode(FileRead($PLYAER_FILE))
	$allPlayers = _JSONGet($allData, "players")
	$allData = 0
EndFunc
;===========================================================================================================
;Online List
;===========================================================================================================
Func __CreateOnlineUI($width, $height, $left, $top)
	Local $hGUI = GUICreate($OnlineTitle, $width, $height, $left, $top, $WS_POPUP, BitOR($WS_EX_TOPMOST , $WS_EX_TOOLWINDOW))
	GUISetBkColor($COLOR_BLACK)
	;透明和半透明窗口不能被某些直播软件捕获
	;WinSetTrans($hGUI, "", 200) ;半透明
	;_WinAPI_SetLayeredWindowAttributes($hGUI, $COLOR_BLACK, 0, $LWA_COLORKEY); 透明
	Local $offsetY = 0
	If(FileExists($LOGOPIC)) Then
		GUICtrlCreatePic($LOGOPIC, 0, 0, $width, $width)
		$offsetY = $width
	EndIf
	$hInfo = GUICtrlCreateLabel("正在刷新在线列表...", 2, $offsetY, $width - 2, $height - $offsetY, $SS_LEFTNOWORDWRAP, $WS_EX_TRANSPARENT)
	GUICtrlSetColor(-1, 0xFF8000)
	GUICtrlSetFont(-1, $fontSize, $FW_MEDIUM, 0, $fontFamily)
	GUISetState(@SW_Show)
	__UpdateOnline($hGUI, 0, 0, 0)
	_Timer_SetTimer($hGUI, $LIST_TIMEOUT, "__UpdateOnline") ; create timer1 for Update List
	_Timer_SetTimer($hGUI, 7000, "__ScrollContent") ; create timer2 for scroll content
	Return $hGUI
EndFunc

Func __DistroyOnlineUI($hGUI)
	_Timer_KillAllTimers($hGUI)
   GUIDelete($hGUI)
EndFunc

Func __UpdateOnline($hWnd, $Msg, $iIDTimer, $dwTime)
	#forceref $hWnd, $Msg, $iIDTimer, $dwTime

	If($allPlayers == Default) Then
		GUICtrlSetData($hInfo, "数据未加载，重启再试")
		Return
	EndIf
	Local $text = ""
	Local  $i, $text= ""
	;GUICtrlSetData($hInfo, "正在刷新在线列表...")
	_UpdatePlayersStatus($allPlayers)
	For $i=0 to UBound($allPlayers) - 1
		Local $broadNo = _JSONGet($allPlayers[$i], "broadNo")
		;_ArrayDisplay($allPlayers[$i])
		;ConsoleWrite("bn:" & $broadNo & @CRLF)
		If($broadNo <> 0 And $broadNo <> Default) Then
			Local $name = _JSONGet($allPlayers[$i], "name")
			$text &= $name &  @CR
		EndIf
	Next
	$text &= " " & @CR

	GUICtrlSetData($hInfo, $text)
	WinSetOnTop($hWnd, "", 1)
EndFunc

Func __ScrollContent($hWnd, $Msg, $iIDTimer, $dwTime)
	#forceref $hWnd, $Msg, $iIDTimer, $dwTime

	Local $text = GUICtrlRead($hInfo)
	Local $players = StringSplit($text, @CR)
	;ConsoleWrite($text)
	;ConsoleWrite("cont:" & $players[0] )
	;WinSetOnTop($hWnd, "", 1)

	Local $aPos = ControlGetPos($hWnd, "", $hInfo)
	Local $maxLine = $aPos[3] / 22
	if($players[0] < $maxLine) Then Return
	$text = ""
	Local $sLine = $players[0] / 7
	If($sLine < 1) Then $sLine = 1

	For $i= $sLine + 1 to $players[0]
		$text &= $players[$i] &  @CR
	Next

	For $i = 1 To $sLine
		$text &= $players[$i] & @CR
	Next
	GUICtrlSetData($hInfo, $text)
EndFunc


;===========================================================================================================
;Preview
;===========================================================================================================

Func __CreatePreviewUI($width = @DesktopWidth, $height = @DesktopHeight, $left = 0, $top = 0)
	Local $hGUI = GUICreate($ViewTitle, $width, $height, $left, $top, $WS_POPUP, BitOR($WS_EX_TOPMOST , $WS_EX_TOOLWINDOW))
	GUISetBkColor($COLOR_WHITE)
	Local $itemLeft = 0, $itemTop = 0, $itemWidth = $SNAPSHOT_WIDTH, $itemHeight=$SNAPSHOT_HEIGHT
	Local $i, $maxRows, $maxCols
	$maxCols = Floor($width / ($itemWidth + 10))
	$maxRows = Ceiling($height / ($itemHeight + 10))
	For $i=0 to UBound($allPlayers) - 1
		Local $broadNo = _JSONGet($allPlayers[$i], "broadNo")
		If($broadNo <> 0 And $broadNo <> Default) Then
			Local $name = _JSONGet($allPlayers[$i], "name")
			Local $file = _DownloadSnapshot($name, $broadNo)
			__CreateViewItem($name, $file, $itemLeft, $itemTop, $itemWidth, $itemHeight)
			$itemLeft += ($itemWidth + 5)
			If($itemLeft + $itemWidth / 2 > $width) Then
				$itemLeft = 0
				$itemTop += ($itemHeight + 5)
				If($itemTop + 20 > $height) Then ExitLoop
			EndIf
		EndIf
	Next
	_Timer_SetTimer($hGUI, $PREVIEW_TIMEOUT, "__ClosePreview") ; create timer1 for Update List
	GUISetState(@SW_SHOW, $hGUI)
	Return $hGUI
EndFunc

Func __CreateViewItem($name, $file, $left, $top, $width, $height)
	GUICtrlCreatePic($file, $left, $top, $width, $height)
	GUICtrlCreateLabel($name, $left, $top, $width, 28, $SS_CENTER, $WS_EX_TRANSPARENT)
	GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
	GUICtrlSetColor(-1, 0xFF8000)
	GUICtrlSetFont(-1, 16, $FW_MEDIUM, 0, $fontFamily)
EndFunc

Func __ShowPrivew($hWnd, $iMsg, $wparam, $lparam)
	If(Not WinExists($ViewTitle)) Then
		Local $aPos = WinGetPos($OnlineTitle)
		Local $width = @DesktopWidth
		If(@error <> 1) Then $width -= $aPos[2];
		$hGUIView = __CreatePreviewUI($width , @DesktopHeight)
	EndIf
	GUISetState(@SW_SHOW, $hGUIView);
EndFunc

Func __ClosePreview($hWnd, $Msg, $iIDTimer, $dwTime)
	#forceref $hWnd, $Msg, $iIDTimer, $dwTime
	__DistroyOnlineUI($hGUIView)
EndFunc