#Requires AutoHotkey v2.0
#SingleInstance Off
; Only remove owned disposable profiles. Never touch the old chrome-sessions folder.
if A_Args.Length != 2
    ExitApp 1
folder := A_Args[1]
pid := Integer(A_Args[2])
if !OwnedProfile(folder) || pid < 1
    ExitApp 1
try ProcessWaitClose pid
Loop 30 {
    if RemoveProfile(folder)
        break
    Sleep 2000
}
; Retry leftovers from a previous shutdown, but retain any profile whose owner is alive.
Loop Files A_ScriptDir "\chrome-sessions-temporary\*", "D" {
    candidate := A_LoopFileFullPath
    if !OwnedProfile(candidate)
        continue
    try {
        owner := Integer(IniRead(candidate "\.disposable-session.ini","Owner","pid"))
        if owner > 0 && !ProcessExist(owner)
            RemoveProfile(candidate)
    }
}
ExitApp

OwnedProfile(folder) {
    root := A_ScriptDir "\chrome-sessions-temporary\"
    if !DirExist(root) || InStr(FileGetAttrib(root),"L")
        return false
    ; A direct child with a generated GUID; no traversal or external paths allowed.
    if SubStr(folder,1,StrLen(root)) != root
        return false
    leaf := SubStr(folder,StrLen(root)+1)
    if !RegExMatch(leaf,"i)^session-\d+-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        return false
    if !DirExist(folder) || InStr(FileGetAttrib(folder),"L")
        return false
    return IniRead(folder "\.disposable-session.ini","Owner","kind","") = "controller-temporary-chrome-v1"
}
RemoveProfile(folder) {
    try {
        if !OwnedProfile(folder)
            return false
        ; Reject junctions/symlinks before recursive deletion.
        Loop Files folder "\*", "DFR"
            if InStr(A_LoopFileAttrib,"L")
                return false
        ; Keep the ownership marker if a locked file requires a later retry.
        Loop Files folder "\*", "DF" {
            if A_LoopFileName = ".disposable-session.ini"
                continue
            if InStr(A_LoopFileAttrib,"D")
                DirDelete A_LoopFileFullPath,1
            else
                FileDelete A_LoopFileFullPath
        }
        FileDelete folder "\.disposable-session.ini"
        DirDelete folder
        return true
    } catch {
        return false
    }
}
