#include-once
#include "wmplayer.au3"
#include "JSON.au3"
#include "http.au3"
; new engine => add engine name [EG] and define _Get[EG]Music function
Local $objPlayer
Local $engines[] = ["Local", "QQ", "Xiami", "163", "Baidu", "Kugou", "Kuwo", "Migu", "Echo"]

#cs
Local $url, $i, $info, $name = "only time"
For $i = 0 To UBound($engines) - 1
	$url = Call("_Get" & $engines[$i] & "Music" , $name, $info)
	If($url <> Default And StringInStr($info, $name) > 0) Then 
		ConsoleWrite($engines[$i] & " url:" & $url & @CRLF)
		ConsoleWrite("info:" & $info & @CRLF & @CRLF)
	else
		ConsoleWrite($engines[$i] & " failed" & @CRLF)
	EndIf
Next 
#ce

#cs
Local $x = PlayMusic("only time")
ConsoleWrite($x & @CrLF)
Sleep(10000)
Local $x = PlayMusic("海阔天空 beyond")
ConsoleWrite($x & @CrLF)
Sleep(10000)
ConsoleWrite( PlayMusic("红豆 王菲")& @CrLF)
Sleep(10000)
PlayMusic("@50")
Sleep(3000)
ConsoleWrite( PlayMusic("小白杨 彭丽媛"))
Sleep(10000)
StopMusic()
#ce

Func PlayMusic($strText)
	if(Not IsObj($objPlayer)) Then
	  $objPlayer = _wmpcreate()
	EndIf
	Local $sinfo = ""
	Local $param = StringStripWS(StringMid($strText, 2), 3)
	If(StringLeft($strText, 1) == "@") Then ; 音量
		If(StringIsDigit($param)) Then
			Local $volume = int($param)
			if($volume >= 0 and $volume <= 100) Then
				SetVolume($volume)
				Return "volume: " & $volume
			EndIf
		EndIf
	EndIf
	$strText = StringStripWS($strText, 3) ;去掉空白
	Local $url = _GetMusic($strText, $sinfo)
	;ConsoleWrite("music url:" & $url & @CRLF)
	if($url <> Default) Then _wmploadmedia($objPlayer, $url)
	Return $sinfo
EndFunc

Func StopMusic()
	If(IsObj($objPlayer)) Then
		_wmpsetvalue($objPlayer, "stop")
	EndIf
EndFunc

Func SetVolume($percent)
	If(IsObj($objPlayer)) Then
		_wmpsetvalue($objPlayer, "volume", $percent)
	EndIf
EndFunc

Func _GetMusic($name, ByRef $info)
	Local $url, $i
	For $i = 0 To UBound($engines) - 1
		$url = Call("_Get" & $engines[$i] & "Music" , $name, $info)
		If($url <> Default And StringInStr($info, $name) > 0) Then Return $url
	Next 
	Return Default
EndFunc

Func _GetLocalMusic($name, ByRef $Info)
	Const $path = @ScriptDir & "\music\"
	Local $hSearch = FileFindFirstFile($path & "\*" & $name & "*.*")
	If($hSearch = -1) Then Return Default
	Local $sFileName = ""
	Local $sFileName = FileFindNextFile($hSearch)
	If @error Then Return Default
	 FileClose($hSearch)
	$Info = $sFileName
	Return $path & $sFileName
EndFunc

Func _GetQQMusic($name, ByRef $Info)
	Const $searchUrl = "https://c.y.qq.com/soso/fcgi-bin/search_for_qq_cp?format=json&w="
	Const $infoUrl = "https://c.y.qq.com/splcloud/fcgi-bin/fcg_list_songinfo_cp.fcg?url=1&typelist=0&idlist=%s&midlist=%s"
	Const $playUrl = "http://ws.stream.qqmusic.qq.com/C100%s.m4a?fromtag=38"
	Local $rtn = _HttpGet($searchUrl & _EncodeURL($name))

	IF(StringLen($rtn) > 8 And StringInStr($rtn, '"code":0') >= 1) Then
		;ConsoleWrite($rtn)
		Local $result = _JSONDecode($rtn)
		IF(_JSONIsObject($result)) Then
			Local $sid = _JSONGet($result, "data.song.list.0.songid")
			Local $mid = _JSONGet($result, "data.song.list.0.songmid")
			$Info = _JSONGet($result, "data.song.list.0.songname") & ' - ' & _JSONGet($result, "data.song.list.0.singer.0.name")
			;$rtn = _HttpGet(StringFormat($infoUrl, $sid, $mid))
			;Local $sinfo =_JSONDecode($rtn)
			Local $url = StringFormat($playUrl, $mid)
			Return $url
		Endif
	EndIf
	Return Default
EndFunc


Func _GetXiamiMusic($name, ByRef $Info)
	Const $searchUrl = "http://www.xiami.com/search/json?t=4&n=3&k="
	Const $infoUrl = "http://www.xiami.com/song/playlist/id/%s/object_name/default/object_id/0/cat/json"
	Const $playUrl = "http://ws.stream.qqmusic.qq.com/C100%s.m4a?fromtag=38"
	Local $rtn = _HttpGet($searchUrl & _EncodeURL($name))

	IF(StringLen($rtn) > 8 And StringInStr($rtn, '"song_id":') >= 1) Then
		;ConsoleWrite($rtn)
		Local $result = _JSONDecode($rtn)
		IF(_JSONIsObject($result)) Then
			Local $sid = _JSONGet($result, "songs.0.song_id")
			$Info = _JSONGet($result, "songs.0.song_name") & ' - ' & _JSONGet($result, "songs.0.artist_name")
			Local $locUrl = StringFormat($infoUrl, $sid)
			
			$rtn = _HttpGet(StringFormat($infoUrl, $sid))
			Local $sinfo =_JSONDecode($rtn)
			Local $loc = _JSONGet($sinfo, "data.trackList.0.location")
			;decode location
			Local $rows = Int(StringMid($loc, 1, 1))
			$loc = StringMid($loc, 2)
			Local $len = StringLen($loc)
			Local $cols = Floor($len / $rows)
			Local $re_col = Mod($len, $rows)
			
			Local $buf[$rows]
			For $r = 0 To $rows -1
				Local $ln = $cols
				If($r < $re_col) Then $ln = $cols + 1
				$buf[$r] = StringToASCIIArray (StringMid($loc, 1, $ln + 1))
				$loc = StringMid($loc, $ln+1)
			Next 

			Local $durl = ""
			For $i = 0 To $len - 1
				Local $t = $buf[Mod($i, $rows)]
				$durl &= Chr($t[Floor($i/$rows)])
			Next
			Local $url = StringReplace(_DecodeURL($durl), "^", "0")
			Return $url
		Endif
	EndIf
	Return Default
EndFunc


Func _GetBaiduMusic($name, ByRef $Info)
	Const $searchUrl = "http://sug.music.baidu.com/info/suggestion?format=json&version=2&from=0&word="
	Const $infoUrl = "http://music.baidu.com/data/music/fmlink?type=mp3&rate=320&songIds="
	Local $rtn = _HttpGet($searchUrl & _EncodeURL($name))

	IF(StringLen($rtn) > 8 And StringInStr($rtn, "error_code") <= 0) Then
		;ConsoleWrite($rtn)
		Local $result = _JSONDecode($rtn)
		IF(_JSONIsObject($result)) Then
			Local $sid = _JSONGet($result, "data.song.0.songid")
			$Info = _JSONGet($result, "data.song.0.songname") & ' - ' & _JSONGet($result, "data.song.0.artistname")
			$rtn = _HttpGet( $infoUrl & $sid)
			Local $sinfo =_JSONDecode($rtn)
			Local $url = _JSONGet($sinfo, "data.songList.0.songLink")
			Return $url
		Endif
	EndIf
	Return Default
EndFunc

Func _GetKugouMusic($name, ByRef $Info)
	Const $searchUrl = "http://songsearch.kugou.com/song_search_v2?platform=WebFilter&keyword="
	Const $infoUrl = "http://www.kugou.com/yy/index.php?r=play/getdata&hash="; acc可为mp3
	Local $rtn = _HttpGet($searchUrl & _EncodeURL($name))
	IF(StringLen($rtn) > 8) Then
		Local $result = _JSONDecode($rtn)

		IF(_JSONIsObject($result)) Then
			Local $sid = _JSONGet($result, "data.lists.0.FileHash")
			;ConsoleWrite("r:" & $sid & @CRLF)
			$Info = _JSONGet($result, "data.lists.0.SongName") & ' - ' & _JSONGet($result, "data.lists.0.SingerName")
			$rtn = _HttpGet( $infoUrl & $sid)
			Local $sinfo =_JSONDecode($rtn)
			Local $url = _JSONGet($sinfo, "data.play_url")
			Return $url
		Endif
	EndIf
	Return Default
EndFunc

Func _GetKuwoMusic($name, ByRef $Info)
	Const $searchUrl = "http://search.kuwo.cn/r.s?ft=music&rformat=json&encoding=utf8&rn=1&SONGNAME="
	Const $infoUrl = "http://antiserver.kuwo.cn/anti.s?type=convert%5Furl&response=url&format=aac%7Cmp3&rid="; acc可为mp3
	Local $rtn = _HttpGet($searchUrl & _EncodeURL($name))
	IF(StringLen($rtn) > 8) Then
		Local $result = _JSONDecode($rtn, "", True)

		IF(_JSONIsObject($result)) Then
			Local $sid = _JSONGet($result, "abslist.0.MUSICRID")
			;ConsoleWrite("r:" & $sid & @CRLF)
			$Info = _JSONGet($result, "abslist.0.SONGNAME") & ' - ' & _JSONGet($result, "abslist.0.ARTIST")
			Local $url = _HttpGet( $infoUrl & $sid)
			Return $url
		Endif
	EndIf
	Return Default
EndFunc


Func _Get163Music($name, ByRef $info)
	Const $searchUrl = "http://s.music.163.com/search/get/?type=1&limit=2&offset=0&s="
	Local $rtn = _HttpGet($searchUrl & _EncodeURL($name))
	;ConsoleWrite("rtn:" & $rtn & @CRLF)
	IF(StringLen($rtn) > 8) Then
		Local $result = _JSONDecode($rtn, "", True)
		IF(_JSONIsObject($result) And _JSONGet($result, "code") == 200) Then
			Local $sid = _JSONGet($result, "result.songs.0.id")
			$Info = _JSONGet($result, "result.songs.0.name") & ' - ' & _JSONGet($result, "result.songs.0.artists.0.name")
			Local $url = _JSONGet($result, "result.songs.0.audio")
			Return $url
		Endif
	EndIf
	Return Default
EndFunc

Func _GetMiguMusic($name, ByRef $info)
	Const $searchUrl = "http://music.migu.cn/webfront/searchNew/suggest.do?keyword="
	Const $infoUrl = "http://music.migu.cn/webfront/player/findsong.do?type=song&itemid="
	Local $rtn = _HttpGet($searchUrl & _EncodeURL($name))
	IF(StringLen($rtn) > 8) Then
		Local $result = _JSONDecode($rtn, "", True)

		IF(_JSONIsObject($result)) Then
			Local $sid = _JSONGet($result, "songList.0.id")
			;ConsoleWrite("r:" & $sid & @CRLF)
			$Info = _JSONGet($result, "songList.0.name") & ' - ' & _JSONGet($result, "songList.0.singerName")
			$rtn = _HttpGet( $infoUrl & $sid )
			$result = _JSONDecode($rtn, "", True)
			Local $url = _JSONGet($result, "msg.0.mp3")
			Return $url
		Endif
	EndIf
	Return Default
EndFunc

Func _GetEchoMusic($name, ByRef $info)
	Const $searchUrl = "http://www.app-echo.com/api/search/input-box-recommend?keyword="
	Local $rtn = _HttpGet($searchUrl & _EncodeURL($name))
	IF(StringLen($rtn) > 8) Then
		Local $result = _JSONDecode($rtn, "", True)
		IF(_JSONIsObject($result)) Then
			$Info = _JSONGet($result, "data.0.sound.name")
			Local $url = _JSONGet($result, "data.0.sound.source")
			$url = StringReplace($url, "\", "")
			Return $url
		Endif
	EndIf
	Return Default
EndFunc


