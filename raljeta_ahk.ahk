;	Raljeta AHK, version: 0.3.x
;	Copyright (C) 2011-2014  Litew <litew9@gmail.com>
;
;	This program is free software: you can redistribute it and/or modify
;	it under the terms of the GNU General Public License as published by
;	the Free Software Foundation, either version 3 of the License, or
;	(at your option) any later version.
;
;	This program is distributed in the hope that it will be useful,
;	but WITHOUT ANY WARRANTY; without even the implied warranty of
;	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;	GNU General Public License for more details.
;
;	You should have received a copy of the GNU General Public License
;	along with this program. If not, see <http://www.gnu.org/licenses/>.

#NoEnv
#Persistent
#Warn All, StdOut
#SingleInstance Force
SendMode input
#Include %A_ScriptDir%\rahk\
#Include ..\default_lang.txt
#Include lib\functions.ahk
#Include lib\HTTPRequest.ahk
#Include web\rutube.ahk
SetWorkingDir %A_ScriptDir%

global ProgramName				:= "Raljeta AHK"
global ProgramVersion			:= "0.3.44"

global TIP_TYPE_INFO			:= 1
global TIP_TYPE_WARNING			:= 2
global TIP_TYPE_ERROR			:= 3

; Config and flags
	
flg						:= {}
flg["Busy"]				:= false
flg["ProgramLoaded"]	:= false
flg["Debug"]			:= false

sysp					:= {}
sysp["DirRahk"]			:= A_ScriptDir "\rahk\"
sysp["DirLogs"]			:= A_WorkingDir "\logs\"
sysp["DirBin"]			:= sysp.DirRahk "bin\"
sysp["File7z"]			:= sysp.DirBin "7za.exe"
sysp["FileTrayIcon"]	:= sysp.DirRahk "res\rahk.ico"
sysp["FileConfig"]		:= A_ScriptDir "\raljeta_ahk.ini"
sysp["FileRtmpdump"]	:= sysp.DirBin "rtmpdump.exe"
sysp["FilePHP"]			:= sysp.DirBin "hds\php.exe"
sysp["FileHDS"]			:= sysp.DirBin "hds\AdobeHDS.php"
sysp["RegRun"]			:= "Software\Microsoft\Windows\CurrentVersion\Run"
sysp["LinkHDS"]			:= "http://tradiz.org/files/hds.7z"
sysp["Link7z"]			:= "http://tradiz.org/files/rahk/7za.exe"

cfg						:= {}

cfg["DirDownloads"]		:= A_WorkingDir "\downloads\"
;~ cfg["LogLevel"]			:= 0		; 0 - none, 1 - normal, 2 - verbose, 3 - debug
cfg["Autorun"]			:= 0		; load when system starts
cfg["RunCount"]			:= 1
cfg["LinkGetTimeout"]	:= 10000	; ms
cfg["ClpMaxTextLength"]	:= 300		; num of symbols in clipboard to check
cfg["ShowBalloons"]		:= true
cfg["BalloonShowTime"]	:= 5000
cfg["ClipboardMon"]		:= true
cfg["AskOnNewLink"]		:= true
;~ cfg["UserAgent"]		:= "Opera/9.80 (Windows NT 5.1) Presto/2.12.388 Version/12.16" ; 12.07.2014
cfg["UserAgent"]		:= "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36 OPR/22.0.1471.70"
;~ cfg["RutubeExp"]		:= "iS)(?P<VIDEO_URL>(?:http:\/\/)?rutube\.ru\/video\/(?P<VIDEO_ID>[\w\d]{10,})\/?)"
cfg["RutubeExp"]		:= "iS)(?P<TRACK_URL>(?:http:\/\/)?rutube\.ru\/(?:.*\/)?video\/(?:private\/)?(?P<TRACK_ID>[\w\d]{10,})\/?)"
cfg["FileExt"]			:= "flv"
;~ cfg["LogExt"]			:= "log"
cfg["VideoQuality"]		:= 3		; 1 - lq, 2 - mq, 3 - hq
cfg["Timeout"]			:= 60		; sec

; ----- Script entry point-----

ReadProgramSettings()
gosub, CreateTrayMenu

if (cfg.RunCount <= 2)
{
	cfg.RunCount++
	ShowTrayBalloon(ProgramName A_Space ProgramVersion, lng.MSG_HOWTO, 10000, TIP_TYPE_INFO)
}
OnExit, ApplicationClose
flg.ProgramLoaded := true
; ----- End  -----

; ----- Read/write settings from/to INI file -----

ReadProgramSettings()
{
	global cfg, sysp,
	
	;~ RegRead, def_acp, HKLM, SYSTEM\CurrentControlSet\Control\Nls\CodePage, ACP
	;~ RegRead, def_oemcp, HKLM, SYSTEM\CurrentControlSet\Control\Nls\CodePage, OEMCP
	fCfg := FileOpen(sysp.FileConfig, 0 4)
	if (IsObject(fCfg))
	{
		while (!fCfg.AtEOF)
		{
			line := RTrim(fCfg.ReadLine(), "`r`t`n")
			if (line = "") and (line != "`n")
				continue
			IfInString, line,=
			{
				eqSignPos := InStr(line, "=", false, 1, 1)
				opt := SubStr(line, 1, eqSignPos - 1)
				val := SubStr(line, eqSignPos + 1)
				if (opt <> "") and (opt <> "`n") and (val <> "") and (val <> "`n")
					cfg[opt] := Trim(val, " `r`t`n")
			}
		}
		fCfg.Close()
		return, 0
	}
	else
		return, -1
}

WriteProgramSettings()
{
	global cfg, sysp,
	
	fCfg := FileOpen(sysp.FileConfig, 13)
	if (IsObject(fCfg))
	{
		for opt, val in cfg
			if (opt <> "") and (val <> "") and (val <> "`n")
				fCfg.Write(opt "=" val "`r`n")
		fCfg.Close()
		return, 0
	}
	else
		return, -1
}

; ----- End  -----

Download(ByRef Clip)
{
		global cfg, sysp, lng, ShortFilename
		static FileName, FileDir, VideoLink, VideoID, PToken
	
		FileName	:= Clip.Name
		FileDir		:= Clip.Dir
		VideoLink	:= ""
		VideoID		:= Clip.VideoId
		PToken		:= Clip.PToken
		LastError	:= lng.ERR_CANNOT_GET_LINK
		
		VarSetCapacity(ShortFilename, 100)
		DllCall("shlwapi\PathCompactPathEx", "str", ShortFilename, "str", Filename, "uint", 50, "uint", 0)
		ShowTrayBalloon(ProgramName, lng.MSG_EXTRACTING_LINK . ShortFileName, cfg.BalloonShowTime, TIP_TYPE_INFO)
		SetTimer, GetLink, -250
	return	
	
	GetLink:
		global cfg, flg, lng, sysp
		
		SetTimer, GetLink, 10000
		if (flg.Busy) and (VideoLink = "")
		{
			gosub, LinkError
			Exit
		}
		
		flg.Busy := true
		if (!InStr(FileExist(FileDir), "D")) 
		{
			FileCreateDir, % FileDir
			if (ErrorLevel <> 0)
			{
				LastError := lng.ERR_WRONG_DIR_PATH . FileDir
				gosub, LinkError
				Exit
			}
		}
			
		ResCode := Rutuberu_GetVideoLink(VideoID, PToken, VideoLink)
		if (ResCode < 0)
		{
			if (ResCode = -1)
				LastError := lng.ERR_CANNOT_GET_LINK
			if (ResCode = -2)
				LastError := lng.ERR_NO_SUPPORT_RTMPS
			gosub, LinkError
		} else
		if (ResCode >= 0)
		{
			if (ResCode = 1)
			{
				if (FileExist(sysp.FilePHP) = "") or (FileExist(sysp.FileHDS) = "")
				{
					MsgBox, 36, % lng.ERR_TITLE_NO_HDS, % lng.ERR_TEXT_NO_HDS, 40
					IfMsgBox Yes
					{
						Derrors		:= 0
						ShowTrayBalloon()
						if (FileExist(sysp.File7z) = "")
							Derrors -= DownloadFile(sysp.Link7z, sysp.File7z, lng.MSG_DNLD_7Z)
						if (FileExist(sysp.DirBin "hds.7z") = "")
							Derrors -= DownloadFile(sysp.LinkHDS, sysp.DirBin "hds.7z", lng.MSG_DNLD_HDS_ARCH)
						ShowTrayBalloon(ProgramName, lng.MSG_UNPACKING_HDS, 5000, TIP_TYPE_INFO)
						Derrors -= Start(sysp.File7z " x -yro" CheckQuotes(sysp.DirBin) A_Space CheckQuotes(sysp.DirBin "hds.7z"))
						Sleep, 4000
						if (Derrors < 0)
						{
							LastError := lng.ERR_CANNOT_EXTRACT_HDS
							gosub, LinkError
							Exit
						}
					}
					else
					{
						LastError	:= lng.MSG_DNLD_CANCELED 
						gosub, LinkError
						Exit
					}
				}
			}
			if (flg.Busy) 
			{
				ShowTrayBalloon(ProgramName, lng.MSG_DOWNLOAD_STARTED, 5000, TIP_TYPE_INFO)
				if (Rutuberu_GetCmd(VideoLink, FileDir FileName, DownloadCmd) <> 0)
				{
					LastError := lng.ERR_CANNOT_START_DNLDR
					gosub, LinkError
				}
				debug("Command line:`r`n" DownloadCmd)
				if (Start(DownloadCmd, !cfg.AskOnNewLink, FileName) = 0)
				{
					SetTimer, GetLink, Off
					flg.Busy := False
					Exit
				} 
				else
				{
					LastError := lng.ERR_CANNOT_START_DNLDR
					gosub, LinkError
					Exit
				}
			}
		}		
		return

	LinkError:
		flg.Busy := False
		SetTimer, GetLink, Off
		ShowTrayBalloon(ProgramName, LastError, cfg.BalloonShowTime, TIP_TYPE_ERROR)
	return
}
return

HandleData(NewURL)
{
	global cfg, lng, flg
	
	Clip := {VideoId: "", PToken: "", Dir: "", Name: ""}
	
	if (RegExMatch(NewURL, cfg.RutubeExp, Match) <> 0)
		{
			ShowTrayBalloon(ProgramName, lng.MSG_EXTRACTING_INFO, cfg.BalloonShowTime-2000, TIP_TYPE_INFO)
			if (Rutuberu_GetVideoInfo(MatchTRACK_ID, Clip) = 0)
			{
				if (cfg.AskOnNewLink)
				{
					FileSelectFile, tmpSave, 19, % cfg.DirDownloads . Clip.Name, % lng.MSG_SAVE_VIDEO_AS, FLV/MP4 (*.flv; *.mp4)
					if (ErrorLevel <> 1)
					{
						SplitPath, tmpSave, tmpName, tmpDir
						Clip.Name := tmpName
						Clip.Dir := tmpDir
						Download(Clip)
					}
				} else
				{
					Clip.Dir := cfg.DirDownloads
					Clip.Name := Clip.Name
					debug("Name: " Clip.Name "`r`nDir: " Clip.Dir)
					Download(Clip)
				}
			} else
			{
				ShowTrayBalloon(ProgramName, lng.ERR_CANNOT_GET_INFO, cfg.BalloonShowTime-2000, TIP_TYPE_ERROR)
				Exit
			}
		}
			else
				return, -1
}

OnClipboardChange:
	global cfg, flg
	
	ClpData = %Clipboard%
	if (cfg.ClipboardMon) and (flg.ProgramLoaded) and (!flg.Busy) and (A_EventInfo = 1) and (StrLen(ClpData) <= cfg.ClpMaxTextLength)
		HandleData(ClpData)
return


; ----- Tray menu -----

CreateTrayMenu:
	Menu, Tray, Icon, % sysp.FileTrayIcon, 1, 1
	Menu, Tray, Tip, %ProgramName% %ProgramVersion%
	Menu, Tray, NoStandard
	Menu, Tray, Add, % lng.MENU_NEW_URL, NewURL
	Menu, Tray, Add
	Menu, Tray, Add, % lng.MENU_SET_DOWNLOAD_DIR, SetSaveDirectory
	Menu, Tray, Add
	Menu, VideoQSubMenu, Add, % lng.MENU_VIDEO_QUAL_LOW, VideoLQItem
	Menu, VideoQSubMenu, Add, % lng.MENU_VIDEO_QUAL_MEDIUM, VideoMQItem
	Menu, VideoQSubMenu, Add, % lng.MENU_VIDEO_QUAL_HIGH, VideoHQItem
	Menu, Tray, Add, % lng.MENU_VIDEO_SUBMENU, :VideoQSubMenu
	Menu, Tray, Add, % lng.MENU_CONFIRM_DOWNLOAD, ToggleAskOnNewLink
	Menu, Tray, Add, % lng.MENU_NOTIFY_ON, ToggleTrayBalloons
	;~ Menu, Tray, Add, % lng.MENU_LOGGING, ToggleLog
	Menu, Tray, Add, % lng.MENU_ENABLE_CLIPMON, ToggleClipMon
	Menu, Tray, Add, % lng.MENU_LOAD_ON_STARTUP, ToggleStartupWithSystem
	Menu, Tray, Add
	Menu, HelpSubMenu, Add, % lng.MENU_HELP_BUGREPORT, SendBugReport
	Menu, HelpSubMenu, Add, % lng.MENU_HELP_WEBSITE, OpenProgramPage
	Menu, HelpSubMenu, Add, % lng.MENU_HELP_MANUAL_LOAD, ManualLoadItem
	Menu, Tray, Add, % lng.MENU_HELP, :HelpSubMenu
	Menu, Tray, Add, % lng.MENU_EXIT, ApplicationClose
	Menu, Tray, Default, % lng.MENU_NEW_URL
	Menu, Tray, Click, 1
	
	if (cfg.AskOnNewLink)
		Menu, Tray, Check, % lng.MENU_CONFIRM_DOWNLOAD
	if (cfg.ShowBalloons)
		Menu, Tray, Check, % lng.MENU_NOTIFY_ON
	if (cfg.LogLevel > 0)
		Menu, Tray, Check, % lng.MENU_LOGGING
	if (cfg.VideoQuality = 3)
		Menu, VideoQSubMenu, Check, % lng.MENU_VIDEO_QUAL_HIGH
	else if (cfg.VideoQuality = 2)
		Menu, VideoQSubMenu, Check, % lng.MENU_VIDEO_QUAL_MEDIUM
	else if (cfg.VideoQuality = 1)
		Menu, VideoQSubMenu, Check, % lng.MENU_VIDEO_QUAL_LOW
	if (cfg.ClipboardMon)
		Menu, Tray, Check, % lng.MENU_ENABLE_CLIPMON
	RegRead, Tmp, HKCU, % sysp.RegRun, %ProgramName%
	if (cfg.Autorun) or (ErrorLevel = 0)
	{
		Menu, Tray, Check, % lng.MENU_LOAD_ON_STARTUP
		cfg.Autorun := 1
	}
return

VideoLQItem:
	cfg.VideoQuality := 1
	Menu, VideoQSubMenu, Check, % lng.MENU_VIDEO_QUAL_LOW
	Menu, VideoQSubMenu, UnCheck, % lng.MENU_VIDEO_QUAL_MEDIUM
	Menu, VideoQSubMenu, UnCheck, % lng.MENU_VIDEO_QUAL_HIGH
return

VideoMQItem:
	cfg.VideoQuality := 2
	Menu, VideoQSubMenu, Check, % lng.MENU_VIDEO_QUAL_MEDIUM
	Menu, VideoQSubMenu, UnCheck, % lng.MENU_VIDEO_QUAL_LOW
	Menu, VideoQSubMenu, UnCheck, % lng.MENU_VIDEO_QUAL_HIGH
return

VideoHQItem:
	cfg.VideoQuality := 3
	Menu, VideoQSubMenu, Check, % lng.MENU_VIDEO_QUAL_HIGH
	Menu, VideoQSubMenu, UnCheck, % lng.MENU_VIDEO_QUAL_MEDIUM
	Menu, VideoQSubMenu, UnCheck, % lng.MENU_VIDEO_QUAL_LOW
return

NewURL:
	NewLink := ""
	Gui +OwnDialogs 
	InputBox, NewLink, % lng.MENU_NEW_URL, %A_Space% ,,630,140,,,, 60,
	if (!ErrorLevel) and (NewLink <> "")
	{
		if (HandleData(NewLink) = -1)
			ShowTrayBalloon(ProgramName, lng.ERR_CANNOT_PARSE_URL, 3000, TIP_TYPE_WARNING)
	}
return

SetSaveDirectory:
	FileSelectFolder, SelectedDir, ::{20d04fe0-3aea-1069-a2d8-08002b30309d},, % lng.MSG_CHOOSE_DOWNLOAD_DIR
	if (ErrorLevel = 0)
	{
		if (InStr(FileExist(SelectedDir), "D"))
			cfg.DirDownloads := AddTrailingBackslash(SelectedDir)
	}				
return

ToggleAskOnNewLink:
	cfg.AskOnNewLink := (cfg.AskOnNewLink = true) ? false : true
	Menu, Tray, ToggleCheck, % lng.MENU_CONFIRM_DOWNLOAD
return

ToggleTrayBalloons:
	cfg.ShowBalloons := (cfg.ShowBalloons = true) ? false : true
	Menu, Tray, ToggleCheck, % lng.MENU_NOTIFY_ON
return

ToggleLog:
	LogLevel := (LogLevel = 1) ? 0 : 1
	Menu, Tray, ToggleCheck, % lng.MENU_LOGGING
return

ToggleClipMon:
	cfg.ClipboardMon := (cfg.ClipboardMon = 1) ? 0 : 1
	Menu, Tray, ToggleCheck, % lng.MENU_ENABLE_CLIPMON
return

ToggleStartupWithSystem:
	if (cfg.Autorun)
	{
		RegDelete, HKCU, % sysp.RegRun, % ProgramName
		cfg.Autorun := 0
	}
	else
	{
		RegWrite, REG_SZ, HKCU, % sysp.RegRun, % ProgramName, %A_ScriptFullPath%
		cfg.Autorun := 1
	}	
	Menu, Tray, ToggleCheck, % lng.MENU_LOAD_ON_STARTUP
return

ManualLoadItem:
	Run, "http://tradiz.org/Rutube/Skachivanie-s-rutuberu-po-rtmp-ssylkam#rtmpdump"
return

SendBugReport:
	Run, "http://bbs.tradiz.org/index.php?mode=posting&id=120"
return

OpenProgramPage:
	Run, "http://tradiz.org/Rutube/Raljeta"
return

; ----- End of tray menu -----

ApplicationClose:
	WriteProgramSettings()
	ExitApp, 0
return
