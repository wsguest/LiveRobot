#Region ;**** 由 AccAu3Wrapper_GUI 创建指令 ****
#AccAu3Wrapper_Icon=icons\win.ico
#AccAu3Wrapper_OutFile=Subtitle.exe
#AccAu3Wrapper_Res_Fileversion=1.0.3.2
#AccAu3Wrapper_Res_FileVersion_AutoIncrement=Y
#AccAu3Wrapper_Res_Language=2052
#AccAu3Wrapper_Res_requestedExecutionLevel=None
#EndRegion ;**** 由 AccAu3Wrapper_GUI 创建指令 ****
#include <Date.au3>
#include <Timers.au3>
#include <Array.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <ColorConstants.au3>
#include <FontConstants.au3>
#include <WinAPI.au3>
#include "subTitleClient.au3"
Opt('MustDeclareVars', 1)
Opt('TrayIconHide', 1)

Const $maxChars = 12; 12 chars in a line
Const $maxLine = 2 ;
Const $fontFamily = "微软雅黑" ;
Const $fontSize = @DesktopHeight / 30
Const $charWidth = Ceiling($fontSize * 1.4)
Const $charHeight = Ceiling($fontSize * 1.8)
Const $maxWidth = $maxChars * $charWidth
Const $maxHeight = $maxLine * $charHeight

Local $width = $maxWidth
Local $height = $maxHeight
Local $left = @DesktopWidth - $width
Local $top = @DesktopHeight - $height ;- 2

Local $hGUI = 0
Local $hInfo = 0
Local $exit = False
Local $info = $g_infoWinTitle

If($CmdLine[0] > 0) Then
   $info = $CmdLine[1]
EndIf

HotKeySet("{ESC}", "Terminate")
GUIRegisterMsg($WM_COPYDATA, "OnMsgCopyData")
WinClose($g_infoWinTitle)
Main($info)

Func Main($text)
   _UpdatePos($infoPosStyle)
   $hGUI = GUICreate($g_infoWinTitle, $width, $height, $left, $top, $WS_POPUP, BitOR($WS_EX_TOPMOST , $WS_EX_TOOLWINDOW))
   ;WinSetTrans($hGUI, "", 200)
   GUISetBkColor($COLOR_BLACK)
   ;_WinAPI_SetLayeredWindowAttributes($hGUI, $COLOR_BLACK, 0, $LWA_COLORKEY); 透明
   Local $timer = _Timer_SetTimer($hGUI, 30000, "_AdjustWindow") ; create timer
   $hInfo = GUICtrlCreateLabel("", 1, 1, $width-2, $height-2, $SS_CENTER, $WS_EX_TRANSPARENT)
   GUICtrlSetColor($hInfo, $COLOR_LIME)
   GUICtrlSetFont($hInfo, $fontSize, $FW_MEDIUM, 0, $fontFamily)
   GUICtrlSetData($hInfo, $text)
   _AdjustWindow($hGUI, 0, 0, 0)
   GUISetState(@SW_Show)
   While (Not $exit)
	  Local $msg = GUIGetMsg()
	  Select
	  Case ($msg == 0)
		 DllCall("user32.dll", "int", "WaitMessage")
	  Case ($msg == $GUI_EVENT_CLOSE)
		 ExitLoop
	  EndSelect
   WEnd
   _Timer_KillTimer($hGUI, $timer)
   GUIRegisterMsg($WM_COPYDATA, "")
   GUIDelete($hGUI)
EndFunc

Func _AdjustWindow($hWnd, $Msg, $iIDTimer, $dwTime)
   #forceref $hWnd, $Msg, $iIDTimer, $dwTime
   Local $text = ControlGetText($hWnd, "", $hInfo)
   Local $len = _StringLenW($text)
   If($len < 1) Then
	  Return
   EndIf
   if(StringLower($text) == "hide") Then
	  _WinAPI_ShowWindow($hWnd, @SW_HIDE)
	  Return
   EndIf
   if(StringLower($text) == "close" Or StringLower($text) == "exit") Then
	  Terminate()
	  Return
   EndIf
   Local $newWidth, $newHeight
   Local $lineNum = Floor(($len - 1) / $maxChars + 1)
   If($lineNum > $maxLine) Then
	  $lineNum = $maxLine;
   EndIf
   GUICtrlSetFont($hInfo, $fontSize, $FW_MEDIUM, 0, $fontFamily)
   $newHeight = ($maxHeight / $maxLine) * $lineNum
   $newWidth = $len * $charWidth
   If($newWidth > $maxWidth) Then
	  $newWidth = $maxWidth
	  ;GUICtrlSetFont($hInfo, Ceiling($fontSize * 0.9), $FW_MEDIUM, 0, $fontFamily)
   ElseIf ($newWidth < $charWidth) Then
	  $newWidth = $charWidth
   EndIf
   ;ConsoleWrite("$newWidth:" & $newWidth & @CRLF)
   ;If($newWidth <> $width Or $newHeight <> $height) Then
	  $width = $newWidth
	  $height = $newHeight
	   _UpdatePos($infoPosStyle)
	  WinMove($hWnd, "", $left, $top, $width, $height)
	  GUICtrlSetPos($hInfo, 1, 1,$width-2, $height-2)
   ;EndIf
   _WinAPI_ShowWindow($hWnd, @SW_SHOW)
   WinSetOnTop($hWnd, "", 1)
EndFunc

Func OnMsgCopyData($hWnd, $Msg, $wParam, $lParam)
   #forceref $hWnd, $Msg, $wParam, $lParam
   Local $stCOPYDATASTRUCT = DllStructCreate($tagCOPYDATASTRUCT, $lParam)
   Local $len = DllStructGetData($stCOPYDATASTRUCT, 2)
   Local $pStr = DllStructGetData($stCOPYDATASTRUCT, 3)
   Local $str = DllStructCreate("char[" & $len & "]", $pStr)
   Local $text = DllStructGetData($str, 1)

   $text = BinaryToString($text)
   Local $pos = StringMid($text, 2, 1)
   If(StringLeft($text, 1) == "@" And StringIsDigit($pos)) Then
	  Local $s = int($pos)
	  if($s >= 1 and $s <= 7) Then
		 $text = StringMid($text, 3)
		 $infoPosStyle = $s
	  EndIf
   EndIf
   ControlSetText($hWnd, "", $hInfo, $text)
   _AdjustWindow($hGUI, 0, 0, 0)
EndFunc


Func Terminate()
   $exit = True
EndFunc

Func _StringLenW($str)
   Local $a = StringToASCIIArray($str)
   ;ConsoleWrite($str & @CRLF)
   Local $len = 0, $i
   For $i = 0 To UBound($a) - 1
	  ;ConsoleWrite("a" & $i  & ":" & $a[$i] & @CRLF)
	  $len += 0.5
	  If($a[$i] > 127) Then
		 $len += 0.5
	  EndIf
   Next
   Return Ceiling ($len)
EndFunc

Func _UpdatePos($style = 6)
   If($style < 4) Then
	  $top = 2
   ElseIf($style < 7) Then ; bottom
	  $top = @DesktopHeight - $height ;- 2
   Else; middle
	  $top = @DesktopHeight - 220;- $height
   EndIf
   Local $xstyle = Mod($style - 1, 3)
   If($xstyle == 0) Then
	  $left = 0
   ElseIf($xstyle == 1) Then
	  $left = Round((@DesktopWidth - $width) / 2)
   Else
	  $left = @DesktopWidth - $width
   EndIf
   If($style == 7) Then $left = @DesktopWidth - $width ;- 100
EndFunc
