#include-once
#include <WindowsConstants.au3>
#include <SendMessage.au3>

Const $g_infoWinTitle = "Live information"
Const $g_exe = "subtitle.exe"
Const $tagCOPYDATASTRUCT = "ulong_ptr dwData;dword cbData;ptr lpData"
Local $infoPosStyle = 6; 1 top-left; 2 top-center; 3 top-right; 4 bottom-left; 5 bottom-center; 6 bottom-right; 7 middle-right

#cs
_ShowInfoWindow("@8Œª÷√≤‚1 ‘")
#ce

Func _ShowInfoWindow($msg)
   Local $hWnd = WinGetHandle($g_infoWinTitle)
   If(@error <> 0) Then
	  Run (@ScriptDir & "\" & $g_exe & " """ & $msg & """")
	  Sleep(1000)
	  WinSetOnTop($hWnd, "", 1)
	  Return
   EndIf
   ;ControlSetText($hWnd, "", "Static1", $msg)
   _SendData($hWnd, $msg)
   WinSetOnTop($hWnd, "", 1)
EndFunc
Func _SendData ($hWnd, $Data)
   $Data = StringToBinary($Data)
   Local $len = StringLen($Data)
   Local $pData = DllStructCreate("char[" & $len & "]")
   DllStructSetData($pData, 1, $Data)
   Local $stCOPYDATASTRUCT = DllStructCreate($tagCOPYDATASTRUCT)
   DllStructSetData($stCOPYDATASTRUCT, 1, 0)
   DllStructSetData($stCOPYDATASTRUCT, 2, $len)
   DllStructSetData($stCOPYDATASTRUCT, 3, DllStructGetPtr($pData))
   _SendMessage($hWnd, $WM_COPYDATA, 0, DllStructGetPtr($stCOPYDATASTRUCT))
   $stCOPYDATASTRUCT = 0
EndFunc
