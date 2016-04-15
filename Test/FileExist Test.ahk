; Possible bug in FileExist

RunAsAdmin()

MsgBox % FileExist(A_WinDir "\de-DE\lsasrv.dll.mui")

RunAsAdmin() {
   If !(A_IsAdmin) {
      Run % "*RunAs " . (A_IsCompiled ? "" : A_AhkPath . " ") . """" . A_ScriptFullPath . """"
      ExitApp
   }
}