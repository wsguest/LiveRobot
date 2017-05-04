#include <ScreenCapture.au3>

#cs
While(True)
   Sleep(5000);
   Local $p = IsPlayingGame();
   ConsoleWrite(_NowCalc() & " Playing: " & $p & @CRLF)
WEnd
#ce

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