;#### Credits
; * Credits to HotkeyIt for the super complicated handle retrievement!
; * Credits to "just me" for translating all the handle retrievement stuff into AHK 1.1 and also for GetPathNameByHandle and GetIconByPath and other valuable info about icons in AHK and File System Redirection!
; * Credits to jNizM for a lot of valuable input and research, QueryDosDevice and fine-tuning of GetExtendedTcpTable and GetProcessFilePath!
; * If your name, someone elses name or anything else is missing from this list, tell me please!
; 
;#### Links
; * [Development topic on autohotkey.com](https://autohotkey.com/boards/viewtopic.php?p=80447)
; * [Release topic on autohotkey.com](https://autohotkey.com/boards/viewtopic.php?p=80455)
; * [The C++ code that has been translated to AHK code for the handle retrievement](http://forums.codeguru.com/showthread.php?176997.html)

#NoEnv
SetBatchLines, -1
RunAsAdmin()
LoadLibraries()
EnablePrivilege()
If (A_Is64bitOS && (A_PtrSize = 4))
    DllCall("Wow64DisableWow64FsRedirection", "UInt*", OldValue)
File := FileOpen(A_ScriptFullPath, "r") ; cause this script to appear in the list
; ==================================================================================================================================
Gui, Add, Tab2, w644 h627, File Handles|Network Ports
Gui, Tab, 1
    Gui, Add, Edit, w620 r1 gGui_FileHandles_CtrlEvt vGui_FileHandles_ApplyFilter
    Gui, Add, ListView, w620 r25 gGui_FileHandles_CtrlEvt vGui_FileHandles_LV +LV0x00000400, Potentially locked|By|PID|Handle
    LV_ModifyCol(1,349), LV_ModifyCol(2,150), LV_ModifyCol(3,50), LV_ModifyCol(4,50)
    Gui, Add, Button, w620 gGui_FileHandles_CtrlEvt vGui_FileHandles_ReloadData, Reload
    Gui, Add, Button, w620 gGui_FileHandles_CtrlEvt vGui_FileHandles_CloseHandle, Close Handle
    Gui, Add, Button, w620 gGui_FileHandles_CtrlEvt vGui_FileHandles_CloseProcess, Close Process
    Gui, Add, Progress, w620 vGui_FileHandles_ProgressBar
Gui, Tab, 2
    Gui, Add, Edit, w620 r1 gGui_NetworkPorts_CtrlEvt vGui_NetworkPorts_ApplyFilter
    Gui, Add, ListView, w620 r25 gGui_NetworkPorts_CtrlEvt vGui_NetworkPorts_LV +LV0x00000400, Port blocked|By|PID
    LV_ModifyCol(1,80), LV_ModifyCol(2,200), LV_ModifyCol(3,50)
    ; TODO: Add columns for remote port and IP addresses
    Gui, Add, Button, w620 gGui_NetworkPorts_CtrlEvt vGui_NetworkPorts_ReloadData, Reload
    Gui, Add, Button, w620 gGui_NetworkPorts_CtrlEvt vGui_NetworkPorts_ReleasePort, Release Port
    Gui, Add, Button, w620 gGui_NetworkPorts_CtrlEvt vGui_NetworkPorts_CloseProcess, Close Process
    Gui, Add, Progress, w620 vGui_NetworkPorts_ProgressBar
Gui, Show,, WhoLockedMe

Gui_FileHandles_CtrlEvt("Gui_FileHandles_ReloadData")
Gui_NetworkPorts_CtrlEvt("Gui_NetworkPorts_ReloadData")


; ==================================================================================================================================
Gui_NetworkPorts_CtrlEvt(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {
    Static DataArray := []
    Static IconObject := {}
    Static ImageListID := 0
    If (A_DefaultListView != "Gui_NetworkPorts_LV")
        Gui, ListView, Gui_NetworkPorts_LV
    GuiControlGet, ControlName, Name, %CtrlHwnd%
    If (ControlName = "Gui_NetworkPorts_ApplyFilter") {
        GuiControlGet, Gui_NetworkPorts_ApplyFilter
        LV_Delete()
        GuiControl, -Redraw, Gui_NetworkPorts_LV
        Loop % DataArray.Length() {
            Data := DataArray[A_Index]
            Port := Data.LocalPort
            If (InStr(Port, Gui_NetworkPorts_ApplyFilter))
                LV_Add("Icon" Data.IconIndex, Data.LocalPort, Data.ProcName, Data.PID)
        }
        GuiControl, +Redraw, Gui_NetworkPorts_LV
    } Else If (ControlName = "Gui_NetworkPorts_ReloadData") {
        LV_Delete()
        If (ImageListID)
            IL_Destroy(ImageListID)
        ImageListID := IL_Create(100, 10)
        LV_SetImageList(ImageListID)
        GuiControl, , Gui_NetworkPorts_ProgressBar, 0
        DataArray := GetExtendedTcpTable()
        DataArrayCount := DataArray.Length()
        Loop % DataArrayCount {
            GuiControl, , Gui_NetworkPorts_ProgressBar, % A_Index/DataArrayCount*100
            
            DataArray[A_Index].PID := DataArray[A_Index].OwningPid
            If (DataArray[A_Index].PID = 0)
                DataArray[A_Index].ProcName := "[System Process]"
            Else If (DataArray[A_Index].PID = 4)
                DataArray[A_Index].ProcName := "System"
            Else {
                DataArray[A_Index].FilePath := GetProcessFilePathByPID(DataArray[A_Index].PID)
                SplitPath, % DataArray[A_Index].FilePath, ProcessName
                If !ProcessName
                     WinGet, ProcessName, ProcessName, % "ahk_pid " DataArray[A_Index].PID
                ; TODO: find out why that's still not enough to get them all
                DataArray[A_Index].ProcName := ProcessName
                DataArray[A_Index].Exists := FileExist(DataArray[A_Index].FilePath)
            }
            
            Data := DataArray[A_Index]
            IconObjectId := Data.Exists ? Data.FilePath : "\\DELETED"
            If IconObject[IconObjectId]
                DataArray[A_Index].IconIndex := IconObject[IconObjectId]
            Else
                IconObject[IconObjectId] := DataArray[A_Index].IconIndex := IL_Add(ImageListID, "HICON:" . GetIconByPath(Data.FilePath, Data.FileExists))
        }
        Gui_NetworkPorts_CtrlEvt("Gui_NetworkPorts_ApplyFilter")
    } Else If (ControlName = "Gui_NetworkPorts_ReleasePort") {
        ;RowNumber := 0
        ;Loop {
        ;    RowNumber := LV_GetNext(RowNumber)
        ;    If !RowNumber
        ;         Break
        ;    LV_GetText(Port, RowNumber, 1)
        ;    LV_GetText(PID, RowNumber, 3)
        ;    
        ;    If PortClosed {
        ;        LV_GetText(Name, RowNumber, 2)
        ;        MsgBox, Error: Unable to release port %Port% used by %Name% (PID: %PID%)!
        ;    } Else {
        ;        i := 1
        ;        Loop % DataArray.Length() {
        ;            If (DataArray[i].Handle = Handle)
        ;                DataArray.RemoveAt(i)
        ;            Else
        ;                i++
        ;        }
        ;    }
        ;}
        ;Gui_NetworkPorts_CtrlEvt("Gui_NetworkPorts_ApplyFilter")
        MsgBox, Not implemented yet!
    } Else If (ControlName = "Gui_NetworkPorts_CloseProcess") {
        RowNumber := 0
        Loop {
            RowNumber := LV_GetNext(RowNumber)
            If !RowNumber
                 Break
            LV_GetText(PID, RowNumber, 3)
            Process, Close, %PID%
            ;Process, WaitClose, %PID%, 5 ;wait up to 5 secs until process closes
            ;If ErrorLevel {
            ;    LV_GetText(Name, RowNumber, 2)
            ;    MsgBox, Error: Unable to close %Name% (PID: %PID%)!
            ;Else {
                i := 1
                Loop % DataArray.Length() {
                    If (DataArray[i].PID = PID)
                        DataArray.RemoveAt(i)
                    Else
                        i++
                }
            ;}
        }
        Gui_NetworkPorts_CtrlEvt("Gui_NetworkPorts_ApplyFilter")
    }
}
; ==================================================================================================================================
Gui_FileHandles_CtrlEvt(CtrlHwnd:=0, GuiEvent:="", EventInfo:="", ErrLvl:="") {
    Static DataArray := []
    Static IconObject := {}
    Static ImageListID := 0
    If (A_DefaultListView != "Gui_FileHandles_LV")
        Gui, ListView, Gui_FileHandles_LV
    GuiControlGet, ControlName, Name, %CtrlHwnd%
    If (ControlName = "Gui_FileHandles_ApplyFilter") {
        GuiControlGet, Gui_FileHandles_ApplyFilter
        LV_Delete()
        GuiControl, -Redraw, Gui_FileHandles_LV
        Loop % DataArray.Length() {
            Data := DataArray[A_Index]
            FilePath := Data.FilePath ? Data.FilePath : Data.DevicePath
            If (InStr(FilePath, Gui_FileHandles_ApplyFilter))
                LV_Add("Icon" Data.IconIndex, FilePath, Data.ProcName, Data.PID, Data.Handle)
        }
        GuiControl, +Redraw, Gui_FileHandles_LV
    } Else If (ControlName = "Gui_FileHandles_ReloadData") {
        LV_Delete()
        If (ImageListID)
            IL_Destroy(ImageListID)
        ImageListID := IL_Create(1000, 100)
        LV_SetImageList(ImageListID)
        Callback := Func("FileHandleCallback")
        DataArray := GetAllFileHandleInfo(Callback)
        GuiControl, , Gui_FileHandles_ProgressBar, 0
        DataArrayCount := DataArray.Length()
        Loop % DataArrayCount {
            GuiControl, , Gui_FileHandles_ProgressBar, % A_Index/DataArrayCount*100
            Data := DataArray[A_Index]
            IconObjectId := Data.Exists ? Data.FilePath : "\\DELETED"
            If IconObject[IconObjectId]
                DataArray[A_Index].IconIndex := IconObject[IconObjectId]
            Else
                IconObject[IconObjectId] :=  DataArray[A_Index].IconIndex := IL_Add(ImageListID, "HICON:" . GetIconByPath(Data.FilePath, Data.FileExists))
        }
        Gui_FileHandles_CtrlEvt("Gui_FileHandles_ApplyFilter")
    } Else If (ControlName = "Gui_FileHandles_CloseHandle") {
        RowNumber := 0
        Loop {
            RowNumber := LV_GetNext(RowNumber)
            If !RowNumber
                 Break
            LV_GetText(Handle, RowNumber, 4)
            LV_GetText(PID, RowNumber, 3)
            
            ProcHandle := OpenProcess(PID, 0x40)
            HandleClosed := DuplicateObject(ProcHandle, 0, Handle, 0x1) ; Close handle
            
            If HandleClosed {
                LV_GetText(Path, RowNumber, 1)
                LV_GetText(Name, RowNumber, 2)
                MsgBox, Error: Unable to close %Name%'s (PID: %PID%) handle on "%Path%"!
            } Else {
                i := 1
                Loop % DataArray.Length() {
                    If (DataArray[i].Handle = Handle)
                        DataArray.RemoveAt(i)
                    Else
                        i++
                }
            }
        }
        Gui_FileHandles_CtrlEvt("Gui_FileHandles_ApplyFilter")
    } Else If (ControlName = "Gui_FileHandles_CloseProcess") {
        RowNumber := 0
        Loop {
            RowNumber := LV_GetNext(RowNumber)
            If !RowNumber
                Break
            LV_GetText(PID, RowNumber, 3)
            Process, Close, %PID%
            ;Process, WaitClose, %PID%, 5 ;wait up to 5 secs until process closes
            ;If ErrorLevel {
            ;    LV_GetText(Name, RowNumber, 2)
            ;    MsgBox, Error: Unable to close %Name% (PID: %PID%)!
            ;Else {
                i := 1
                Loop % DataArray.Length() {
                    If (DataArray[i].PID = PID)
                        DataArray.RemoveAt(i)
                    Else
                        i++
                }
            ;}
        }
        Gui_FileHandles_CtrlEvt("Gui_FileHandles_ApplyFilter")
    }
}
; ==================================================================================================================================
FileHandleCallback(PercentDone) {
    GuiControl, , Gui_FileHandles_ProgressBar, %PercentDone%
}
; ==================================================================================================================================
LoadLibraries() {
    DllCall("LoadLibrary", "Str", "Advapi32.dll", "UPtr")
    DllCall("LoadLibrary", "Str", "Ntdll.dll", "UPtr")
    DllCall("LoadLibrary", "Str", "Shell32.dll", "UPtr")
    DllCall("LoadLibrary", "Str", "Iphlpapi.dll", "UPtr")
    DllCall("LoadLibrary", "Str", "psapi.dll", "UPtr")
}
; ==================================================================================================================================
GuiClose(Hwnd){
    ExitApp
}

; ==================================================================================================================================
; General functions that can simply be used in other scripts =======================================================================
; ==================================================================================================================================
GetProcessFilePath(hProcess) {
    nSize := VarSetCapacity(lpFilename, 260 * (A_IsUnicode ? 2 : 1), 0)
    If !(DllCall("GetModuleFileNameEx", "Ptr", hProcess, "Ptr", 0, "Str", lpFilename, "UInt", nSize))
        If !(DllCall("psapi.dll\GetModuleFileNameEx", "Ptr", hProcess, "Ptr", 0, "Str", lpFilename, "UInt", nSize))
            Return (ErrorLevel := 2) & 0
    Return lpFilename
}
; ==================================================================================================================================
GetProcessFilePathByPID(PID) {
    If !(hProcess := DllCall("OpenProcess", "UInt", 0x10|0x400, "Int", 0, "UInt", PID, "UPtr"))
        Return (ErrorLevel := 1) & 0
    lpFilename := GetProcessFilePath(hProcess)
    DllCall("CloseHandle", "Ptr", hProcess)
    Return lpFilename
}
; ==================================================================================================================================
GetExtendedTcpTable() {
    ; https://msdn.microsoft.com/en-us/library/aa365928.aspx
    Static AF_INET := 2, TCP_TABLE_OWNER_PID_ALL := 5
    DllCall("Iphlpapi.dll\GetExtendedTcpTable", "Ptr", 0, "UInt*", pdwSize, "Int", 0, "UInt", AF_INET, "UInt", TCP_TABLE_OWNER_PID_ALL, "UInt", 0)
    VarSetCapacity(pTcpTable, pdwSize, 0)
    If (DllCall("Iphlpapi.dll\GetExtendedTcpTable", "Ptr", &pTcpTable, "UInt*", pdwSize, "Int", 0, "UInt", AF_INET, "UInt", TCP_TABLE_OWNER_PID_ALL, "UInt", 0) != 0)
        Return (ErrorLevel := 1) & 0
 
    Offset := 0, TcpTable := []
    Loop % NumGet(pTcpTable, "UInt") {
        TcpTable[A_Index, "State"] := NumGet(&pTcpTable + (Offset+=4), "UInt")
        TcpTable[A_Index, "LocalAddr"] := NumGet(&pTcpTable + (Offset+=4), "UInt")
        TcpTable[A_Index, "LocalPort"] := NumGet(&pTcpTable + (Offset+=4), "UInt")
        TcpTable[A_Index, "RemoteAddr"] := NumGet(&pTcpTable + (Offset+=4), "UInt")
        TcpTable[A_Index, "RemotePort"] := NumGet(&pTcpTable + (Offset+=4), "UInt")
        TcpTable[A_Index, "OwningPid"] := NumGet(&pTcpTable + (Offset+=4), "UInt")
    }
    Return TcpTable
}
; ==================================================================================================================================
;SetScrollInfo(hwnd, ScrollInfoObj, fnBar:=1, fRedraw:=True) {
;    ; NOT SUPPORTED ON WINDOWS XP
;    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787583%28v=vs.85%29.aspx
;    VarSetCapacity(SCROLLINFO, ScrollInfoObj.Size, 0)
;    NumPut(ScrollInfoObj.Size, SCROLLINFO, 0, "UInt") 
;    NumPut(ScrollInfoObj.Mask, SCROLLINFO, 4, "UInt")
;    NumPut(ScrollInfoObj.Min, SCROLLINFO, 8, "Int")
;    NumPut(ScrollInfoObj.Max, SCROLLINFO, 12, "Int")
;    NumPut(ScrollInfoObj.Page, SCROLLINFO, 16, "UInt")
;    NumPut(ScrollInfoObj.Pos, SCROLLINFO, 20, "Int")
;    NumPut(ScrollInfoObj.TrackPos, SCROLLINFO, 24, "Int")
;    Return DllCall("User32.dll\SetScrollInfo", "Ptr", hwnd, "Int", fnBar, "Ptr", &SCROLLINFO)
;}
;; ==================================================================================================================================
;GetScrollInfo(hwnd, fnBar:=1) {
;    ; NOT SUPPORTED ON WINDOWS XP
;    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787583%28v=vs.85%29.aspx
;    VarSetCapacity(SCROLLINFO, 28, 0)
;    NumPut(28, SCROLLINFO, 0, "UInt") 
;    NumPut(0x1F, SCROLLINFO, 4, "UInt") ; SIF_ALL
;    If !DllCall("User32.dll\GetScrollInfo", "Ptr", hwnd, "Int", fnBar, "Ptr", &SCROLLINFO)
;        Return False
;
;    ScrollInfoObj := {}
;    ScrollInfoObj.Size := NumGet(SCROLLINFO, 0, "UInt")
;    ScrollInfoObj.Mask := NumGet(SCROLLINFO, 4, "UInt")
;    ScrollInfoObj.Min := NumGet(SCROLLINFO, 8, "Int")
;    ScrollInfoObj.Max := NumGet(SCROLLINFO, 12, "Int")
;    ScrollInfoObj.Page := NumGet(SCROLLINFO, 16, "UInt")
;    ScrollInfoObj.Pos  := NumGet(SCROLLINFO, 20, "Int")
;    ScrollInfoObj.TrackPos := NumGet(SCROLLINFO, 24, "Int")
;
;    Return ScrollInfoObj
;}
; ==================================================================================================================================
OpenProcess(PID := 0, Privileges := -1) {
    Return DllCall("OpenProcess", "Uint", (Privileges = -1) ? 0x1F0FFF : Privileges, "Uint", False, "Uint", PID ? PID : DllCall("GetCurrentProcessId"))
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
    devicePathsObj := GetDevicePaths()
    Loop %HandleCount% {
        ; PROCESS_DUP_HANDLE = 0x40, PROCESS_QUERY_INFORMATION = 0x400
        If !(hProc := DllCall("OpenProcess", "UInt", 0x0400|0x40|0x10, "UInt", 0, "UInt", SHI[A_Index, "PID"], "UPtr"))
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
            DllCall("QueryFullProcessImageName", "Ptr", hProc, "UInt", 0, "Str", ProcFullPath, "UIntP", sz := 260) ; NOT COMPATIBLE WITH WINDOWS XP
            
            Data := {}
            Data.ProcFullPath := ProcFullPath ? ProcFullPath : GetProcessFilePath(hProc) ; For XP compatibility
            Data.PID := SHI[A_Index].PID
            Data.Handle := SHI[A_Index].Handle
            Data.GrantedAccess := SHI[A_Index].Access
            Data.Flags := SHI[A_Index].Flags
            Data.Attributes := OBI.Attr
            Data.HandleCount := (OBI.Handles - 1)
            Data.DevicePath := ONI.Name
            
            FilePath := GetPathNameByHandle(hObject) ; NOT COMPATIBLE WITH WINDOWS XP
            
            If (!FilePath) {  ; For XP compatibility
                RegexMatch(Data.DevicePath, "OS)(^\\.+?\\.+?)(\\|$)", matches)
                FilePath := StrReplace(Data.DevicePath,matches[1],devicePathsObj[matches[1]],o,1)
            }
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
GetIconByPath(Path, FileExists:="") { ; fully qualified file path, result of FileExist on Path (optional)
    ; SHGetFileInfo  -> http://msdn.microsoft.com/en-us/library/bb762179(v=vs.85).aspx
    ; FIXME:
    ;     For 32-bit AHK File System Redirection is automatically enabled when running on a 64-bit OS. 
    ;     So files which exist in Sytem32 (64-bit) but not in SysWOW64 (32-bit) won't be found. 
    ;     Also, all files which exist in both directories might address the wrong file. 
    ;     So the file redirection must be disabled in this case (A_Is64bitOS && (A_PtrSize = 4)).
    Static AW := A_IsUnicode ? "W" : "A"
    Static cbSFI := A_PtrSize + 8 + (340 << !!A_IsUnicode)
    Static IconType := 2
    FileExists := FileExists ? FileExists : FileExist(Path)
    If (FileExists) {
        SplitPath, Path, , , FileExt
        If (InStr(FileExists, "D") || FileExt = "exe" || FileExt = "ico" || FileExt = "") {
            pszPath := Path
            dwFileAttributes := 0x00
            uFlags := 0x0101
        } Else {
            pszPath := "." FileExt
            dwFileAttributes := 0x80
            uFlags := 0x0111
        }
    } Else ; If the file is deleted reutrn an appropriate icon. 
        Return LoadPicture(A_WinDir "\System32\imageres.dll", "Icon85 w16 h16", IconType) ; TODO: find a way to retrieve the icon just once and return it everytime it is needed
        ;TODO: maybe remove this because other scripts might not want to get this icon when the file is not existent
    
    VarSetCapacity(SFI, cbSFI, 0) ; SHFILEINFO
    DllCall("Shell32.dll\SHGetFileInfo" . AW, "Str", pszPath, "UInt", dwFileAttributes, "Ptr", &SFI, "UInt", cbSFI, "UInt", uFlags, "UInt")
    Return NumGet(SFI, 0, "UPtr")
}
; ==================================================================================================================================
GetPathNameByHandle(hFile) {
    VarSetCapacity(FilePath, 4096, 0)
    DllCall("GetFinalPathNameByHandle", "Ptr", hFile, "Str", FilePath, "UInt", 2048, "UInt", 0, "UInt")
    Return SubStr(FilePath, 1, 4) = "\\?\" ? SubStr(FilePath, 5) : FilePath
}
; ==================================================================================================================================
GetDevicePaths() {
    DriveGet, driveLetters, List
    driveLetters := StrSplit(driveLetters)
    devicePaths := {}
    Loop % driveLetters.MaxIndex()
        devicePaths[QueryDosDevice(driveLetters[A_Index] ":")] := driveLetters[A_Index] ":"
    Return devicePaths
}
; ==================================================================================================================================
QueryDosDevice(DeviceName := "C:") {
    size := VarSetCapacity(TargetPath, 1023) + 1
    DllCall("QueryDosDevice", "str", DeviceName, "str", TargetPath, "uint", size)
    return TargetPath
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
RunAsAdmin() {
    If !(A_IsAdmin) {
        Run % "*RunAs " . (A_IsCompiled ? "" : A_AhkPath . " ") . """" . A_ScriptFullPath . """"
        ExitApp
    }
}