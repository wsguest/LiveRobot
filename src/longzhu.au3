#Region ;**** 由 AccAu3Wrapper_GUI 创建指令 ****
#AccAu3Wrapper_Icon=./icons/icon.ico
#AccAu3Wrapper_OutFile=Longzhu.exe
#AccAu3Wrapper_Res_Fileversion=2.1.3.4
#AccAu3Wrapper_Res_FileVersion_AutoIncrement=Y
#AccAu3Wrapper_Res_Language=2052
#AccAu3Wrapper_Res_requestedExecutionLevel=None
#EndRegion ;**** 由 AccAu3Wrapper_GUI 创建指令 ****
#include-once
Opt('MustDeclareVars', 1)
#include "JSON.au3"
#include "http.au3"
#include "config.au3"
#include "music.au3"
#include "speech.au3"
#include "robot.au3"
#include "block.au3"
#include "streamer.au3"
#include "./cv/screenMatch.au3"
#include "subtitleClient.au3"
#include "onlineClient.au3"

;管理员列表
Global $g_Managers = Default
Global $g_Status = "Closed"
Global $g_lockPlayerExpired = _NowCalc(); 锁定选手时间，锁定期间不能换台

MainLoop()

Func MainLoop()

	;消息检查周期 3s
	Local $msgCheckPeriod = 5000
	;播放状态检查周期 30s
	Local $statusCheckPeriod = 10

	;从开始按顺序播放任意选手
	_BroadcastAnyPlayer()

	;主循环
	Do
		Sleep($msgCheckPeriod)
		If(Not _CheckBroadcastStatus($statusCheckPeriod)) Then
			_BroadcastAnyPlayer()
			_ShowInfoWindow($g_currentPlayer)
		EndIf
		_CheckRoomStatus()
		;_AutoBet()
		Local $msgs = GetMsgs()
		ParseMsgs($msgs)
	Until @error <> 0
	Exit(@error)
EndFunc

Func GetMsgs()
	Static $FromId = 0
	Const $getMsgUrl = "http://mb.tga.plu.cn/chatroom/msgs/"
	Local $rtn = _HttpGet($getMsgUrl & $g_roomId & "/" & $FromId & "/5/cb")
	;ConsoleWrite($rtn & @CR)
	if(StringLen($rtn) < 5) Then Return $_JSONNull

	$rtn = StringMid($rtn, 4)
	$rtn = StringTrimRight($rtn, 1)
	Local $result = _JSONDecode($rtn)
	IF(Not _JSONIsObject($result)) Then
		Return $_JSONNull
	Endif
	;$FromId = _JSONGet($result, "from")
	;添加校准
	Local $curTime = Int(_JSONGet($result, "from"))
	Local $NextSec = Int(_JSONGet($result, "next"))
	If($NextSec < 0 And $FromId == $curTime) Then
		$FromId = $curTime - $NextSec
		Return $_JSONNull
	EndIf
	$FromId = $curTime
	Return $result
EndFunc

Func ParseMsgs($msgs)
	if(_JSONIsNull($msgs)) Then
		Return
	EndIf
	Local $count = _JSONGet($msgs, "count")
	if(_JSONIsNull($count) Or $count < 1) Then
		Return
	EndIf

	Local $msgList = _JSONGet($msgs, "msgs")
	Local $i = 0
	For $i = 0 to $count -	1
		Local $msg = $msgList[$i]
		Local $type = _JSONGet($msg, "type")
		Local $userId = _JSONGet($msg, "msg.user.uid")
		Local $userName = _JSONGet($msg, "msg.user.username")
		Local $time = _JSONGet($msg, "msg.time")
		Local $tid=""
		Switch $type
		 Case "chat";聊天
			Local $content = _JSONGet($msg, "msg.content")
			;_DebugOut("chat: "	&	$userId & " " & $userName & " " & $content )
			Local $userType = "user"
			Local $userGrade = _JSONGet($msg, "msg.user.newGrade")
			if($userGrade < $g_responseGrade) Then ContinueLoop
			OnChatMsg($userId, $content, $userName, $userType)
		 Case "gift"; 礼物
			Local $gtype = _JSONGet($msg, "msg.itemType")
			Local $gnumber = _JSONGet($msg, "msg.number")
			;_DebugOut("gift: " &	$userId & " " & $userName & " " & $gtype & ":" & $gnumber )
			OnGiftMsg($userId, $userName, $gtype, $gnumber)
		 Case "hostjoin" ;有主播加入; {"type":"hostjoin","msg":{"userId":105259,"username":"s_k_911"}}
			$userName = _JSONGet($msg, "msg.username")
			OnHostJoin($userName)
		 Case "vipjoin" ;vip加入"msgs":[{"type":"vipjoin","msg":{"userId":983262,"username":"wsguest"}}]
			$userName = _JSONGet($msg, "msg.user.username")
			OnVIPJoin($userName)
		Case "redEnvelope" ;有人发红包
			;$userName = _JSONGet($msg, "msg.user.username")
			$tid = _JSONGet($msg, "redEnvelopeId")
			OnRedEnvelope($userName, $tid)
		 Case Else
		EndSwitch
	Next
EndFunc

;处理聊天信息
Func OnChatMsg($id, $content, $userName, $type = "user")
	;别理自己
	if($userName == $g_robotName) Then
		Return
	EndIf

	;待完成解析命令
	if(StringLeft($content, 1) == "/") Then; 用户命令
		OnChatCmd($id, $userName, $content)
		Return
	EndIf

	;拉黑
	if (IsInvalid($userName, $content)) Then;是否应该封掉?封掉后不再做处理
		;_DebugOut("block id: " & $id )
		Block($id)
		Local $msg = "@" & $userName &	" 因发敏感词已被禁言。"
		If $g_kickOut Then $msg &= "（同时被踢出直播间）"
		SendMsg($msg)
		Return;
	Endif

	;其他聊天命令解析
	; 当前直播
	if(StringInStr($content, "直播预告") > 0 Or StringInStr($content, "什么比赛") > 0  Or StringInStr($content, "什么赛事") > 0 Or StringInStr($content, "显示公告") > 0 Or StringInStr($content, "比赛公告") > 0 Or StringInStr($content, "赛事公告") > 0 Or StringInStr($content, "显示预告") > 0 Or StringInStr($content, "直播公告") > 0)	Then
		Local $notice = GetNotice()
		SendMsg($notice)
		Return
	EndIf

	; 在线列表
	if((StringInStr($content, "谁在线") > 0) Or StringInStr($content, "刷新在线") > 0 ) Then
		;SetSignal(120)
		Local $refresh = False
		if(StringInStr($content, "刷新在线") > 0) Then $refresh = True
		SendMsg("正在为您查询，请稍候。@" & $userName)
		Local $players = _GetOnlinePlayers()
		If($players == "") Then;get from window
			$players = _GetOnlinePlayersX($refresh)
			If(Not ProcessExists("online.exe")) Then
				Run("online.exe")
			Else
				_ShowOnline(True)
			EndIf
		EndIf

		Local $i, $strMsg= "在线("
		$strMsg &= $players[0] & "):"
		_ArrayShuffle1D($players, 1)
		For $i= 1 to $players[0]
			Local $len = StringLen($players[$i])
			If($len < 3) Then ContinueLoop
			If((StringLen($strMsg) + $len)>52) Then
				SendMsg($strMsg )
				$strMsg = ""
			EndIf
			$strMsg &= $players[$i] & ", "
		Next
		$strMsg &= "正直播: [em_43] " & $g_currentPlayer & " @" & $userName
		SendMsg($strMsg)
		Return
	EndIf
	if(StringInStr($content, "谁在打") == 1 ) Then
		Local $isAdmin = IsManager($id);
		If(Not $isAdmin) Then  Return
		SendMsg("请稍后查看屏幕快照。 @" & $userName)
		_ShowPreview()
		Return
	EndIf

	if(StringInStr($content, "谁和谁") == 1 Or StringInStr($content, "谁打谁") == 1) Then
		Local $playing = $g_currentPlayer
		if(StringLen($playing) < 3) Then $playing = "我也不清楚。可用他的战网id查询 @" & $userName
		SendMsg($playing)
		Return
	EndIf

	if(StringInStr($content, "播放音乐") == 1) Then
		Local $tm = StringMid($content, 5)
		if(StringLen($tm) > 2) Then
			Local $isAdmin = IsManager($id);
			If(Not $isAdmin) Then  Return
			Local $sname = PlayMusic($tm)
			If(StringLen($sname) > 1) Then
				SendMsg("正在播放歌曲：" & $sname & " @" & $userName)
			Else
				SendMsg("没找到歌曲：" & $tm & " @" & $userName)
				SendGift("dragon0513", 1)
			EndIf
		EndIf
		Return
	Endif
	if(StringInStr($content, "关闭音乐") == 1 Or StringInStr($content, "音乐停止") == 1) Then
		Local $isAdmin = IsManager($id);
		If(Not $isAdmin) Then  Return
		StopMusic()
		Return
	Endif

	if(StringInStr($content, "切换到") == 1) Then
		Local $tm = StringMid($content, 4)
		if(_IsPlayerName($tm)) Then ;;看是否是选手名字
		 ;SetSignal(120); 通知monitor额外等待30秒
			 Local $isAdmin = IsManager($id);
			 If(Not $isAdmin) Then
				If(IsPlayingGame()) Then
					SendMsg("正在打的时候不要换台。@" & $userName)
					Return
				EndIf
			 EndIf
			Try2Broadcast($tm, $userName, $isAdmin)
		Else
			;SendMsg("久仰 " & $tm & " 的大名，就是主播还没听说过。[em_46] @" & $userName)
			SendGift("dragon0513", 1)
		EndIf
		Return
	EndIf

	if(StringInStr($content, "谁是") == 1 Or StringRight($content, 2) == "是谁") Then
		;Local $bnid = StringMid($content, 3)
		Local $bnid = StringReplace(StringReplace($content, "谁是", ""), "是谁", "")
		If(Not StringIsASCII($bnid)) Then Return
		If(StringLen($bnid) < 2) Then
			SendMsg( $bnid & "包含的信息太少了, @" & $userName)
			Return
		EndIf
		Local $pname = _GetNameByBnid($bnid)
		if(StringLen($pname) < 3) Then
			SendMsg($bnid & "没有登记，请联系主播或使用AddId添加。@" & $userName)
		Else
			SendMsg($bnid & " 可能是：" & $pname & " @" & $userName)
		EndIf
		Return
	EndIf

	if(StringInStr($content, "重新启动") == 1 Or StringInStr($content, "重启直播") == 1) Then
		;SetSignal(120)
		Local $isAdmin = IsManager($id);
		RestartBroadcast($userName, $isAdmin)
		Return
	EndIf

	if(StringInStr($content, "命令帮助") == 1) Then
		ShowHelp()
		Return
	EndIf

	if(StringInStr($content, "卡了") > 0 Or StringInStr($content, "非常卡") > 0 _
		Or StringInStr($content, "很卡") > 0	Or StringInStr($content, "卡死了") > 0 _
		Or StringInStr($content, "卡住了") > 0 Or StringInStr($content, "不动了") > 0) Then
		;添加时注意添加数组长度!!!!!!!!!
		Local $msg[8]
		$msg[0] = "主播网速不行啊，咱都来打赏，让主播攒钱扩带宽[em_68]"
		$msg[1] = "等一下，主播可能在下片"
		$msg[2] = "刷新一下试试"
		$msg[3] = "要是长时间卡住使用'/restart'重新启动直播"
		$msg[4] = "主播，水友喊你来看看咋回事"
		$msg[5] = "送花保不卡，打赏看高清"
		$msg[6] = "快把礼物送出来"
		$msg[7] = "是你网络不行吧？少撸多干活，攒钱扩带宽吧，年轻人。"
		Local $r = Random(0, 7, 1)
		SendMsg($msg[$r])
		Sleep(100)
		SendFlower(1)
		Return
	EndIf

	If(StringInStr($content, "送花") > 0) Then
		SendFlower(1)
		SendMsg("请各位水友送出手中的鲜花，谢谢大家。")
		SpeakMsg("请各位水友送出手中的鲜花，谢谢大家。")
		Return
	EndIf

	If(StringInStr($content, "送龙蛋") > 0) Then
		SendGift("dragon0513", 1)
		SendMsg("请各位水友送出自己的蛋，谢谢大家。")
		SpeakMsg("请各位水友送出自己的蛋，谢谢大家。")
		Return
	EndIf

	if(StringInStr($content, "@" & $g_robotName) > 0 Or StringInStr($content, $g_robotName) == 1) Then
		Local $msg = StringReplace($content,"@" & $g_robotName, "")
		if(StringInStr($content, $g_robotName) == 1) Then
			$msg = StringMid($content, 3)
		EndIf
		$msg = StringStripWS($msg, 1+2)
		if(StringLen($msg) < 1) Then; 空消息
			SendMsg("嗯？")
			Return
		EndIf
		Local $ans = GetAnswer($msg, $id, $g_robotKey)
		if($ans <> Default) Then
			If(Random() > 0.5) Then
				$ans = $ans & " @" & $userName
			Else
				$ans = "@" & $userName & ", " & $ans;FormatAnswer($ans, $g_currentPlayer)
			EndIf
		Else
			$ans =	"@" & $userName & "[em_" & Random(1, 75, 1) & "]"
			SendGift("dragon0513", 1)
		EndIf
		SendMsg($ans)
	EndIf
EndFunc
;处理聊天命令，以斜杠/开头
Func OnChatCmd($id, $userName, $content)
	Local $tm = StringStripWS(StringLower(StringMid($content, 2)), 1+2);

	;_DebugOut("cmd: " & $tm )
	Select
	Case StringLeft($tm, 6) == "online" Or	StringLeft($tm, 7) == "refresh" Or	StringLeft($tm, 3) == "谁在线"
		Local $option = StringMid($content, 9) ;取元消息
		If($option == "off") Then
			_ShowOnline(False)
			Return
		EndIf
		If($option == "") Then
			_ShowOnline(True)
			;Return
		EndIf
		;SetSignal(60)
		SendMsg("正在为您查询，请稍候。@" & $userName)
		Local $force = False
		If($tm == "refresh") Then  $force = True
		Local $players = _GetOnlinePlayers()
		If($players == "") Then;get from window
			$players = _GetOnlinePlayersX($force)
			If(Not ProcessExists("online.exe")) Then
				Run("online.exe")
			Else
				_ShowOnline(True)
			EndIf
		EndIf
		Local $i, $strMsg= "在线("
		$strMsg &=	$players[0] & "):"
		_ArrayShuffle1D($players, 1)
		For $i= 1 to $players[0]
			Local $len = StringLen($players[$i])
			If($len < 3) Then ContinueLoop
			If((StringLen($strMsg) + $len)>52) Then
				SendMsg($strMsg )
				$strMsg = ""
			EndIf
			$strMsg &= $players[$i] & ", "
		Next
		$strMsg &= "正直播: [em_43] " & $g_currentPlayer & " @" & $userName
		Return
	Case $tm == "onliving" Or $tm == "live"
		SendMsg("正在直播: " & $g_currentPlayer & "。@" & $userName)
		;SpeakMsg("正在直播的是：" & $g_currentPlayer)
		Return

	Case $tm == "playing" Or $tm == "preview"
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
		Else
			SendMsg("请稍后查看屏幕快照。@" & $userName)
			_ShowPreview()
		EndIf
		;SpeakMsg("正在直播的是：" & $g_currentPlayer)
		Return
	Case $tm == "restart"
		;SetSignal(120)
		Local $isAdmin = IsManager($id);
		RestartBroadcast($userName, $isAdmin)
		Return
	Case (StringLeft($tm, 4) == "down") ;音量减小
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		Local $times = 1 ;默认参数
		Local $paraM = StringStripWS(StringMid($tm, 6), 1+2)
		If(StringLen($paraM)>0 And StringIsAlNum($paraM)) Then
			$times = Int($paraM) ;取次数
			if($times > 100) Then $times = 100;最多100
			If($times < 1) Then $times = 1
		EndIf

		Local $keys = StringFormat("^{down %d}", $times)
		Send($keys)
	Case (StringLeft($tm, 2) == "up") ;音量减小
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		Local $times = 1 ;默认参数
		Local $paraM = StringStripWS(StringMid($tm, 4), 1+2)
		If(StringLen($paraM)>0 And StringIsAlNum($paraM)) Then
			$times = Int($paraM) ;取次数
			if($times > 100) Then $times = 100;最多100
			If($times < 1) Then $times = 1
		EndIf
		Local $keys = StringFormat("^{up %d}", $times)
		Send($keys)
	Case (StringLeft($tm, 3) == "vol") ;音量
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		Local $times = 1 ;默认参数

		Local $paraM = StringStripWS(StringMid($tm, 5), 1+2)
		If(StringLen($paraM)>0) Then
			$times = Int($paraM) ;取次数
			if($times > 100) Then $times = 100;最多100
			If($times < -100) Then $times = -100
		EndIf
		If($times == 0) Then Return
		Local $op = "down"
		If($times > 0) Then $op = "up"
		Local $keys = StringFormat("^{%s %d}", $op, $times)
		Send($keys)
	Case (StringLeft($tm, 3) == "key") ;按键
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
		Else
			Local $keys = StringMid($content, 6) ;取元消息
			Send($keys)
		EndIf
		Return
	Case (StringLeft($tm, 4) == "bnid") ;通过id查找姓名
		Local $bnid = StringMid($content, 7)
		If(StringLen($bnid) < 2) Then
			SendMsg( $bnid & "包含的信息太少了，没法查。@" & $userName)
			Return
		EndIf
		Local $pname = _GetNameByBnid($bnid)
		if(StringLen($pname) < 3) Then
			SendMsg($bnid & "没有登记，请联系主播或者使用AddId添加到当前选手。@" & $userName)
		Else
			SendMsg($bnid & " 可能是：" & $pname & "。@" & $userName)
		EndIf
		Return
	Case (StringLeft($tm, 5) == "addid") ;添加id
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您不是管理员。@" & $userName)
		Else
			Local $bid = StringReplace(StringMid($content, 8), "&nbsp" , "");取元消息
			_AddBnid($g_currentPlayer, $bid)
		EndIf
		Return
	Case $tm == "info" ;比赛信息
		Local $notice = GetNotice()
		If(StringLen($notice) < 2) Then	$notice = $g_currentPlayer
		SendMsg($notice)
		;ConsoleWrite("notice:" & $notice & @CRLF)
		;SpeakMsg($gameInfo)
		Return
	Case (StringLeft($tm, 6) == "notice") ;添加notice只有管理员可以
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
		Else
			Local $notice = StringMid($content, 9) ;取元消息
			SetNotice($notice)
		EndIf
		Return
	Case (StringLeft($tm, 6) == "record") 
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		Local $words = StringLower(StringMid($content, 9))
		If($words == "off") Then
			StopRecord()
			SendMsg("录像已停止。@" & $userName)
			Return
		EndIf
		Local $room = IniRead($g_configFile, "Live", "Room", "")
		Local $prefix = StringReplace(StringReplace($g_currentPlayer, "/", ""), " ", "") & "_"
		Local $filePath = $g_VodPath & "\" & $prefix  & @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC & ".mp4"
		Local $r = StartRecord($room, $filePath)
		If($r) Then
			SendMsg("正在录像中...@" & $userName)
		Else
			SendMsg("录像启动失败，请重试。@" & $userName)
		EndIf
		Return
	 Case $tm == "opencamera" ;调出解说头像
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		; pause broadcast stream
		WinActivate("fd://0 - VLC media player")
		send("{SPACE}")
		Local $streamUrl = GetRoomConfig("LocalStream")
		WinClose($streamUrl)
		Sleep(3000)
		Run("C:\Program Files\VideoLAN\VLC\vlc.exe " & $streamUrl & " --file-caching=10000  --network-caching=10000 --fullscreen")
		Return
   Case $tm == "closecamera" ;调出解说头像
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		Local $streamUrl = GetRoomConfig("LocalStream")
		WinClose($streamUrl)
		WinClose("fd://0 - VLC media player")
		Return
	Case $tm == "ver" ;版本信息
		SendMsg("Version: " & $g_Version)
		Return

	Case $tm == "warning" ;警告信息
		Local $warning = "友情提醒：骂人、喷解说、比赛中换台 禁言1天，甚至被踢出直播间。"
		SendMsg($warning)
		SpeakMsg($warning)
		Return
	Case (StringLeft($tm, 5) == "speak") ;设置消息
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
		Else
			Local $words = StringMid($content, 8) ;取元消息
			SpeakMsg($words)
		EndIf
		Return
	Case (StringLeft($tm, 6) == "speech") ;禁用语音
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
		Else
			Local $words = StringLower(StringMid($content, 9))
			If($words == "off") Then
				$g_EnableSpeech = False
				SendMsg( "语音已关闭, @" & $username )
			Else
				$g_EnableSpeech = True
				SendMsg( "语音已开启, @" & $username )
				SpeakMsg("语音已开启")
			EndIf
		EndIf
		Return
	Case (StringLeft($tm, 5) == "music")
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		Local $skey = StringStripWS(StringMid($content, 8), 3)
		If(StringLen($skey) <= 1) Then
			StopMusic()
		Else
			Local $sname = PlayMusic($skey)
			If(StringLen($sname) > 1) Then
				SendMsg("正在播放歌曲：" & $sname & " @" & $userName)
			Else
				SendMsg("没找到歌曲：" & $skey & " @" & $userName)
			EndIf
		EndIf
		Return
	Case (StringLeft($tm, 3) == "set" Or StringLeft($tm, 3) == "sub") ;设置消息
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
		Else
			Local $gameInfo = StringMid($content, 6) ;取元消息
			_ShowInfoWindow($gameInfo)
		EndIf
		Return
    Case (StringLeft($tm, 3) == "app" Or StringLeft($tm, 6) == "reboot") ;restart haibo
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
		Else
			RestartLiveApp();
			SendMsg("已经开始直播。@" & $userName)
		EndIf
		Return
	Case (StringLeft($tm, 4) == "kill") ;杀灭进程
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
		Else
			Local $title = StringMid($content, 7) ;取元消息
			If(StringLen($title) > 1) Then
				WinActivate($title)
				Sleep(500)
				WinKill($title)
			Endif
		EndIf
		Return
	Case (StringLeft($tm, 5) == "block") ;添加黑名单关键字只有管理员可以
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		Local $key = StringMid($content, 8) ;取元消息
		Local $keyAdded = AddKey($key)
		If($keyAdded) Then SaveKeys();保存字典
		Return
	Case (StringLeft($tm, 4) == "lock") ;锁定换台
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		Local $min = 30 ;默认参数
		Local $paraM = StringStripWS(StringMid($tm, 6), 1+2)
		If(StringLen($paraM)>0 And StringIsAlNum($paraM)) Then
			$min = Int($paraM) ;取分钟
			if($min > 180) Then $min = 180;最多锁定3小时
		EndIf
		$g_lockPlayerExpired = _DateAdd("n", $min, _NowCalc())
		SendMsg("@" & $username & " 锁定至：" & $g_lockPlayerExpired)
		Return
	Case (StringLeft($tm, 6) == "unlock") ;解锁换台
		If(Not (IsManager($id))) Then
			SendMsg("对不起，您现在还不是管理员或者不在日榜。@" & $userName)
			Return
		EndIf
		$g_lockPlayerExpired = _NowCalc()
		Return
	Case ($tm == "help") Or ($tm == "?")
		ShowHelp()
		Return
	Case (_IsPlayerName($tm)) ;;看是否是在线选手名字
		;SetSignal(120); 通知monitor额外等待120秒
		Local $isAdmin = IsManager($id);
		If(Not $isAdmin) Then
		 If(IsPlayingGame()) Then
			SendMsg("正在打的时候不要换台。@" & $userName)
			Return
		 EndIf
		EndIf
		Try2Broadcast($tm, $userName, $isAdmin)
		Return
	Case Else
		SendMsg("命令有误，您可以输入'/help'、'/?'或“命令帮助”获取详细信息。@" & $userName)
	EndSelect
EndFunc

Func RestartBroadcast($username = "", $isAdmin = False)
	Static $RestartTime = _NowCalc()
	if(_DateDiff("s", $RestartTime, _NowCalc()) < 30) Then ;30秒内不再重启
		Return
	EndIf
	Local $secs = _DateDiff("s", $g_lockPlayerExpired, _NowCalc())
	if($secs < 0 And (Not $isAdmin)) Then ;锁定期限没达到
		SendMsg(" 锁定至：" & $g_lockPlayerExpired & " @" & $username )
		SpeakMsg("对不起，锁定期间不能重新启动。")
		Return
	EndIf

	$RestartTime = _NowCalc()
	_ShowInfoWindow("正在重启 " & $g_currentPlayer & " 的直播...")
	Local $pr = _Broadcast($g_currentPlayer, True)
	if($pr < 0) Then
		if(_IsBroadcasting()) Then
			SendMsg("别急，换台中...[em_4] @" & $username)
		ElseIf($pr == -3) Then
			SendMsg($g_currentPlayer & "已不在线。 @"& $username)
		Else
			SendMsg("不能重启" & $g_currentPlayer & "的直播[em_46] @"& $username)
		EndIf
		_ShowInfoWindow("重启 " & $g_currentPlayer & " 的直播失败。")
	Else
		SendMsg("[em_69]重启成功，继续直播: " & $g_currentPlayer & " @" & $username)
		_ShowInfoWindow($g_currentPlayer )
	EndIf
EndFunc

Func Try2Broadcast($playerName, $username="", $isAdmin=false)
	Static $lastSwitch = "2014/11/25 17:09:07"
	if(_DateDiff("s",$lastSwitch, _NowCalc()) < 30 And (Not $isAdmin)) Then Return;非管理员切换频率控制在30s以上
	if(StringLeft($playerName, 1) == "/") then
		;SendMsg("对不起, 现在不能自由切换了，原因自己猜。 @" & $username )
		;Return
	EndIf

	if(Not _IsPlayerName($playerName, True)) Then
		SendMsg($playerName & " 不在线[em_8] @" & $username)
		Return
	EndIf
	Local $secs = _DateDiff("s", $g_lockPlayerExpired, _NowCalc())
	if($secs < 0 And (Not $isAdmin)) Then ;非管理员锁定期限没达到
		SendMsg(" 锁定至：" & $g_lockPlayerExpired & " @" & $username )
		SpeakMsg("对不起，锁定 期间 不能 换台。")
		Return
	EndIf
	_ShowInfoWindow("正在切换到 " & $playerName & ", 请稍候...")
	Local $pr = _Broadcast($playerName)
	if($pr < 0) Then
		If($pr == -1) Then
			SendMsg("错误的选手名 " & $playerName & "  @" & $username)
		ElseIf ($pr == -2) Then
			SendMsg("没有找到 " & $playerName & " 的直播id。 @" & $username)
		ElseIf ($pr == -3) Then
			SendMsg( $playerName & "不在线。/online查看在线列表。 @" & $username)
		ElseIf ($pr == -4) Then
			SendMsg("不能播放 " & $playerName & "，启动错误。[em_46] @" & $username)
		EndIf
		SendGift("dragon0513", 1);送个龙蛋
		_ShowInfoWindow("切换到 " & $playerName & " 失败。")
	Else
		SendMsg("[em_69]正直播: " & $g_currentPlayer & " @" & $username)
		If($pr == 1) Then
			Local $subtitle = $g_currentPlayer
			If(StringLeft($subtitle, 1) == "/") Then $subtitle = StringMid($subtitle, 2)
			_ShowInfoWindow($subtitle)
		EndIf
		$lastSwitch = _NowCalc()
		If($isAdmin And $g_enableAutoLock) Then ;自动锁定
			$g_lockPlayerExpired = _DateAdd("n", 15, _NowCalc())
		EndIf
	EndIf
EndFunc

;处理礼物消息
Func OnGiftMsg($id, $userName, $giftType, $giftNumber)
	If($userName == $g_robotName) Then Return
	If(($giftType == "flower") And (Not $g_thankFlower)) Then Return
	If($giftType <> "flower" And (Not $g_thankGift)) Then Return
	If($giftType == "flower") Then
		If (Random() < 0.1) Then
			Local $msg = StringReplace(StringReplace($g_flowerMsgTemplate, "{用户}", "@" & $userName), "{数量}", $giftNumber);
			SendMsg($msg)
		EndIf
		Return
	EndIf
	If (_JSONIsNull($g_Gifts)) Then Return
	Local $giftName = "新礼物"
	Local $index = 0, $t
	Do
		$t = _JSONGet($g_Gifts, $index & ".name")
		if($t == $giftType) Then
			$giftName = _JSONGet($g_Gifts, $index & ".title")
			ExitLoop
		EndIf
		$index = $index + 1
	Until $t == $_JSONNull
	Local $msg = StringReplace(StringReplace(StringReplace($g_giftMsgMsgTemplate, "{用户}", "@" & $userName), "{数量}", $giftNumber), "{礼物}", $giftName);
	SendMsg($msg)
	SpeakMsg($msg)
	;_DebugOut($msg )
EndFunc

Func OnVIPJoin($userName)
	;Local $strMsg = "@" & $userName &	", 正直播 " & $g_currentPlayer
	;SendMsg($strMsg)
	SpeakMsg("欢迎 VIP :" & $userName)
EndFunc
Func OnHostJoin($userName)
	Local $strMsg = "叮咚叮咚，主播来了"
	SendMsg("主播来了，大家欢迎。")
	SpeakMsg($strMsg)
EndFunc
Func OnRedEnvelope($userName, $tid)
	;红包
	Local $strMsg = $userName & " 土豪发红包了，大家快抢。"
	SpeakMsg($strMsg)
	SendMsg($strMsg)

	;抢红包
	;_HttpGet($redEnvelopeUrl & $tid, 10, "http://star.longzhu.com/sk2")
	;$g_IE.document.parentWindow.execScript("aGet('" & $redEnvelopeUrl & $tid & "')")
EndFunc
;发送聊天信息
Func SendMsg($content)
	;ConsoleWrite($content & @crlf)
	Local $sendMsgUrl = "http://mbgo.plu.cn/chatroom/sendbulletscreen2?color=0x32CD32&style=1&callback=cb&group=%d&content=%s"

	Static $lastContent = ""
	If (StringCompare($content, $lastContent) == 0) Then
		;Return
	EndIf
	Local $s = 1, $lc = StringLen($content)
	DO
		Local $msg = StringMid($content, $s, 52)
		If($msg == "") Then ExitLoop
		Local $url = StringFormat($sendMsgUrl, $g_roomId, _EncodeURL($msg))
		_HttpGet($url)
		$s += 52
	Until $s >= $lc
	$lastContent = $content
EndFunc

Func SendFlower($count = 0)
	If($count == 0) Then
		Const $getFlowerCount = "http://giftapi.plu.cn/chatroom/getiteminventory?item=flower"
		Local $rtn = _HttpGet($getFlowerCount)
		$count = Int(StringTrimRight(StringTrimLeft($rtn,1), 1))
	EndIf
	SendGift("flower", $count);
EndFunc

Func SendGift($type = "flower", $count = 1)
	Const $sendGiftUrl = "http://giftapi.plu.cn/chatroom/sendgift?roomId=%d&number=%d&callback=cb&type=%s"
	Local $url = StringFormat($sendGiftUrl, $g_roomId, $count, $type)
	_HttpGet($url)
 EndFunc

Func SpeakMsg($strText)
	If Not $g_enableSpeech Then Return
	$strText = StringRegExpReplace($strText, "[~!@#$%^&*():;|<>_=+-]", "")
	Speak($strText, $g_speechEngine, 0)
EndFunc

Func Block($userId)
	If Not $g_enableBlock Then Return
	Local $blockUrl = "http://star.api.plu.cn/usermanage/blockuser?expiredSeconds=%s&roomId=%d&userid=%d"
	Local $url = StringFormat($blockUrl, $g_blockSeconds, $g_roomId, $userId)
	_HttpGet($url)
	If Not $g_kickOut Then Return
	Kickout($userId)
EndFunc

Func Kickout($userId)
	If Not $g_kickOut Then Return
	Local $kickUrl = "http://userapi.plu.cn/api/usermanage/kickoutroomuser?roomId=%d&userId=%d"
	Local $url = StringFormat($kickUrl,  $g_roomId, $userId)
	_HttpGet($url)
EndFunc

Func _CheckRoomStatus()
	Static $UpdateRoomTime = _NowCalc()
	if(($g_Managers <> $_JSONNull) And _DateDiff("s", $UpdateRoomTime, _NowCalc()) < 180) Then Return;180秒内不再更新
	$UpdateRoomTime = _NowCalc()
	Const $statusUrl = "http://star.api.plu.cn/api/roomstatus?pagetype=live&roomid=%d"
	Local $url = StringFormat($statusUrl, $g_roomId)
	Local $rtn = _HttpGet($url)
	If(StringLen($rtn) < 3) Then Return Default
	;ConsoleWrite("return:" & $rtn	)
	Local $objRtn = _JSONDecode($rtn)
	$g_Managers = _JSONGet($objRtn, "Managers")
	$g_UserRankList = _JSONGet($objRtn, "UserRankLists")
	Local $close = _JSONGet($objRtn, "Closed")
	if($close) Then
		$g_Status = "Closed"
		SendMsg("主播被封了，表示同情吧。")
	ElseIf (_JSONGet($objRtn, "Broadcast") = $_JSONNull) Then
		$g_Status = "Closed"
		SendMsg("直播挂了，尝试重启直播")
		RestartLiveApp()
	Else
		$g_Status = "Opened"
	Endif

	;取龙豆
	;#cs
	Local $boxUrl = "http://star.api.plu.cn/property/boxrebate"
	if(@HOUR > 19 AND @HOUR <= 23) Then
		$rtn = _HttpGet($boxUrl)
		If(StringLen($rtn) > 3) Then
			Local $objBox = _JSONDecode($rtn)
			Local $count = _JSONGet($objBox, "result")
			Local $span = _JSONGet($objBox, "timeSpan")
			Local $roll = _JSONGet($objBox, "count")
			If($span<1 And $count > 0 And $roll < 5) Then ;每天只能领3次
				SendMsg("刚得了"& $count & "颗龙豆，啦啦啦...");
			Endif
		EndIf
	EndIf
	;#ce

	;自动签到
	;#cs
	Local $signUrl = "http://task.u.plu.cn/missionv2/daysignreceive"
	if((@HOUR == 8 Or @HOUR == 12) AND @MIN < 31) Then
		$rtn = _HttpGet($signUrl)
		If(StringLen($rtn) > 3) Then
			Local $objSign = _JSONDecode($rtn)
			Local $code = _JSONGet($objSign, "code")
			If($code == 0) Then SendMsg("已签到攒蛋，啦啦啦...");每天签到一次
		EndIf
	EndIf
	;#ce
	Return $objRtn
EndFunc

Func RestartLiveApp()
	Local $hWnd = WinGetHandle("嗨播","MainWidgetWindow")
	If @error <> 0 Then
	   Return
		Run(@ProgramFilesDir & "\Haibo\hibo.exe")
		Sleep(50000)
	Endif

	WinSetState ($hWnd, "", @SW_RESTORE)
	WinActivate ($hWnd)
	WinSetOnTop($hWnd, "", 1)
	SendKeepActive($hWnd)

	Sleep(500)
	Send("{space}")
	Sleep(500)
	Send("{enter}")
	Sleep(500)
	SendKeepActive("")
	WinMove($hWnd, "", 0, 0)
	Sleep(500)
	MouseClick("left", 90, 630, 1, 0)
	Sleep(1000)
	WinSetOnTop($hWnd, "", 0)
	WinSetState ($hWnd, "", @SW_MINIMIZE)

EndFunc

Func IsManager($id)
	Local $index=0, $mid
	If($id == $g_hostId) Then
		Return True
	EndIf
	Do
		$mid = _JSONGet($g_Managers, $index & ".UserId")
		if($mid == $id) Then
		 Return True
		EndIf
		$index = $index + 1
	Until $mid == $_JSONNull
	$index = 0
	Do
		$mid = _JSONGet($g_UserRankList, $index & ".UserId")
		if($mid == $id) Then
		 Return True
		EndIf
		$index = $index + 1
	Until ($mid == $_JSONNull OR $index >= 10)
	Return False
EndFunc

Func ShowHelp()
	SendMsg("/online:在线列表；/选手名:切换到指定选手；/playing:查看在线屏幕；/live:当前直播；/info:显示比赛通告；/help或/?:显示帮助信息")
	Sleep(500)
	SendMsg("你也可以输入：谁在线、刷新在线选手；谁在直播、直播的是谁；切换到选手名；谁在打；什么比赛、谁打谁 等来查看相关信息。")
EndFunc

Func SetNotice($notice)
	SetRoomConfig("Notice", $notice)
EndFunc

Func GetNotice()
	Return GetRoomConfig("Notice")
 EndFunc

Func _ArrayShuffle1D(ByRef $array, $startIndex = 0, $endIndex = 0)
	If $startIndex = Default Then $startIndex = 0
	If $endIndex = Default Then $endIndex = 0
	Local $dim1 = UBound($array)
	If $endIndex = 0 Then $endIndex = $dim1 - 1
	Local $tmp, $iRnd
	For $i = $endIndex To $startIndex + 1 Step -1
		$iRnd = Random($startIndex, $i, 1)
		$tmp = $array[$i]
		$array[$i] = $array[$iRnd]
		$array[$iRnd] = $tmp
	Next
EndFunc
