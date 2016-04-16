RunAsAdmin()
DllCall("LoadLibrary", "Str", "Iphlpapi.dll", "UPtr")
EnablePrivilege()

TcpTable := GetExtendedTcpTable()
MsgBox % TcpTable[1].OwningPid
MsgBox % TcpTable[4].State
MsgBox % TcpTable[2].LocalAddr
MsgBox % TcpTable[6].RemotePort

GetExtendedTcpTable() {
   ; https://msdn.microsoft.com/en-us/library/aa365928.aspx
   TCP_TABLE_OWNER_PID_ALL = 5 ; pTcpTable will be a MIB_TCPTABLE_OWNER_PID struct: https://msdn.microsoft.com/en-us/library/aa366921.aspx 
   AF_INET = 2
   VarSetCapacity(pdwSize, 4)
   pTcpTableSize := VarSetCapacity(pTcpTable, 4)
   DllCall("Iphlpapi.dll\GetExtendedTcpTable", "Ptr", pTcpTable, "Ptr", pdwSize, "UInt", False, "UInt", AF_INET, "UInt", TCP_TABLE_OWNER_PID_ALL, "UInt", 0)
   RequiredSize := NumGet(pdwSize, 0, "UInt")
   If (RequiredSize < pTcpTableSize) {
      VarSetCapacity(pTcpTable, RequiredSize)
      DllCall("Iphlpapi.dll\GetExtendedTcpTable", "Ptr", pTcpTable, "Ptr", pdwSize, "UInt", False, "UInt", AF_INET, "UInt", TCP_TABLE_OWNER_PID_ALL, "UInt", 0)
   }
   dwNumEntries := NumGet(pTcpTable, 0, "UInt")
   TcpTable := []
   msgbox % dwNumEntries
   Loop % dwNumEntries { ;Loop through the elements of the MIB_TCPROW_OWNER_PID table (array)
       MIB_TCPROW_OWNER_PID := NumGet(pTcpTable, 4+(A_Index-1)*24, "UInt")
       Tcp := {}
       Tcp.State := NumGet(MIB_TCPROW_OWNER_PID, 0, "UInt")
       Tcp.LocalAddr := NumGet(MIB_TCPROW_OWNER_PID, 4, "UInt")
       Tcp.LocalPort := NumGet(MIB_TCPROW_OWNER_PID, 8, "UInt")
       Tcp.RemoteAddr := NumGet(MIB_TCPROW_OWNER_PID, 12, "UInt")
       Tcp.RemotePort := NumGet(MIB_TCPROW_OWNER_PID, 16, "UInt")
       Tcp.OwningPid := NumGet(MIB_TCPROW_OWNER_PID, 20, "UInt")
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