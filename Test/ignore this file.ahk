RunAsAdmin()                                         ; Run elevated
thisHProcess := OpenProcess()                        ; Get handle to this ahk process
SetPrivilege(thisHProcess, "SeDebugPrivilege", True) ; Set SeDebugPrivilege on this process
pidList := EnumProcesses()                           ; Get all process IDs

Loop % pidList.MaxIndex() {                          ; Loop through all the PIDs 
    pid := pidList[A_Index]                          ; Store current process ID in pid
    hProcess := OpenProcess(pidList[A_Index])        ; Store current process handle in hProcess
    
    
    If !A_LastError                                   ; If an error occured print it out:
        MsgBox % "PID: " pid "`nHandle: " hProcess "`nLastError: " A_LastError
    
    
    
    
    CloseHandle(hProcess)                            ; Close the handle again
}


;EnumHandles(hProcess) {
;    
;    DllCall("Ntdll.dll\NtQuerySystemInformation", 
;}

WinGetPid(winTitle := "A") {
    WinGet, pid, PID, %winTitle%
    Return pid
}

OpenProcess(pid := 0, privileges := -1) {
    Return DllCall("OpenProcess", "Uint", (privileges = -1) ? 0x1F0FFF|0x0400 : privileges, "Uint", False, "Uint", pid ? pid : DllCall("GetCurrentProcessId"))
}

CloseHandle(handle) {
    Return DllCall("CloseHandle", "Ptr", handle)
}

SetPrivilege(hProcess, privilegeName := "SeDebugPrivilege", enable := True) {
    DllCall("Advapi32.dll\OpenProcessToken", "Ptr", hProcess, "UInt", 32, "PtrP", tokenHandle)
    VarSetCapacity(newState, 16, 0)
    NumPut(1, newState, 0, "UInt")
    DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", privilegeName, "Int64P", luid)
    NumPut(luid, newState, 4, "Int64")
    If enable
    	NumPut(2, newState, 12, "UInt")
    returnValue := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", tokenHandle, "Int", False, "Ptr", &newState, "UInt", 0, "Ptr", 0, "Ptr", 0)
    CloseHandle(tokenHandle)
    CloseHandle(hProcess)
    Return returnValue
}

EnumProcesses() {
    pidList := []
    VarSetCapacity(pProcessIds, 4096)
    DllCall("Psapi.dll\EnumProcesses", "Ptr", &pProcessIds, "UInt", 4096, "UIntP", pBytesReturned)
    Loop % pBytesReturned // 4
        If pid := NumGet(pProcessIds, A_Index*4, "UInt") ;pProcessIds = DWORD array (DWORD = 4 bytes)
            pidList.Insert(pid)
    Return pidList
}

RunAsAdmin() {
    If !A_IsAdmin {
        Run *runAs "%A_ScriptFullPath%"
        ExitApp
    }
}