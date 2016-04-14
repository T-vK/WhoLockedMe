; http://forums.codeguru.com/showthread.php?176997.html
; https://autohotkey.com/boards/viewtopic.php?p=80447
; Credits to HotkeyIt for the super complicated handle retrievement!
; Credits to jNizM for the neat QueryDosDevice function!
; Credits to Lexikos and "just me" for the GetIconGroupNameByIndex function!
; Credits to "just me" for translating the whole script into AHK 1.1!

#NoEnv
SetBatchLines, -1
RunAsAdmin()
LoadLibraries()
EnablePrivilege()
File := FileOpen(A_ScriptFullPath, "r") ; cause this script to appear in the list
; ==================================================================================================================================
Gui, Add, Edit, w640 r1 gGui_FilterList vGui_Filter
Gui, Add, ListView, w640 r30 vFilesLV +LV0x00000400, Potentially locked|By
LV_ModifyCol(1,300)
LV_ModifyCol(2,300)
Gui, Add, Button, w640 gGui_Reload, Reload
Gui, Add, Progress, w640 vGui_Progress
Gui, Show,, WhoLockedMe

Gui_Reload()

; ==================================================================================================================================
Gui_FilterList(ctrlHwnd:="", guiEvent:="", eventInfo:="", errLvl:=0) {
   Global DataArray
   GuiControlGet, Gui_Filter
   LV_Delete()
   GuiControl, -Redraw, FilesLV
   Loop % DataArray.Length() {
      Data := DataArray[A_Index]
      FilePath := Data.FilePath ? Data.FilePath : Data.DevicePath
      If (InStr(FilePath, Gui_Filter))
         LV_Add("Icon" . Data.Icon, FilePath, Data.ProcFullPath)
   }
   GuiControl, +Redraw, FilesLV
}
; ==================================================================================================================================
Gui_Reload() {
   Static ImageListID := 0
   Static hCurrentProc := DllCall("GetCurrentProcess", "UPtr")
   Global DataArray ; let's make life as easy as needed
   DataArray := []
   LV_Delete()
   If (ImageListID)
      IL_Destroy(ImageListId)
   ExtIcons := []
   ImageListID := IL_Create(1000, 100)
   IL_Add(ImageListID, "imageres.dll", 3) ; icon 1 = default
   IL_Add(ImageListID, "shell32.dll", 5)  ; icon 2 = folder
   IL_Add(ImageListID, "shell32.dll", 12)  ; icon 2 = exe default
   LV_SetImageList(ImageListID)
   GuiControl, , Gui_Progress, 0
   If !(SHI := QuerySystemHandleInformation()) {
      MsgBox, 16, Error!, % "Couldn't get SYSTEM_HANDLE_INFORMATION`nLast Error: " . Format("0x{:08X}", ErrorLevel)
      Return False
   }
   HandleCount := SHI.Count
   Loop %HandleCount% {
      GuiControl, , Gui_Progress, % A_Index/HandleCount*100
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
         VarSetCapacity(ProcName, 520, 0)
         DllCall("QueryFullProcessImageName", "Ptr", hProc, "UInt", 0, "Str", ProcName, "UIntP", sz := 260)
         FilePath := GetPathNameByHandle(hObject)
         Data := {}
         Data.ProcFullPath := ProcName
         Data.PID := SHI[A_Index].PID
         Data.Handle := SHI[A_Index].Handle
         Data.GrantedAccess := SHI[A_Index].Access
         Data.Flags := SHI[A_Index].Flags
         Data.Attributes := OBI.Attr
         Data.HandleCount := (OBI.Handles - 1)
         Data.DevicePath := ONI.Name
         Data.FilePath := FilePath
         Data.Drive := SubStr(FilePath, 1, 1)
         Data.Isfolder := InStr(FileExist(Data.FilePath), "D") ? True : False
         SplitPath, FilePath, , , FileExt
         If (Data.Isfolder)
            Data.Icon := 2
         Else If (FileExt = "exe") {
            If GetIconGroupNameByIndex(Data.FilePath, 1)
               Data.Icon := IL_Add(ImageListID, Data.FilePath, 0)
            Else
               Data.Icon := IL_Add(ImageListID, "imageres.dll", 12)
         }
         Else If (FileExt) {
            If ExtIcons[FileExt]
               Data.Icon := ExtIcons[FileExt]
            Else {
               icon := GetIconByExt(FileExt)
               If (icon.file)
                  ExtIcons[FileExt] := Data.Icon := IL_Add(ImageListID, icon.file, icon.index)
               Else
                  Data.Icon := 1
            }
         } Else
            Data.Icon := 1
         DataArray.Push(Data)
      }
      DllCall("CloseHandle", "Ptr", hObject)
      DllCall("CloseHandle", "Ptr", hProc)
   }
   Gui_FilterList()
}
; ==================================================================================================================================
GuiClose(hwnd){
    ExitApp
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
;GetIconByExt(Ext) { ; pass the extension without the leading dot
;   ; SHGetFileInfo  -> http://msdn.microsoft.com/en-us/library/bb762179(v=vs.85).aspx
;   Static AW := A_IsUnicode ? "W" : "A"
;   Static cbSFI := A_PtrSize + 8 + (340 << !!A_IsUnicode)
;   VarSetCapacity(SFI, cbSFI, 0) ; SHFILEINFO
;   DllCall("Shell32.dll\SHGetFileInfo" . AW, "Str", "." . Ext, "UInt", 0x80, "Ptr", &SFI, "UInt", cbSFI, "UInt", 0x0111, "UInt")
;   Return NumGet(SFI, 0, "UPtr")
;}
GetIconByExt(ext) {
   RegRead, from, % "HKEY_CLASSES_ROOT\." ext
   RegRead, defaultIcon, % "HKEY_CLASSES_ROOT\" from "\DefaultIcon"
   defaultIcon := StrReplace(defaultIcon, """", "")
   defaultIcon := StrReplace(defaultIcon, "`%SystemRoot`%", A_WinDir)
   defaultIcon := StrReplace(defaultIcon, "`%ProgramFiles`%", A_ProgramFiles)
   defaultIcon := StrReplace(defaultIcon, "`%windir`%", A_WinDir)
   defaultIconSplit := StrSplit(defaultIcon,",")
   resFile := defaultIconSplit[1]
   index := defaultIconSplit[2]
   ;index := (index < 0 ? abs(index)-4 : index)
   Return {file: resFile, index: index}
}
; ==================================================================================================================================
GetIconGroupNameByIndex(FilePath, Index, NamePtr := "", Param := "") {
   ; Credits to lexikos and "just me" for that function
   ; https://autohotkey.com/boards/viewtopic.php?p=49057#p49057
   Static EnumProc := RegisterCallback("GetIconGroupNameByIndex", "F", 4)
   Static EnumCall := A_TickCount
   Static EnumCount := 0
   Static GroupIndex := 0
   Static GroupName := ""
   Static Loaded := 0
   ; ----------------------------------------------------------------------------------------------
   If (Param = EnumCall) { ; called by EnumResourceNames
      EnumCount++
      If (EnumCount = GroupIndex) {
         If ((NamePtr & 0xFFFF) = NamePtr)
            GroupName := NamePtr
         Else
            GroupName := StrGet(NamePtr)
         Return False
      }
      Return True
   }
   ; ----------------------------------------------------------------------------------------------
   EnumCount := 0
   GroupIndex := Index
   GroupName := ""
   Loaded := 0
   If !(HMOD := DllCall("GetModuleHandle", "Str", FilePath, "UPtr")) {
      If (HMOD := DllCall("LoadLibraryEx", "Str", FilePath, "Ptr", 0, "UInt", 0x02, "UPtr"))
         Loaded := HMOD
      Else
         Return ""
   }
   DllCall("EnumResourceNames", "Ptr", HMOD, "Ptr", 14, "Ptr", EnumProc, "Ptr", EnumCall)
   If (Loaded)
      DllCall("FreeLibrary", "Ptr", Loaded)
   Return GroupName
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