; http://forums.codeguru.com/showthread.php?176997.html
; https://autohotkey.com/boards/viewtopic.php?p=80447
; credits to HotkeyIt for the super complicated handle retrievement!
; credits to jNizM for the neat QueryDosDevice function!
; credits to Lexokos and "just me" for the GetIconGroupNameByIndex fucntion
 
RunAsAdmin()
SetGlobals()
EnablePrivilege()

Gui, +Resize
Gui, Add, Edit, w640 r1 aw gGui_FilterList vGui_Filter
Gui, Add, ListView, w640 r30 aw ah, Potentially locked|By
LV_ModifyCol(1,300)
LV_ModifyCol(2,300)
Gui, Add, Button, w640 aw ay gGui_Reload, Reload
Gui, Add, Progress, w640 aw ay vGui_Progress
Gui, Show,, % "Showing " i " File Handles"
 
Gui_Reload()
 
Gui_FilterList(ctrlHwnd:="", guiEvent:="", eventInfo:="", errLvl:=0) {
    Global
    GuiControlGet, Gui_Filter
    LV_Delete()
    Loop % dataArray.MaxIndex() {
        data := dataArray[A_Index]
        If (InStr(data.filePath,Gui_Filter))
            LV_Add("Icon" A_Index, data.filePath, data.procFullPath)
    }
}
 
Gui_Reload() {
    Global ;let's make life a bit more easy
    obi := Struct(OBJECT_BASIC_INFORMATION), oti := Struct("OBJECT_TYPE_INFORMATION[100]"), oni := Struct("OBJECT_NAME_INFORMATION[65]")
    ObjectBasicInformation:=0, ObjectNameInformation:=1,ObjectTypeInformation:=2
    VarSetCapacity(p,A_PtrSize*n:=0x1000)
    SystemHandleInformation:=16
    While 0xc0000004 = DllCall("ntdll\ZwQuerySystemInformation","UInt", SystemHandleInformation, "PTR", &p, "UInt", n*A_PtrSize, "UInt*", sz,"CDecl UInt") ;STATUS_INFO_LENGTH_MISMATCH:=0xc0000004
        VarSetCapacity(p, A_PtrSize * (n := n * 2))
    h:=Struct("SYSTEM_HANDLE_INFORMATION", (&p) + A_PtrSize)
    hCurrentProc:=GetCurrentProcess()
    VarSetCapacity(procName,520)
    dataArray := []
    i:=0
    numgetRes := NumGet(&p,"UInt")
 
    LV_Delete()
    ImageList := IL_Create(numgetRes)
    LV_SetImageList(ImageList)
    GuiControl,, Gui_Progress, 0 
 
    devicePathsObj := GetDevicePaths()
 
    Loop % numgetRes {
        GuiControl,, Gui_Progress, % A_Index/numgetRes*100
        If !hProc:=OpenProcess(0x40|0x400, false, h[A_Index].ProcessID) ;PROCESS_DUP_HANDLE:=0x40, PROCESS_QUERY_INFORMATION:=0x400
            Continue
        If (ZwDuplicateObject(hProc, h[A_Index].Handle, hCurrentProc, getvar(hObject:=0), 0, 0, 0x4)){ ;DUPLICATE_SAME_ATTRIBUTES := 0x4
            CloseHandle(hProc)
            Continue
        }
        ZwQueryObject(hObject, ObjectBasicInformation, obi[], sizeof(obi))
        ZwQueryObject(hObject, ObjectTypeInformation, oti[], obi.TypeInformationLength + 2)
        If ("File" !=StrGet(oti.Name.Buffer["",""],oti.Name.Length // 2,"UTF-16") || GetFileType(hObject)!=1) {
            CloseHandle(hObject),CloseHandle(hProc)
            Continue
        }
        DllCall("QueryFullProcessImageName","Ptr", hProc, "Uint", 0, "Str", procName, "UInt*", sz:=520)
        data := {}
        data.procFullPath := procName
        data.pid := h[A_Index].ProcessID
        data.handle := h[A_Index].Handle
        data.grantedAccess := h[A_Index].GrantedAccess
        data.flags := h[A_Index].flags
        data.attributes := obi.Attributes
        data.handleCount := (obi.HandleCount - 1)
        i++
        If ZwQueryObject(hObject, ObjectNameInformation, oni[], obi.NameInformationLength = 0 ? 520 : obi.NameInformationLength)<0x7FFFFFFF { ; MAX_PATH*2:=520
            devicePath := StrGet(oni.Name.Buffer["",""],oni.Name.Length // 2,"UTF-16")
            RegexMatch(devicePath, "S)(^\\.+?\\.+?)(\\|$)", matches)
            filePath := StrReplace(devicePath,matches[1],devicePathsObj[matches[1]],o,1)
            drive := SubStr(filePath,1,1)
            data.devicePath := devicePath
            data.filePath := filePath
            data.drive := drive
            data.isfolder := InStr(FileExist(data.filePath), "D") ? True : False
 
            SplitPath, % data.filePath,,, fileExt
            If (data.isfolder)
                IL_Add(ImageList, "shell32.dll", 5)
            Else If (fileExt = "exe") {
                If GetIconGroupNameByIndex(data.filePath, 1)
                    IL_Add(ImageList, data.filePath, 0)
                Else
                    IL_Add(ImageList, "imageres.dll", 12)
            } Else {
                icon := GetIconByExt(fileExt)
                If (icon.file)
                    IL_Add(ImageList, icon.file, icon.index)
                Else
                    IL_Add(ImageList, "imageres.dll", 3) 
            }
            dataArray.Push(data)
        }
 
        CloseHandle(hObject),CloseHandle(hProc)
    }
 
    Gui_FilterList()
}
 
GuiClose(){
    ExitApp
}
#DllImport, ZwDuplicateObject,ntdll\ZwDuplicateObject,PTR,,PTR,,PTR,,PTR,,UInt,,UInt,,UInt,,UInt
#DllImport, ZwQuerySystemInformation, ntdll\ZwQuerySystemInformation,UInt,,PTR,,UInt,,UInt,,UInt
#DllImport, ZwQueryObject, ntdll\ZwQueryObject,PTR,,UInt,,PTR,,UInt,,UInt,,UInt
#DllImport, ZwQueryInformationFile, ntdll\ZwQueryInformationFile,PTR,,PTR,,PTR,,UInt,,UInt,
RunAsAdmin() {
    If !A_IsAdmin {
        Run % "*runAs " (A_IsCompiled?"":A_AhkPath " ") "`"" A_ScriptFullPath "`""
        ExitApp
    }
}
EnablePrivilege(name:="SeDebugPrivilege"){
	static LUID:="DWORD LowPart;LONG  HighPart",LUID_AND_ATTRIBUTES:="EnablePrivilege(LUID) Luid;DWORD Attributes;",TOKEN_PRIVILEGES:="DWORD PrivilegeCount;EnablePrivilege(LUID_AND_ATTRIBUTES) Privileges[1]"
	,priv:=Struct(TOKEN_PRIVILEGES,{PrivilegeCount:1}),init:=priv.Privileges.Attributes:=2 ;SE_PRIVILEGE_ENABLED
    LookupPrivilegeValue(0, name, priv.Privileges.Luid[""])
	OpenProcessToken(GetCurrentProcess(), 32, getvar(hToken:=0)) ; TOKEN_ADJUST_PRIVILEGES:=32
    AdjustTokenPrivileges(hToken, FALSE, priv[], sizeof(priv), 0, 0)
    rv := !A_LastError
    CloseHandle(hToken)
    return rv
}
 
GetIconByExt(ext) {
   from := RegRead("HKEY_CLASSES_ROOT\." ext)
   defaultIcon := RegRead("HKEY_CLASSES_ROOT\" from "\DefaultIcon")
   defaultIcon := StrReplace(defaultIcon, "`"", "") ;"
   defaultIcon := StrReplace(defaultIcon, "`%SystemRoot`%", A_WinDir)
   defaultIcon := StrReplace(defaultIcon, "`%ProgramFiles`%", A_ProgramFiles)
   defaultIcon := StrReplace(defaultIcon, "`%windir`%", A_WinDir)
   defaultIconSplit := StrSplit(defaultIcon,",")
   resFile := defaultIconSplit[1]
   index := defaultIconSplit[2]
   ;index := (index < 0 ? abs(index)-4 : index)
   Return {file: resFile, index: index}
}
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
 
GetDevicePaths() {
    DriveGet, driveLetters, List
    driveLetters := StrSplit(driveLetters)
    devicePaths := {}
    Loop % driveLetters.MaxIndex()
        devicePaths[QueryDosDevice(driveLetters[A_Index] ":")] := driveLetters[A_Index] ":"
    Return devicePaths
}
QueryDosDevice(DeviceName := "C:") {
    ; Credits to jNizM for this function
    size := VarSetCapacity(TargetPath, 1023) + 1
    DllCall("QueryDosDevice", "str", DeviceName, "str", TargetPath, "uint", size)
    return TargetPath
}
 
SetGlobals() {
    Global
    FILETIME :="DWORD dwLowDateTime;DWORD dwHighDateTime"
    OBJECT_BASIC_INFORMATION:="
    (
        // Information Class 0
        int Attributes;
        int GrantedAccess;
        int HandleCount;
        int PointerCount;
        int PagedPoolUsage;
        int NonPagedPoolUsage;
        int Reserved1;
        int Reserved2;
        int Reserved3;
        int NameInformationLength;
        int TypeInformationLength;
        int SecurityDescriptorLength;
        FILETIME CreateTime;
    )"
    GENERIC_MAPPING :="
    (
      DWORD GenericRead;
      DWORD GenericWrite;
      DWORD GenericExecute;
      DWORD GenericAll;
    )"
    OBJECT_TYPE_INFORMATION:="
    (
        // Information Class 2
        UNICODE_STRING Name;
        int ObjectCount;
        int HandleCount;
        int Reserved1;
        int Reserved2;
        int Reserved3;
        int Reserved4;
        int PeakObjectCount;
        int PeakHandleCount;
        int Reserved5;
        int Reserved6;
        int Reserved7;
        int Reserved8;
        int InvalidAttributes;
        GENERIC_MAPPING GenericMapping;
        int ValidAccess;
        byte Unknown;
        byte MaintainHandleDatabase;
        int PoolType;
        int PagedPoolUsage;
        int NonPagedPoolUsage;
    )"
    UNICODE_STRING := "WORD Length;WORD MaximumLength;WORD *Buffer"
    OBJECT_NAME_INFORMATION:="UNICODE_STRING Name"
    ;SYSTEM_HANDLE_INFORMATION :="
    ;(
    ;    // Information Class 16
    ;    int ProcessID;
    ;    byte ObjectTypeNumber;
    ;    byte Flags; // 0x01 = PROTECT_FROM_CLOSE, 0x02 = INHERIT
    ;    ushort Handle;
    ;    int Object_Pointer;
    ;    int GrantedAccess;
    ;)"
    SYSTEM_HANDLE_INFORMATION :="
    (
        // Information Class 16
        int ProcessID;
        byte ObjectTypeNumber;
        byte Flags; // 0x01 = PROTECT_FROM_CLOSE, 0x02 = INHERIT
        ushort Handle;
        pvoid Object_Pointer; // <<<<< changed int to pvoid
        int GrantedAccess;
    )"
}