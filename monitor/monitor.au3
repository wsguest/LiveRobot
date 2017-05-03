#Region ;**** 由 AccAu3Wrapper_GUI 创建指令 ****
#AccAu3Wrapper_Icon=..\icons\mon.ico
#AccAu3Wrapper_Outfile=monitor.exe
#AccAu3Wrapper_Outfile_x64=monitor_x64.exe
#AccAu3Wrapper_Compile_Both=y
#AccAu3Wrapper_Res_Fileversion=2.0.2.1
#AccAu3Wrapper_Res_Fileversion_AutoIncrement=p
#AccAu3Wrapper_Res_Language=2052
#AccAu3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#AccAu3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/sf=0 /sv=0
#EndRegion ;**** 由 AccAu3Wrapper_GUI 创建指令 ****
#include <Date.au3>
#include <Timers.au3>
#include <File.au3>
#include <TrayConstants.au3>
#include <Array.au3>
Opt('MustDeclareVars', 1)
Local $slaves[0]
Const $configFile = @ScriptDir & "/monitor.ini"

Main()

Func Main()
	LaunchSlaves()
	Local $hGUI = GUICreate("monitor", 100, 100)
	Local $timerInterval = IniRead($configFile, "monitor", "CheckSeconds", 5) * 1000
	Local $timer = _Timer_SetTimer($hGUI, $timerInterval, "CheckSlaves") ; create timer
	Local $trayOpen = TrayCreateItem(UBound($slaves) & "个应用")
	GUISetState(@SW_HIDE)
	While True
	  Local $msg = GUIGetMsg()
	  Select
	  Case ($msg == 0)
		 DllCall("user32.dll", "int", "WaitMessage")
	  Case ($msg == -3)
		 ExitLoop
	  EndSelect
	WEnd
	_Timer_KillTimer($hGUI, $timer)
	GUIDelete($hGUI)
EndFunc

Func CheckSlaves($hWnd, $Msg, $iIDTimer, $dwTime)
	#forceref $hWnd, $Msg, $iIDTimer, $dwTime
	Local $i
	For $i = 0 To UBound($slaves) - 1
		If(Not ProcessExists($slaves[$i])) Then
			$slaves[$i] = RunApp($i + 1)
		Endif
	Next
EndFunc
Func LaunchSlaves()
	Local $count = IniRead($configFile, "monitor", "SlaveCount", 0)
	;ConsoleWrite($count)
	If($count < 1) Then Return
	ReDim $slaves[$count]
	Local $i
	For $i = 0 To UBound($slaves) - 1
		$slaves[$i] = RunApp($i + 1)
		If($slaves[$i] = 0) Then
			MsgBox(16, "错误", "第[" & ($i + 1) & "]个应用启动失败，请配置正确路径。")
		EndIf
	Next
	;_ArrayDisplay($slaves)
EndFunc

Func RunApp($i)
	Local $sec = "Slave" & $i 
	Local $app = IniRead($configFile, $sec, "app", "")
	If($app == "") Then Return 0
	Local $cmd = IniRead($configFile, $sec, "cmd", 0)
	Local $wd = IniRead($configFile, $sec, "workdir", "")
	Local $show = IniRead($configFile, $sec, "show", 0)
	Local $show_flag = @SW_HIDE
	$app = StringReplace($app, "{NOW}", @YEAR&@MON&@MDAY&@HOUR&@MIN&@SEC)
	$app = StringReplace($app, "{RANDOM}", Random())
	If($cmd == 1) Then $app = @ComSpec & " /c " & $app
	If $show == 1 Then $show_flag = @SW_SHOW
	ConsoleWrite($app)
	Return Run($app, $wd, $show_flag)
EndFunc
