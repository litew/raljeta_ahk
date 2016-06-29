; Help functions

Debug(dMessage)
{
   global flg
   if (flg.Debug)
      MsgBox % dMessage
}

AddTrailingBackslash(ptext)
{
	if (SubStr(ptext, 0, 1) <> "\")
		return, ptext . "\"
	return, ptext
}

CheckQuotes(Path)
{
   if (InStr(Path, A_Space, false) <> 0)
   {
      Path = "%Path%"
   }
   return, Path
}

; Based on code by Sean and SKAN @ http://www.autohotkey.com/forum/viewtopic.php?p=184468#184468
DownloadFile(url, file, info="")
{
    static vt
    if !VarSetCapacity(vt)
    {
        VarSetCapacity(vt, A_PtrSize*11), nPar := "31132253353"
        Loop Parse, nPar
            NumPut(RegisterCallback("DL_Progress", "F", A_LoopField, A_Index-1), vt, A_PtrSize*(A_Index-1))
    }
    global _cu, descr
    SplitPath file, dFile
    SysGet m, MonitorWorkArea, 1
    y := mBottom-62-2, x := mRight-330-2, VarSetCapacity(_cu, 100), VarSetCapacity(tn, 520)
    , DllCall("shlwapi\PathCompactPathEx", "str", _cu, "str", url, "uint", 50, "uint", 0)
    descr := (info = "") ? _cu : info . ": " _cu
    Progress Hide CWFAFAF7 CT000020 CB445566 x%x% y%y% w330 h62 B1 FS8 WM700 WS700 FM8 ZH12 ZY3 C11,, %descr%, AutoHotkeyProgress, Tahoma
    if (0 = DllCall("urlmon\URLDownloadToCacheFile", "ptr", 0, "str", url, "str", tn, "uint", 260, "uint", 0x10, "ptr*", &vt))
        FileCopy %tn%, %file%
    else
        ErrorLevel := -1
    Progress Off
    return ErrorLevel
}

DL_Progress(pthis, nP=0, nPMax=0, nSC=0, pST=0)
{
    global _cu, descr
    if A_EventInfo = 6
    {
        Progress Show
        Progress % P := 100*nP//nPMax, % "     " Round(np/1024,1) " KB / " Round(npmax/1024) " KB    [ " P "`% ]", %descr%
    }
    return 0
}

NewLinkMsg(VideoSite, VideoName = "")
{
   global lng
   
   TmpMsg := % lng.MSG_NEW_LINK_FOUND . VideoSite . "`r`n"  
   if (VideoName <> "")
      TmpMsg := TmpMsg . lng.MSG_NEW_LINK_FILENAME . VideoName . "`r`n`r`n"
   
	MsgBox 36, %ProgramName%, % TmpMsg lng.MSG_NEW_LINK_ASK, 50
	IfMsgBox Yes
		return, 0
	else
		return, -1
}

LogAdd(Str = "-")
{
   global cfg
   
   if (cfg.Logging > 0) and (cfg.LogFile <> "")
   {
      if (Str = "-")
         FileAppend, ------------------------------`r`n, % cfg.LogFile
      else 
         FileAppend, %Str%`r`n, % cfg.LogFile
   }
}

ReplaceForbiddenChars(S_IN, ReplaceByStr = "")
{
   S_OUT := ""
   Replace_RegEx := "im)[\/:*?""<>|]*"
   
   S_OUT := RegExReplace(S_IN, Replace_RegEx, "")
   if (S_OUT = 0)
      return, S_IN
   if (ErrorLevel = 0) and (S_OUT <> "")
      return, S_OUT
}

NormalizeFilename(VideoID, FileName, FileExt)
{   
   FileName := Trim(FileName)
   if (FileName <> "")
   {
      SplitPath FileName,,, ExtFromName
      if (ExtFromName <> FileExt)
      {
         FileName := SubStr(ReplaceForbiddenChars(FileName), 1, 251) . "." . FileExt
      }
      else
      {
         FileName := SubStr(ReplaceForbiddenChars(FileName), 1, 251)
      }
   }
   else
   {
      if (VideoID <> "")
      {
         FileName := SubStr(ReplaceForbiddenChars(VideoID), 1, 251) . "." . FileExt
      }
      else
         FileName := ""
   }
   return, FileName
}

Start(Target, Minimal = false, Title = "")
{
   cPID = -1
   if Minimal
      Run %ComSpec% /c "%Target%", A_WorkingDir, Min UseErrorLevel, cPID
   else
      Run %ComSpec% /c "%Target%", A_WorkingDir, UseErrorLevel, cPID
   if ErrorLevel = 0
   {
      if (Title <> "")
      {
         WinWait ahk_pid %cPID%,,,2
         WinSetTitle, %Title%
      }
      return, 0
   }
   else
      return, -1
}

ShowTrayBalloon(TipTitle = "", TipText = "", ShowTime = 5000, TipType = 1)
{
   global cfg
   
   if (not cfg.ShowBalloons)
      return, 0
   gosub, RemoveTrayTip
   if (TipText <> "")
   {
      Title := (TipTitle <> "") ? TipTitle : ProgramName
      TrayTip, %Title%, %TipText%, 10, %TipType%+16
      SetTimer, RemoveTrayTip, %ShowTime%
   }
   else
   {
      gosub, RemoveTrayTip
      return, 0
   }
   return, 0
   
   RemoveTrayTip:
      SetTimer, RemoveTrayTip, Off
      TrayTip
   return
}

UriEncode(Uri)
{
    oSC := ComObjCreate("ScriptControl")
    oSC.Language := "JScript"
    Script := "var Encoded = encodeURIComponent(""" . Uri . """)"
    oSC.ExecuteStatement(Script)
    Return, oSC.Eval("Encoded")
}

UriDecode(Uri)
{
    oSC := ComObjCreate("ScriptControl")
    oSC.Language := "JScript"
    Script := "var Decoded = decodeURIComponent(""" . Uri . """)"
    oSC.ExecuteStatement(Script)
    Return, oSC.Eval("Decoded")
}

StrPutVar(string, ByRef var, encoding)
{
    VarSetCapacity( var, StrPut(string, encoding)
        * ((encoding="utf-16"||encoding="cp1200") ? 2 : 1) )
    return StrPut(string, &var, encoding)
}