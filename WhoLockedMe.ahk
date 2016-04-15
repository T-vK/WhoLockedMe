; http://forums.codeguru.com/showthread.php?176997.html
; https://autohotkey.com/boards/viewtopic.php?p=80447
; Credits to HotkeyIt for the super complicated handle retrievement!
; Credits to jNizM for the neat QueryDosDevice function!
; Credits to "just me" for translating the whole script into AHK 1.1 and also for GetPathNameByHandle and GetIconByPath!
; If I forgot to put *your* name into this list, tell me please!

#NoEnv
SetBatchLines, -1
RunAsAdmin()
LoadLibraries()
EnablePrivilege()
File := FileOpen(A_ScriptFullPath, "r") ; cause this script to appear in the list
; ==================================================================================================================================
Gui, Add, Edit, w640 r1 gGUI_FileLockTabCtrlEvt vGui_Filter
Gui, Add, ListView, w640 r30 gGUI_FileLockTabCtrlEvt vFileLockLV +LV0x00000400, Potentially locked|By|PID
LV_ModifyCol(1,419), LV_ModifyCol(2,150), LV_ModifyCol(3,50)
Gui, Add, Button, w640 gGUI_FileLockTabCtrlEvt vGUI_Reload, Reload
Gui, Add, Button, w640 gGUI_FileLockTabCtrlEvt vGUI_CloseHandle, Close Handle
Gui, Add, Button, w640 gGUI_FileLockTabCtrlEvt vGUI_CloseProcess, Close Process
Gui, Add, Progress, w640 vGui_Progress
Gui, Show,, WhoLockedMe

GUI_FileLockTabCtrlEvt("Gui_Reload")

; ==================================================================================================================================
GuiClose(Hwnd){
    ExitApp
}
; ==================================================================================================================================
GUI_FileLockTabCtrlEvt(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {
   Static DataArray := []
   Static IconObject := {}
   Static ImageListID := 0
   If (A_DefaultListView != "FileLockLV")
      Gui, ListView, FileLockLV
   GuiControlGet, ControlName, Name, %CtrlHwnd%
   If (ControlName = "Gui_Filter") {
      GuiControlGet, Gui_Filter
      LV_Delete()
      GuiControl, -Redraw, FileLockLV
      Loop % DataArray.Length() {
         Data := DataArray[A_Index]
         FilePath := Data.FilePath ? Data.FilePath : Data.DevicePath
         If (InStr(FilePath, Gui_Filter))
            LV_Add("Icon" Data.IconIndex, FilePath, Data.ProcName, Data.PID)
      }
      GuiControl, +Redraw, FileLockLV
   } Else If (ControlName = "GUI_Reload") {
      LV_Delete()
      If (ImageListID)
         IL_Destroy(ImageListID)
      ImageListID := IL_Create(1000, 100)
      LV_SetImageList(ImageListID)
      Callback := Func("FileHandleCallback")
      DataArray := GetAllFileHandleInfo(Callback)
      GuiControl, , Gui_Progress, 0
      DataArrayCount := DataArray.MaxIndex()
      Loop % DataArrayCount {
         GuiControl, , Gui_Progress, % A_Index/DataArrayCount*100
         Data := DataArray[A_Index]
         IconObjectId := Data.Exists ? Data.FilePath : "\\DELETED"
         If IconObject[IconObjectId]
            DataArray[A_Index].IconIndex := IconObject[IconObjectId]
         Else
            IconObject[IconObjectId] :=  DataArray[A_Index].IconIndex := IL_Add(ImageListID, "HICON:" . GetIconByPath(Data.FilePath), Data.FileExists)
      }
      GUI_FileLockTabCtrlEvt("Gui_Filter")
   } Else If (ControlName = "GUI_CloseHandle") {
      Msgbox, Not implemented yet! I'm working on it.
   } Else If (ControlName = "GUI_CloseProcess") {
      Msgbox, Not implemented yet! I'm working on it.
   }
}
; ==================================================================================================================================
FileHandleCallback(PercentDone) {
   GuiControl, , Gui_Progress, %PercentDone%
}
; ==================================================================================================================================
GetAllFileHandleInfo(Callback:="") {
   Static hCurrentProc := DllCall("GetCurrentProcess", "UPtr")
   DataArray := []
   If !(SHI := QuerySystemHandleInformation()) {
      MsgBox, 16, Error!, % "Couldn't get SYSTEM_HANDLE_INFORMATION`nLast Error: " . Format("0x{:08X}", ErrorLevel)
      Return False
   }
   HandleCount := SHI.Count
   Loop %HandleCount% {
      ; PROCESS_DUP_HANDLE = 0x40, PROCESS_QUERY_INFORMATION = 0x400
      If !(hProc := DllCall("OpenProcess", "UInt", 0x0440, "UInt", 0, "UInt", SHI[A_Index, "PID"], "UPtr"))
         Continue
      ; DUPLICATE_SAME_ATTRIBUTES = 0x04 (4)
      If !(hObject := DuplicateObject(hProc, hCurrentProc, SHI[A_Index, "Handle"], 4)) {
         DllCall("CloseHandle", "Ptr", hProc)
         Continue
      }
      If (OBI := QueryObjectBasicInformation(hObject))
      && (OTI := QueryObjectTypeInformation(hObject))
      && (OTI.Type = "File")
      && (DllCall("GetFileType", "Ptr", hObject, "UInt") = 1)
      && (ONI := QueryObjectNameInformation(hObject)) {
         VarSetCapacity(ProcFullPath, 520, 0)
         DllCall("QueryFullProcessImageName", "Ptr", hProc, "UInt", 0, "Str", ProcFullPath, "UIntP", sz := 260)
         FilePath := GetPathNameByHandle(hObject)
         Data := {}
         Data.ProcFullPath := ProcFullPath
         Data.PID := SHI[A_Index].PID
         Data.Handle := SHI[A_Index].Handle
         Data.GrantedAccess := SHI[A_Index].Access
         Data.Flags := SHI[A_Index].Flags
         Data.Attributes := OBI.Attr
         Data.HandleCount := (OBI.Handles - 1)
         Data.DevicePath := ONI.Name
         Data.FilePath := FilePath
         Data.Drive := SubStr(FilePath, 1, 1)
         FileExists := FileExist(FilePath)
         Data.Exists := FileExists ? True : False
         Data.Isfolder := InStr(FileExists, "D") ? True : False
         SplitPath, ProcFullPath, ProcName
         Data.ProcName := ProcName
      
         ProgressInPercent := A_Index/HandleCount*100
         If Callback
            Callback.Call(ProgressInPercent)
         
         DataArray.Push(Data)
      }
      DllCall("CloseHandle", "Ptr", hObject)
      DllCall("CloseHandle", "Ptr", hProc)
   }
   If Callback
      Callback.Call(100)
   Return DataArray
}
; ==================================================================================================================================
RunAsAdmin() {
   If !(A_IsAdmin) {
      Run % "*RunAs " . (A_IsCompiled ? "" : A_AhkPath . " ") . """" . A_ScriptFullPath . """"
      ExitApp
   }
}
; ==================================================================================================================================
LoadLibraries() {
   DllCall("LoadLibrary", "Str", "Advapi32.dll", "UPtr")
   DllCall("LoadLibrary", "Str", "Ntdll.dll", "UPtr")
   DllCall("LoadLibrary", "Str", "Shell32.dll", "UPtr")
}
; ==================================================================================================================================
EnablePrivilege(Name := "SeDebugPrivilege") {
   hProc := DllCall("GetCurrentProcess", "UPtr")
   If DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", Name, "Int64P", LUID := 0, "UInt")
   && DllCall("Advapi32.dll\OpenProcessToken", "Ptr", hProc, "UInt", 32, "PtrP", hToken := 0, "UInt") { ; TOKEN_ADJUST_PRIVILEGES = 32
      VarSetCapacity(TP, 16, 0) ; TOKEN_PRIVILEGES
      , NumPut(1, TP, "UInt")
      , NumPut(LUID, TP, 4, "UInt64")
      , NumPut(2, TP, 12, "UInt") ; SE_PRIVILEGE_ENABLED = 2
      , DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", hToken, "UInt", 0, "Ptr", &TP, "UInt", 0, "Ptr", 0, "Ptr", 0, "UInt")
   }
   LastError := A_LastError
   If (hToken)
      DllCall("CloseHandle", "Ptr", hToken)
   Return !(ErrorLevel := LastError)
}
; ==================================================================================================================================
GetPathNameByHandle(hFile) {
   VarSetCapacity(FilePath, 4096, 0)
   DllCall("GetFinalPathNameByHandle", "Ptr", hFile, "Str", FilePath, "UInt", 2048, "UInt", 0, "UInt")
   Return SubStr(FilePath, 1, 4) = "\\?\" ? SubStr(FilePath, 5) : FilePath
}
; ==================================================================================================================================
GetIconByPath(Path, FileExists:="") { ; fully qualified file path, result of FileExist on Path (optional)
   ; SHGetFileInfo  -> http://msdn.microsoft.com/en-us/library/bb762179(v=vs.85).aspx
   Static AW := A_IsUnicode ? "W" : "A"
   Static cbSFI := A_PtrSize + 8 + (340 << !!A_IsUnicode)
   Static IconType := 2
   FileExists := FileExists ? FileExists : FileExist(Path)
   If (FileExists) {
      SplitPath, Path, , , FileExt
      If (InStr(FileExists, "D") || FileExt = "exe" || FileExt = "ico") {
         pszPath := Path
         dwFileAttributes := 0x00
         uFlags := 0x0101
      } Else {
         pszPath := FileExt ? "." FileExt : ""
         dwFileAttributes := 0x80
         uFlags := 0x0111
      }
   } Else ; If the file is deleted reutrn an appropriate icon. 
      Return LoadPicture(A_WinDir "\System32\imageres.dll", "Icon85 w16 h16", IconType) ; TODO: find a way to retrieve the icon just once and return it everytime it is needed
   
   VarSetCapacity(SFI, cbSFI, 0) ; SHFILEINFO
   DllCall("Shell32.dll\SHGetFileInfo" . AW, "Str", pszPath, "UInt", dwFileAttributes, "Ptr", &SFI, "UInt", cbSFI, "UInt", uFlags, "UInt")
   Return NumGet(SFI, 0, "UPtr")
}
; ==================================================================================================================================
DuplicateObject(hProc, hCurrentProc, Handle, Options) {
   ; PROCESS_DUP_HANDLE = 0x40, PROCESS_QUERY_INFORMATION = 0x400, DUPLICATE_SAME_ATTRIBUTES = 0x04 (4)
   Status := DllCall("Ntdll.dll\ZwDuplicateObject", "Ptr", hProc
                                                  , "Ptr", Handle
                                                  , "Ptr", hCurrentProc
                                                  , "PtrP", hObject
                                                  , "UInt", 0
                                                  , "UInt", 0
                                                  , "UInt", Options
                                                  , "UInt")
   Return (Status) ? !(ErrorLevel := Status) : hObject
}
; ==================================================================================================================================
QueryObjectBasicInformation(hObject) {
   ; ObjectBasicInformation = 0, STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
   Static Size := 56 ; size of OBJECT_BASIC_INFORMATION
   VarSetCapacity(OBI, Size, 0)
   Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 0, "Ptr", &OBI, "UInt", Size, "UIntP", L, "UInt")
   If (Status = 0xC0000004) {
      VarSetCapacity(OBI, L)
      Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 0, "Ptr", &OBI, "UInt", L, "Ptr", 0, "UInt")
   }
   Return (Status) ? !(ErrorLevel := Status)
                   : {Attr: NumGet(OBI, 0, "UInt")
                     , Access: NumGet(OBI, 4, "UInt")
                     , Handles: NumGet(OBI, 8, "UInt")
                     , Pointers: NumGet(OBI, 12, "UInt")}
}
; ==================================================================================================================================
QueryObjectTypeInformation(hObject, Size := 4096) {
   ; ObjectTypeInformation = 2, STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
   VarSetCapacity(OTI, Size, 0)
   Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 2, "Ptr", &OTI, "UInt", Size, "UIntP", L, "UInt")
   If (Status = 0xC0000004) {
      VarSetCapacity(OTI, L)
      Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 2, "Ptr", &OTI, "UInt", L, "Ptr", 0, "UInt")
   }
   Return (Status) ? !(ErrorLevel := Status)
                   : {Type: StrGet(NumGet(OTI, A_PtrSize, "UPtr"), NumGet(OTI, 0, "UShort") // 2, "UTF-16")}
}
; ==================================================================================================================================
QueryObjectNameInformation(hobject, Size := 4096) {
   ; ObjectNameInformation = 1, STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
   VarSetCapacity(ONI, Size, 0)
   Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 1, "Ptr", &ONI, "UInt", Size, "UIntP", L, "UInt")
   If (Status = 0xc0000004) {
      VarSetCapacity(ONI, L)
      Status := DllCall("Ntdll.dll\ZwQueryObject", "Ptr", hObject, "UInt", 1, "Ptr", &ONI, "UInt", L, "Ptr", 0, "UInt")
   }
   Return (Status) ? !(ErrorLevel := Status)
                   : {Name: StrGet(NumGet(ONI, A_PtrSize, "UPtr"), NumGet(ONI, 0, "UShort") // 2, "UTF-16")}
}
; ==================================================================================================================================
QuerySystemHandleInformation() {
   ; SystemHandleInformation = 16, STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
   Static SizeSH := 8 + (A_PtrSize * 2)
   Static Size := A_PtrSize * 4096
   VarSetCapacity(SHI, Size)
   Status := DllCall("Ntdll.dll\NtQuerySystemInformation", "UInt", 16, "Ptr", &SHI, "UInt", Size, "UIntP", L, "UInt")
   While (Status = 0xc0000004) {
      VarSetCapacity(SHI, L)
      Status := DllCall("Ntdll.dll\NtQuerySystemInformation", "UInt", 16, "Ptr", &SHI, "UInt", L, "UIntP", L, "UInt")
   }
   If (Status)
      Return !(ErrorLevel := Status)
   HandleCount := NumGet(SHI, "UInt")
   ObjSHI := {Count: HandleCount}
   Addr := &SHI + A_PtrSize
   Loop, %HandleCount% {
      ObjSHI.Push({PID: NumGet(Addr + 0, "UInt")
                 , Type: NumGet(Addr + 4, "UChar")
                 , Flags: NumGet(Addr + 5, "UChar")
                 , Handle: NumGet(Addr + 6, "UShort")
                 , Addr: NumGet(Addr + 8, "UPtr")
                 , Access: NumGet(Addr + 8, A_PtrSize, "UInt")})
      Addr += SizeSH
   }
   Return ObjSHI
}