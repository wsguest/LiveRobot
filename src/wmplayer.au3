#include-once
#cs
	_wmpcreate()
	Return: The object for the control
#ce#include-once
Func _wmpcreate()
	Local $oWMP = ObjCreate("WMPlayer.OCX")
	If Not IsObj($oWMP) Then Return 0
	$oWMP.settings.autoStart = 1
	Return $oWMP
EndFunc   ;==>_wmpcreate
#cs
	_wmploadmedia( $object, $URL, $autostart = 1 )
	$object:    Object returned from the _wmpcreate()
	$URL:        Path or URL of the media
	$autostart:    1 = yes
	0 = no

	Return: None
#ce
Func _wmploadmedia($object, $URL, $autostart = 1)
   If Not IsObj($object) Then Return 0
   $object.URL = $URL
   If $autostart = 1 And $object.controls.isAvailable("play") Then $object.controls.play()
EndFunc   ;==>_wmploadmedia
#cs
	_wmpsetvalue( $object, $setting, $para=1 )
	$object:    Object returned from the _wmpcreate()
	$setting:    "play"
	   "stop"
	   "pause"
	   "invisible" (Hides all)
	   "control"    (Shows controls)
	   "nocontrol"    (Hides controls)
	   "fullscreen"
	   "step"        (frames to step before freezing)
	   "fastforward"
	   "fastreverse"
	   "volume"    (0 To 100)
	   "rate"        (-10 To 10)
	   "playcount"

	Return: None
#ce
Func _wmpsetvalue($object, $setting, $para = 1)
    $setting = StringLower($setting)
	Select
		Case $setting = "play"
			If $object.controls.isAvailable("play") Then $object.controls.play()
		Case $setting = "stop"
			If $object.controls.isAvailable("stop") Then $object.controls.stop()
		Case $setting = "pause"
			If $object.controls.isAvailable("pause") Then $object.controls.pause()
		Case $setting = "invisible"
			$object.uiMode = "invisible"
		Case $setting = "controls"
			$object.uiMode = "mini"
		Case $setting = "nocontrols"
			$object.uiMode = "none"
		Case $setting = "fullscreen"
			$object.fullscreen = "true"
		Case $setting = "step"
			If $object.controls.isAvailable("step") Then $object.controls.step($para)
		Case $setting = "fastForward"
			If $object.controls.isAvailable("fastForward") Then $object.controls.fastForward()
		Case $setting = "fastReverse"
			If $object.controls.isAvailable("fastReverse") Then $object.controls.fastReverse()
		Case $setting = "volume"
			$object.settings.volume = $para
		Case $setting = "rate"
			$object.settings.rate = $para
		Case $setting = "playcount"
			$object.settings.playCount = $para
	EndSelect
 EndFunc   ;==>_wmpsetvalue
#cs
	_wmpgetvalue( $object, $setting )
	$object:    Object returned from the _wmpcreate()
	$setting:    "url"
	   "fullscreen"
	   "playstate" 1=stopped 2=paused 3=playing
	   "mode"
	   "volume" 0-100
	   "playcount"
	   "duration" double
	   "dstring" 4:32
	   "position" double
	   "pstring" 0:32

	Return: property value
#ce
Func _wmpgetvalue($object, $setting)
   $setting = StringLower($setting)
   Select
   Case $setting = "url"
	  Return $object.URL
   Case $setting = "fullscreen"
	  Return $object.fullscreen
   Case $setting = "playstate"
	  Return $object.playState
   Case $setting = "mode"
	  Return $object.uMode
   Case $setting = "volume"
	  Return $object.settings.volume
   Case $setting = "playcount"
	  Return $object.settings.playCount
   Case $setting = "duration"
	  Return $object.currentMedia.duration
   Case $setting = "dstring"
	  Return $object.currentMedia.durationString
   Case $setting = "position"
	  Return $object.controls.currentPosition
   Case $setting = "pstring"
	  Return $object.controls.currentPositionString

   EndSelect
EndFunc  ;==>_wmpsetvalue