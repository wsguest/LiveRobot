#include "../onlineClient.au3"
#include "Array.au3"
;_ShowPreview()
;_ShowOnline(True)
;_UpdateOnline()
;Local $ps = _GetOnlinePlayers()
;_ArrayDisplay($ps)
;Local $x = _GetBroadNo("momo130")
;ConsoleWrite($x)
RestartLiveApp()

Func RestartLiveApp()
	Local $hWnd = WinGetHandle("嗨播")
	If @error <> 0 Then
		Run(@ProgramFilesDir & "\Haibo\hibo.exe")
		Sleep(50000)
	Endif
	WinActivate ($hWnd)
	WinSetState ($hWnd, "", @SW_RESTORE)
	;Return
	Sleep(500)
	;Send("{space}")
	;Sleep(500)
	Send("{enter}")
	Sleep(500)
	WinMove($hWnd, "", 0, 0)
	Sleep(500)
	MouseClick("left", 30, 538, 1, 0)
	Sleep(1000)
	WinSetState ($hWnd, "", @SW_MINIMIZE)
EndFunc
