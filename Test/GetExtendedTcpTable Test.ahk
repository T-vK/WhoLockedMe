RunAsAdmin()
DllCall("LoadLibrary", "Str", "Iphlpapi.dll", "UPtr")
EnablePrivilege()

TcpTable := GetExtendedTcpTable()
Loop % TcpTable.MaxIndex() {
    c := TcpTable[A_Index]
    MsgBox % "State: " c.State "`nLocalAddr: " c.LocalAddr "`nLocalPort: " c.LocalPort "`nRemoteAddr: " c.RemoteAddr "`nRemotePort: " c.RemotePort "`nOwningPid: " c.OwningPid
}
GetExtendedTcpTable() {
   ; https://msdn.microsoft.com/en-us/library/aa365928.aspx
   TCP_TABLE_OWNER_PID_ALL = 5 ; pTcpTable will be a MIB_TCPTABLE_OWNER_PID struct: https://msdn.microsoft.com/en-us/library/aa366921.aspx 
   AF_INET = 2
   VarSetCapacity(pdwSize, 4)
   pTcpTableSize := VarSetCapacity(pTcpTable, 4) ;we could specify a really high number here to avoid calling the function twice
   DllCall("Iphlpapi.dll\GetExtendedTcpTable", "UInt", &pTcpTable, "UInt", &pdwSize, "UInt", False, "UInt", AF_INET, "UInt", TCP_TABLE_OWNER_PID_ALL, "UInt", 0)
   VarSetCapacity(pTcpTable, NumGet(pdwSize))
   DllCall("Iphlpapi.dll\GetExtendedTcpTable", "UInt", &pTcpTable, "UInt", &pdwSize, "UInt", False, "UInt", AF_INET, "UInt", TCP_TABLE_OWNER_PID_ALL, "UInt", 0)
   
   dwNumEntries := NumGet(pTcpTable, 0, "UInt")
   TcpTable := []
   CurrentOffset := 0
   Loop % dwNumEntries { ;Loop through the elements of the MIB_TCPROW_OWNER_PID table (array)
       Tcp := {}
       CurrentOffset += 4
       Tcp.State := NumGet(pTcpTable, CurrentOffset, "UInt")
       CurrentOffset += 4
       Tcp.LocalAddr := NumGet(pTcpTable, CurrentOffset, "UInt")
       CurrentOffset += 4
       Tcp.LocalPort := NumGet(pTcpTable, CurrentOffset, "UInt")
       CurrentOffset += 4
       Tcp.RemoteAddr := NumGet(pTcpTable, CurrentOffset, "UInt")
       CurrentOffset += 4
       Tcp.RemotePort := NumGet(pTcpTable, CurrentOffset, "UInt")
       CurrentOffset += 4
       Tcp.OwningPid := NumGet(pTcpTable, CurrentOffset, "UInt")
       TcpTable.Push(Tcp)
   }
   Return TcpTable
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