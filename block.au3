#include-once
#include "Array.au3"
#include <FileConstants.au3>
#include "config.au3"
;#include <Debug.au3>
;_DebugSetup("plu",False, 2, "", True)

;加载字典
;Const $keyFile = @ScriptDir & "\block.txt" ;过滤关键字，每行一个
Global $keys = LoadKeys($g_blockKeysFile)
;******** 字典设置及判断 ********
;加载字典
Func LoadKeys($filePath)
   Local $keytext = FileRead($filePath)
   $keytext = StringStripCR($keytext)
   Local $keys = StringSplit($keytext, @LF)
   ;_DebugOut("load block keys : " & $keys[0])
   Return $keys
EndFunc
;保存字典
Func SaveKeys($filePath = $g_blockKeysFile)

   Local $hFileOpen = FileOpen($filePath, $FO_OVERWRITE)
   Local $i
   For $i = 1 to $keys[0]
	  If(StringLen($keys[$i]) > 3) Then
		 FileWriteLine($hFileOpen, $keys[$i])
	  EndIf
   Next
   FileClose($hFileOpen)
EndFunc

;添加关键字
Func AddKey($key)
   $key = StringRegExpReplace($key, "[\p{P}\x20-\x2f\x3a-\x40\x5b-\x60\x7b-\xff]", "")
   If (StringLen($key) > 3 And _ArraySearch($keys, $key) == -1) Then
	  _ArrayAdd($keys, $key)
	  $keys[0] = $keys[0] + 1
	  ;_DebugOut("add a new key: " & $key)
	  Return True
   EndIf
   Return False
EndFunc
;判断是否包含敏感信息
Func IsInvalid($id, $content)
   Local $i
   $id = StringRegExpReplace($id, "[\p{P}\x20-\x2f\x3a-\x40\x5b-\x60\x7b-\xff]", "")
   $content = StringRegExpReplace($content, "[\p{P}\x20-\x2f\x3a-\x40\x5b-\x60\x7b-\xff]", "")
   For $i = 1 to $keys[0]
	  if(StringLen($keys[$i]) > 3 And _
		 (StringInStr($content, $keys[$i]) >=1) Or (StringInStr($id, $keys[$i]) >=1)) Then
		 Return True
	  EndIf
   Next
   Return False
EndFunc
