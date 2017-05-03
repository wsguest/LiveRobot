Local $vlcExe = "notepad.exe"
Local $orgProcList = ProcessList($vlcExe)
Do
	Local $procList = ProcessList($vlcExe)
	For $i = 1 To $procList[0][0]
		Local $pId = $procList[$i][1], $j
		For $j = 1 To $orgProcList[0][0]
			If($pId == $orgProcList[$j][1]) Then ExitLoop
		Next 
		If($j > $orgProcList[0][0]) Then 
			MsgBox(16, "", $pId)
			ExitLoop
		EndIf
	Next
	$orgProcList = $procList
	Sleep(1000)
Until False