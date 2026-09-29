#Requires AutoHotkey v2.0
#SingleInstance Force
SetControlDelay -1
; Preserve the previous sender's lack of an added per-key delay.
SetKeyDelay -1, -1

global Targets := [], Running := false, Busy := false, RunMessage := ""
global LaunchPanel := 0, LaunchQueue := 0
global PeriodicPoint := 0, PeriodicEvery := 10, RunPeriodicEvery := 0
global SingleCycle := false, CaptureDraft := 0, PointTemplate := 0, PreviewMarker := 0
global Picker := 0, CaptureTarget := 0, CaptureCountdown := 0
global Options := Defaults(), IniPath := A_ScriptDir "\controller-sequence-background-loop.ini"
if A_Args.Length && A_Args[1] = "--selftest" {
    plan := Steps(Defaults()), waits := 0, clicks := 0, fills := 0, enters := 0
    for action in plan {
        waits += action.delay
        clicks += action.kind = "click"
        fills += action.kind = "fill"
        enters += action.kind = "key"
    }
    if plan.Length != 20 || waits != 4950 || clicks != 3 || fills != 4 || enters != 4
        throw Error("Sequence mismatch")
    if plan[1].x != 380 || plan[3].x != 943 || plan[5].y != 756 || plan[7].text != "Girl 1 5 "
        throw Error("Coordinates or text changed")
    FileAppend "PASS: 20 steps, 3 clicks, 4 fills, 4 Enter presses, default waits including message 4 settle time. No browser input sent.`n","*"
    ExitApp
}

try {
    for key,value in Options
        Options[key] := IniRead(IniPath,"Timing",key,value)
    Validate(Options)
} catch {
    Options := Defaults()
}
global Panel := Gui(,"Controller sequence · Background")
Panel.BackColor := "F4F6FA"
Panel.SetFont("s18 w600 c172033","Segoe UI")
Panel.AddText("x24 y16 w850 h32","Controller sequence · Background")
Panel.SetFont("s10 w400 c637087")
Panel.AddText("x24 y54 w850 h34","Your 20-step sequence. Each assigned browser runs independently. Test one cycle first.")
global Tabs := Panel.AddTab3("x24 y98 w880 h574",["Browsers","Steps & settings","Every N loops"])
Tabs.UseTab(1)
Panel.AddText("x44 y140 w830 h62","1 = first button (workflow step 1). 2 = second button (step 3). 3 = message field (step 5).`nClick Record, then hover over the exact target centre for 3 seconds. Navigate between recordings if needed.`nSelect a saved browser and use Show 1/2/3 to check its points without clicking or sending anything.")
global Rows := Panel.AddListView("x44 y220 w830 h300 -Multi",["Browser","Current step / status"])
Rows.ModifyCol(1,480), Rows.ModifyCol(2,320)
global ChooseButton := Panel.AddButton("x44 y540 w175 h36","Record click 1")
ChooseButton.OnEvent("Click",(*) => BeginCapture())
global RemoveButton := Panel.AddButton("x232 y540 w175 h36","Remove selected")
RemoveButton.OnEvent("Click",(*) => RemoveTarget())
Panel.AddButton("x422 y540 w175 h36","Cancel recording").OnEvent("Click",(*) => CancelCapture())
global ReuseButton := Panel.AddButton("x610 y540 w264 h36","Add windows - reuse 3 points")
ReuseButton.OnEvent("Click",(*) => ChooseWindow())
global PointsLabel := Panel.AddText("x44 y594 w520 h62","Select a browser to see its three saved points.")
Rows.OnEvent("ItemSelect",(*) => UpdatePointSummary())
Panel.AddButton("x580 y604 w90 h32","Show 1").OnEvent("Click",(*) => PreviewPoint(1))
Panel.AddButton("x680 y604 w90 h32","Show 2").OnEvent("Click",(*) => PreviewPoint(2))
Panel.AddButton("x780 y604 w90 h32","Show 3").OnEvent("Click",(*) => PreviewPoint(3))
global MessageInput := Panel.AddEdit("Hidden","workflow")
Tabs.UseTab(2)
global Fields := Map()
for i,spec in TimingFields() {
    col := i > 10 ? 1 : 0, row := Mod(i-1,10), x := 44+col*432, y := 140+row*44
    Panel.AddText("x" x " y" y " w226 h34",spec[2])
    Fields[spec[1]] := Panel.AddEdit("x" (x+230) " y" y " w174 h30",Options[spec[1]])
}
global SaveButton := Panel.AddButton("x44 y592 w160 h34","Save settings")
SaveButton.OnEvent("Click",(*) => SaveSettings())
global ResetButton := Panel.AddButton("x216 y592 w175 h34","Reset to defaults")
ResetButton.OnEvent("Click",(*) => ResetSettings())
global SettingsStatus := Panel.AddText("x44 y634 w825 h30","")
Tabs.UseTab(3)
Panel.AddText("x44 y145 w800 h65","Optional extra click after every N completed loops, separately for each browser.`nRecord once; the point is reused in all assigned browsers with the same client size.`nYour existing 20 steps and waits stay unchanged. Test modes do not perform this extra click.")
Panel.AddText("x44 y230 w230 h30","Every how many loops? (0 = off)")
global PeriodicInput := Panel.AddEdit("x285 y226 w130 h30 Number","10")
Panel.AddButton("x435 y226 w160 h32","Save interval").OnEvent("Click",(*) => SavePeriodicInterval())
Panel.AddButton("x44 y285 w230 h36","Record extra click").OnEvent("Click",(*) => BeginPeriodicCapture())
Panel.AddButton("x290 y285 w180 h36","Cancel recording").OnEvent("Click",(*) => CancelCapture())
global PeriodicLabel := Panel.AddText("x44 y350 w800 h110","No extra click recorded. The existing loop runs normally.")
Panel.AddText("x44 y500 w800 h60","Hover over the extra button for 3 seconds after clicking Record. It saves automatically.`nLoop counts start again from zero each time you press Start all. Stop before editing settings.")
Tabs.UseTab()

global StartButton := Panel.AddButton("x24 y690 w175 h38","Start all")
StartButton.OnEvent("Click",(*) => Toggle())
global TestButton := Panel.AddButton("x212 y690 w175 h38","Test one cycle")
TestButton.OnEvent("Click",(*) => Toggle(true))
global ClickTestButton := Panel.AddButton("x402 y690 w175 h38","Test clicks only")
ClickTestButton.OnEvent("Click",(*) => Toggle(true,true))
global Status := Panel.AddText("x590 y690 w310 h48","Ready")
Panel.AddText("x24 y744 w600 h26","Emergency stop: Ctrl+Alt+F12 · Closing the panel stops all runs.")
global SessionsButton := Panel.AddButton("x650 y740 w250 h32","Chrome sessions")
SessionsButton.OnEvent("Click",(*) => OpenChromeSessions())
Panel.OnEvent("Close",(*) => ClosePanel())
LoadPointTemplate()
LoadPeriodicSettings()
LoadAssignments()
OnExit (*) => SaveAssignments()
Panel.Show("w930 h786")
^!F12::StopAll()

Defaults() {
    return Map("x1",380,"y1",745,"w2",1000,"x3",943,"y3",121,"w4",1000,"x5",481,"y5",756,"w6",250,"t7","Girl 1 5 ","w8",250,"w10",250,"t11","My","w12",250,"w14",250,"t15","TG","w16",250,"t18","Munchkn","w19",200,"afterThirdEnter",250,"afterFourthEnter",1000)
}
TimingFields() {
    return [["w2","After click 1 (ms)"],["w4","After click 2 (ms)"],["w6","After click 3 (ms)"],
        ["t7","Message 1"],["w8","After message 1 (ms)"],["w10","After Enter 1 (ms)"],
        ["t11","Message 2"],["w12","After message 2 (ms)"],["w14","After Enter 2 (ms)"],
        ["t15","Message 3"],["w16","After message 3 (ms)"],["t18","Message 4"],["w19","After message 4 (ms)"],
        ["afterThirdEnter","After Enter 3 / before message 4 (ms)"],
        ["afterFourthEnter","After Enter 4 / before skipping (ms)"]]
}
Validate(values) {
    for spec in TimingFields() {
        key := spec[1]
        if SubStr(key,1,1) = "t"
            continue
        v := values[key]
        if !IsNumber(v) || v < 0 || v > 3600000 || v != Floor(v)
            throw Error(spec[2] ": enter a nonnegative whole number.")
        values[key] := Integer(v)
    }
    return values
}
Steps(v) {
    return [
{kind:"click",slot:1,key:"",x:v["x1"],y:v["y1"],delay:0},
        {kind:"wait",key:"",delay:v["w2"]},
        {kind:"click",slot:2,key:"",x:v["x3"],y:v["y3"],delay:0},
        {kind:"wait",key:"",delay:v["w4"]},
        {kind:"click",slot:3,key:"",x:v["x5"],y:v["y5"],delay:0},
        {kind:"wait",key:"",delay:v["w6"]},
        {kind:"fill",key:"",text:v["t7"],delay:0},
        {kind:"wait",key:"",delay:v["w8"]},
        {kind:"key",key:"{Enter}",delay:0},
        {kind:"wait",key:"",delay:v["w10"]},
        {kind:"fill",key:"",text:v["t11"],delay:0},
        {kind:"wait",key:"",delay:v["w12"]},
        {kind:"key",key:"{Enter}",delay:0},
        {kind:"wait",key:"",delay:v["w14"]},
        {kind:"fill",key:"",text:v["t15"],delay:0},
        {kind:"wait",key:"",delay:v["w16"]},
        {kind:"key",key:"{Enter}",delay:v["afterThirdEnter"]},
        {kind:"fill",key:"",text:v["t18"],delay:0},
        {kind:"wait",key:"",delay:v["w19"]},
        {kind:"key",key:"{Enter}",delay:v["afterFourthEnter"]}]
}
SaveSettings() {
    global Options
    if Running
        return
    try {
        values := Defaults()
        for key,control in Fields
            values[key] := control.Value
        Validate(values)
        tmp := IniPath ".pending"
        if FileExist(tmp)
            FileDelete tmp
        for key,value in values
            IniWrite value,tmp,"Timing",key
        FileMove tmp,IniPath,1
        Options := values
        SettingsStatus.Text := "Saved. Applies to the next run."
    } catch Error as err {
        SettingsStatus.Text := err.Message
    }
}
ResetSettings() {
    if Running
        return
    for key,control in Fields
        control.Value := Defaults()[key]
    SettingsStatus.Text := "Original workflow restored. Click Save settings to apply."
}
AddTarget() {
    if Running {
        Status.Text := "Stop before adding windows."
        return
    }
    MouseGetPos ,, &hovered
    hwnd := DllCall("GetAncestor", "Ptr",hovered,"UInt",2,"Ptr")
    if !hwnd || hwnd = Panel.Hwnd
        return
    RegisterTarget(hwnd)
}
RegisterTarget(hwnd, expectedPid := 0) {
    if Running
        return
    for t in Targets
        if t.hwnd = hwnd {
            Status.Text := "That window is already assigned."
            return
        }
    try {
        win := "ahk_id " hwnd
        if !WinExist(win) || (expectedPid && WinGetPID(win) != expectedPid)
            throw Error("Window closed; refresh the list.")
        if !IsObject(PointTemplate)
            throw Error("Record three points first.")
        WinGetClientPos ,,&w,&h,win
        if w != PointTemplate.w || h != PointTemplate.h
            throw Error("Window size differs: use " PointTemplate.w " x " PointTemplate.h " client size, or record it separately.")
        pts := []
        for pt in PointTemplate.points
            pts.Push({x:pt.x,y:pt.y})
        t := {hwnd:hwnd,pid:WinGetPID(win),enabled:false,step:1,due:0,points:pts,point:{x:pts[3].x,y:pts[3].y,w:w,h:h}}
        Targets.Push(t)
        Rows.Add(,WinGetTitle(win),"3 points reused")
        SaveAssignments()
        UpdateUI()
        return ""

    } catch Error as err {
        Status.Text := err.Message
        return err.Message
    }
}
ChooseWindow() {
    global Picker
    if Running
        return
    if !IsObject(PointTemplate) {
        Status.Text := "Record the three points first."
        return
    }
    if IsObject(Picker) {
        Picker.Show()
        return
    }
    Picker := Gui("+Owner" Panel.Hwnd, "Choose windows")
    Picker.BackColor := "F4F6FA"
    Picker.SetFont("s10 c172033", "Segoe UI")
    Picker.AddText("x20 y18 w700 h36", "Select browsers with the same size/layout. Ctrl or Shift selects several; Add selected reuses all 3 points.")
    list := Picker.AddListView("x20 y62 w700 h300", ["Window", "App", "Window ID"])
    list.ModifyCol(1,440), list.ModifyCol(2,150), list.ModifyCol(3,85)
    candidates := []
    Picker.AddButton("x20 y378 w150 h36", "Add selected").OnEvent("Click", (*) => AddChosen(list,candidates))
    Picker.AddButton("x182 y378 w110 h36", "Refresh list").OnEvent("Click", (*) => FillWindowList(list,candidates))
    Picker.AddButton("x304 y378 w100 h36", "Cancel").OnEvent("Click", (*) => ClosePicker())
    list.OnEvent("DoubleClick", (*) => AddChosen(list,candidates))
    Picker.OnEvent("Close", (*) => ClosePicker())
    FillWindowList(list,candidates)
    Panel.Opt("+Disabled")
    Picker.Show("w740 h434")
}
FillWindowList(list,candidates) {
    list.Delete()
    candidates.Length := 0
    for hwnd in WinGetList() {
        if hwnd = Panel.Hwnd || hwnd = Picker.Hwnd
            continue
        try {
            win := "ahk_id " hwnd
            title := WinGetTitle(win)
            if title = "" || !DllCall("IsWindowVisible", "Ptr",hwnd)
                continue
            assigned := false
            for t in Targets
                if t.hwnd = hwnd
                    assigned := true
            if assigned
                continue
            candidates.Push({hwnd:hwnd,pid:WinGetPID(win)})
            list.Add(,title,WinGetProcessName(win),hwnd)
        }
    }
}
AddChosen(list,candidates) {
    row := 0, selected := []
    while row := list.GetNext(row)
        selected.Push(candidates[row])
    if !selected.Length
        return
    failures := [], before := Targets.Length
    for target in selected {
        issue := RegisterTarget(target.hwnd,target.pid)
        if issue != ""
            failures.Push(issue)
    }
    ClosePicker()
    Status.Text := "Added " (Targets.Length-before) " windows." (failures.Length ? " " failures.Length " skipped: " failures[1] : " All 3 points saved.")
}
ClosePicker() {
    global Picker
    Panel.Opt("-Disabled")
    if IsObject(Picker)
        Picker.Destroy()
    Picker := 0
}
RemoveTarget() {
    if Running
        return
    row := Rows.GetNext()
    if row {
        Targets.RemoveAt(row)
        Rows.Delete(row)
        SaveAssignments()
        UpdateUI()
    }
}
UpdateUI() {
    StartButton.Text := Running ? "Stop all" : "Start all"
    MessageInput.Enabled := !Running
    RemoveButton.Enabled := !Running
    ChooseButton.Enabled := !Running
    SessionsButton.Enabled := !Running
    ReuseButton.Enabled := !Running
    TestButton.Enabled := !Running
    ClickTestButton.Enabled := !Running
    SaveButton.Enabled := !Running
    ResetButton.Enabled := !Running
    for key,control in Fields
        control.Enabled := !Running
    Status.Text := (Running ? "Running" : "Ready") " · " Targets.Length " windows"
    UpdatePointSummary()
}
Toggle(once := false,clicksOnly := false) {
    global Running, RunMessage, RunSteps, SingleCycle, RunPeriodicEvery
    if Running {
        StopAll()
        return
    }
    if !Targets.Length {
        Status.Text := "Record the three click targets first."
        return
    }
    if Trim(MessageInput.Value) = "" {
        Status.Text := "Enter a message first."
        return
    }
    if IsObject(CaptureTarget) {
        Status.Text := "Finish recording the field point first."
        return
    }
    for t in Targets {
        if !t.HasOwnProp("points") {
            Status.Text := "Record all three click targets for every browser."
            return
        }
    }
    selected := 0
    if clicksOnly {
        selected := Rows.GetNext()
        if !selected {
            Status.Text := "Select one browser row to test its three clicks."
            return
        }
    }
    RunPeriodicEvery := !once && IsObject(PeriodicPoint) ? PeriodicEvery : 0
    if RunPeriodicEvery {
        for t in Targets {
            if t.point.w != PeriodicPoint.w || t.point.h != PeriodicPoint.h {
                Status.Text := "Extra point size differs: resize browsers or set interval to 0."
                return
            }
        }
    }
    SingleCycle := once
    RunMessage := MessageInput.Value
    RunSteps := Steps(Options)
    if clicksOnly
        RunSteps.Length := 6
    for i,t in Targets {
        if clicksOnly && i != selected {
            t.enabled := false
            Rows.Modify(i,"Col2","Not part of click test")
            continue
        }
        t.step := 1, t.due := A_TickCount, t.enabled := true, t.cycles := 0, t.periodicPending := false
        Rows.Modify(i,"Col2","Running")
    }
    Running := true
    UpdateUI()
    SetTimer Tick,15
}
StopAll() {
    global Running, CaptureTarget
    SetTimer CaptureFieldTick,0
    CaptureTarget := 0
    Running := false
    SetTimer Tick,0
    for i,t in Targets {
        t.enabled := false
        Rows.Modify(i,"Col2","Stopped")
    }
    UpdateUI()
}
ClosePanel() {
    StopAll()
    Panel.Hide()
}
Tick() {
    global Busy, Running
    if Busy || !Running
        return
    Busy := true
    try {
        for i,t in Targets {
            if !Running
                break
            if !t.enabled
                continue
            if A_TickCount < t.due
                continue
            try {
                win := "ahk_id " t.hwnd
                if !WinExist(win) || WinGetPID(win) != t.pid
                    throw Error("Closed; add again")
                if WinGetMinMax(win) = -1
                    throw Error("Minimized")
                WinGetClientPos ,, &width, &height, win
                if width != t.point.w || height != t.point.h
                    throw Error("Resized; set point again")
                if UserModifiersHeld() {
                    t.due := A_TickCount + 100
                    continue
                }
                if t.HasOwnProp("periodicPending") && t.periodicPending {
                    SendWindowAction(t,{kind:"extraClick"})
                    t.periodicPending := false
                    Rows.Modify(i,"Col2","Extra click · " t.cycles " loops completed")
                    TraceStep(i,t,{hwnd:t.hwnd},"Extra click")
                    continue
                }
                action := RunSteps[t.step]
                SendWindowAction(t,action)
                label := action.kind = "click" ? "Click " action.slot : action.kind = "fill" ? "Text" : action.kind = "wait" ? "Wait" : action.key
                Rows.Modify(i,"Col2","Step " t.step "/" RunSteps.Length " · " label)
                TraceStep(i,t,{hwnd:t.hwnd},label)
                t.due := A_TickCount + action.delay
                t.step := Mod(t.step,RunSteps.Length) + 1
                if t.step = 1 {
                    t.cycles += 1
                    t.periodicPending := !SingleCycle && RunPeriodicEvery > 0 && Mod(t.cycles,RunPeriodicEvery) = 0
                    if SingleCycle {
                        t.enabled := false
                        Rows.Modify(i,"Col2","Test cycle sent")
                    }
                }
            } catch Error as err {
                t.enabled := false
                Rows.Modify(i,"Col2",err.Message)
            }
        }
        anyEnabled := false
        for t in Targets
            anyEnabled := anyEnabled || t.enabled
        if !anyEnabled {
            Running := false
            SetTimer Tick,0
            UpdateUI()
        }
    } finally {
        Busy := false
    }
}


BeginCapture() {
    global CaptureTarget, CaptureCountdown
    if Running
        return
    HidePreview()
    CaptureTarget := {}, CaptureCountdown := 3
    Status.Text := "Record " PointName(IsObject(CaptureDraft) ? CaptureDraft.points.Length+1 : 1) " — hover for 3 seconds."
    SetTimer CaptureFieldTick,1000
}
CaptureFieldTick() {
    global CaptureTarget, CaptureCountdown
    CaptureCountdown -= 1
    if CaptureCountdown > 0 {
        Status.Text := "Keep hovering over the click target — " CaptureCountdown " seconds."
        return
    }
    SetTimer CaptureFieldTick,0
    extra := IsObject(CaptureTarget) && CaptureTarget.HasOwnProp("periodic")
    pending := IsObject(CaptureTarget)
    CaptureTarget := 0
    if Running || !pending
        return
    try {
        CoordMode "Mouse","Screen"
        MouseGetPos &x,&y,&hovered
        root := DllCall("GetAncestor","Ptr",hovered,"UInt",2,"Ptr")
        if extra
            SavePeriodicPoint(root,x,y)
        else
            SaveField(root,x,y)
    } catch Error as err {
        Status.Text := err.Message
    }
}
SaveField(root,x,y) {
    global CaptureDraft
    if !root || root = Panel.Hwnd || (IsObject(Picker) && root = Picker.Hwnd)
        throw Error("Hover over the actual click target, then try again.")
    win := "ahk_id " root
    pid := WinGetPID(win)
    pt := MapPoint(0,root,x,y)
    WinGetClientPos ,, &w,&h,win
    cx := pt.x, cy := pt.y
    if cx < 0 || cy < 0 || cx >= w || cy >= h
        throw Error("Hover inside the webpage content.")
    if !IsObject(CaptureDraft)
        CaptureDraft := {hwnd:root,pid:pid,w:w,h:h,points:[]}
    if CaptureDraft.hwnd != root || CaptureDraft.pid != pid
        throw Error("Use the same browser for all three clicks, or Cancel recording.")
    if CaptureDraft.w != w || CaptureDraft.h != h
        throw Error("Browser resized during recording; cancel and start again.")
    CaptureDraft.points.Push({x:cx,y:cy})
    if CaptureDraft.points.Length < 3 {
        ChooseButton.Text := "Record click " (CaptureDraft.points.Length+1)
        PointsLabel.Text := DraftSummary(CaptureDraft.points)
        Status.Text := "Saved " PointName(CaptureDraft.points.Length) " at " cx ", " cy ". Next: " PointName(CaptureDraft.points.Length+1)
        return
    }
    t := 0, row := 0
    for i,target in Targets {
        if target.hwnd = root && target.pid = pid {
            t := target, row := i
            break
        }
    }
    if !IsObject(t) {
        t := {hwnd:root,pid:pid,enabled:false,step:1,due:0}
        Targets.Push(t)
        row := Rows.Add(,WinGetTitle(win),"")
    }
    t.point := {x:cx,y:cy,w:w,h:h}
    t.points := CaptureDraft.points
    SavePointTemplate(t)
    CaptureDraft := 0
    ChooseButton.Text := "Record click 1"
    if t.HasOwnProp("pageReceiver")
        t.DeleteProp("pageReceiver")
    Rows.Modify(row,"Col2","3 clicks saved")
    SaveAssignments()
    UpdateUI()
    Status.Text := "Saved · " Targets.Length " browsers. Test one cycle to check the clicks."
}


UserModifiersHeld() {
    for key in ["Ctrl","Alt","Shift","LWin","RWin"]
        if GetKeyState(key,"P")
            return true
    return false
}
MapPoint(fromHwnd,toHwnd,x,y) {
    pt := Buffer(8,0)
    NumPut("Int",x,"Int",y,pt)
    DllCall("SetLastError","UInt",0)
    result := DllCall("MapWindowPoints","Ptr",fromHwnd,"Ptr",toHwnd,"Ptr",pt,"UInt",1,"Int")
    if !result && A_LastError
        throw Error("Could not map saved point")
    return {x:NumGet(pt,0,"Int"),y:NumGet(pt,4,"Int")}
}

SendWindowAction(t,action) {
    ; Match the working SDD input path: address the saved browser window.
    win := "ahk_id " t.hwnd
    switch action.kind {
        case "click", "extraClick":
            pt := action.kind = "extraClick" ? PeriodicPoint : t.points[action.slot]
            if pt.x < 0 || pt.y < 0 || pt.x >= t.point.w || pt.y >= t.point.h
                throw Error("Saved click outside window; record again")
            ControlClick "x" pt.x " y" pt.y, win, , "Left", 1, "NA Pos"
        case "fill":
            ControlSendText action.text, , win
        case "key":
            ControlSend action.key, , win
        case "wait":
            return
    }
}

SaveAssignments() {
    file := A_ScriptDir "\controller-sequence-background-windows.ini", tmp := file ".pending"
    try {
        if FileExist(tmp)
            FileDelete tmp
        count := 0
        for t in Targets {
            if !t.HasOwnProp("point")
                continue
            count += 1, section := "Window" count
            for key in ["hwnd","pid"]
                IniWrite t.%key%,tmp,section,key
            for key in ["x","y","w","h"]
                IniWrite t.point.%key%,tmp,section,key
            if t.HasOwnProp("points")
                for n,pt in t.points {
                    IniWrite pt.x,tmp,section,"click" n "x"
                    IniWrite pt.y,tmp,section,"click" n "y"
                }
        }
        IniWrite count,tmp,"State","Count"
        FileMove tmp,file,1
    } catch Error as err {
        Status.Text := "Could not save windows: " err.Message
    }
}
LoadAssignments() {
    file := A_ScriptDir "\controller-sequence-background-windows.ini"
    if !FileExist(file)
        return
    try {
        count := Integer(IniRead(file,"State","Count",0))
        Loop count {
            section := "Window" A_Index
            hwnd := Integer(IniRead(file,section,"hwnd")), pid := Integer(IniRead(file,section,"pid"))
            win := "ahk_id " hwnd
            if !WinExist(win) || WinGetPID(win) != pid
                continue
            point := {}
            for key in ["x","y","w","h"]
                point.%key% := Integer(IniRead(file,section,key))
            t := {hwnd:hwnd,pid:pid,point:point,enabled:false,step:1,due:0}
            if IniRead(file,section,"click3x","") != "" {
                t.points := []
                Loop 3
                    t.points.Push({x:Integer(IniRead(file,section,"click" A_Index "x")),y:Integer(IniRead(file,section,"click" A_Index "y"))})
            }
            Targets.Push(t)
            Rows.Add(,WinGetTitle(win),t.HasOwnProp("points") ? "3 clicks restored" : "Record 3 clicks")
        }
        UpdateUI()
    } catch Error as err {
        Status.Text := "Some windows could not restore: " err.Message
    }
}

TraceStep(index,t,receiver,label) {
    ; Deliberately excludes message contents and browser titles.
    try {
        file := A_ScriptDir "\controller-sequence-background-diagnostics.log"
        if FileExist(file) && FileGetSize(file) > 1048576
            FileDelete file
        FileAppend A_TickCount " window=" index " target=" t.hwnd " receiver=" receiver.hwnd " step=" label "`n",file,"UTF-8"
    }
}



CancelCapture() {
    global CaptureDraft, CaptureTarget
    SetTimer CaptureFieldTick,0
    CaptureDraft := 0, CaptureTarget := 0
    ChooseButton.Text := "Record click 1"
    Status.Text := "Recording cancelled. Existing saved points are unchanged."
}

SavePointTemplate(t) {
    global PointTemplate
    pts := []
    for pt in t.points
        pts.Push({x:pt.x,y:pt.y})
    PointTemplate := {w:t.point.w,h:t.point.h,points:pts}
    file := A_ScriptDir "\controller-sequence-points.ini", tmp := file ".pending"
    try {
        if FileExist(tmp)
            FileDelete tmp
        IniWrite PointTemplate.w,tmp,"Points","w"
        IniWrite PointTemplate.h,tmp,"Points","h"
        for i,pt in pts {
            IniWrite pt.x,tmp,"Points","x" i
            IniWrite pt.y,tmp,"Points","y" i
        }
        FileMove tmp,file,1
    } catch Error as err {
        Status.Text := "Could not save reusable points: " err.Message
    }
}
LoadPointTemplate() {
    global PointTemplate
    file := A_ScriptDir "\controller-sequence-points.ini"
    if !FileExist(file)
        return
    try {
        value := {w:Integer(IniRead(file,"Points","w")),h:Integer(IniRead(file,"Points","h")),points:[]}
        Loop 3 {
            x := Integer(IniRead(file,"Points","x" A_Index)), y := Integer(IniRead(file,"Points","y" A_Index))
            if x < 0 || y < 0 || x >= value.w || y >= value.h
                throw Error("Invalid reusable point")
            value.points.Push({x:x,y:y})
        }
        PointTemplate := value
    } catch Error as err {
        Status.Text := "Reusable points could not load; record them again."
    }
}

PointName(n) {
    return ["1: first button (step 1)","2: second button (step 3)","3: message field (step 5)"][n]
}
DraftSummary(points) {
    text := ""
    for i,pt in points
        text .= PointName(i) " — X " pt.x ", Y " pt.y "`n"
    return RTrim(text,"`n")
}
UpdatePointSummary() {
    if IsObject(CaptureDraft) {
        PointsLabel.Text := DraftSummary(CaptureDraft.points)
        return
    }
    row := Rows.GetNext()
    if !row && Targets.Length
        row := Targets.Length
    if row && Targets[row].HasOwnProp("points")
        PointsLabel.Text := DraftSummary(Targets[row].points)
    else
        PointsLabel.Text := "Select a browser to see its three saved points."
}
PreviewPoint(n) {
    global PreviewMarker
    if Running || IsObject(CaptureTarget) {
        Status.Text := "Stop the loop and finish recording before previewing."
        return
    }
    row := Rows.GetNext()
    if !row && Targets.Length
        row := Targets.Length
    if !row || !Targets[row].HasOwnProp("points") {
        Status.Text := "Record all three points first."
        return
    }
    try {
        t := Targets[row], win := "ahk_id " t.hwnd
        if !WinExist(win) || WinGetPID(win) != t.pid || WinGetMinMax(win) = -1
            throw Error("Open and unminimize that browser to preview.")
        WinGetClientPos ,,&w,&h,win
        if w != t.point.w || h != t.point.h
            throw Error("Window resized; record points again.")
        pt := MapPoint(t.hwnd,0,t.points[n].x,t.points[n].y)
        HidePreview()
        PreviewMarker := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08000020 -DPIScale")
        PreviewMarker.BackColor := "FF245B"
        PreviewMarker.SetFont("s10 w700 cFFFFFF","Segoe UI")
        PreviewMarker.AddText("x0 y0 w20 h20 Center",n)
        PreviewMarker.Show("NA x" (pt.x-10) " y" (pt.y-10) " w20 h20")
        SetTimer HidePreview,-2500
        Status.Text := "Marker centre = " PointName(n) ". Nothing was clicked."
    } catch Error as err {
        Status.Text := err.Message
    }
}
HidePreview() {
    global PreviewMarker
    SetTimer HidePreview,0
    if IsObject(PreviewMarker)
        PreviewMarker.Destroy()
    PreviewMarker := 0
}


OpenChromeSessions() {
    global LaunchPanel
    if Running
        return
    if IsObject(LaunchPanel) {
        LaunchPanel.Show()
        return
    }
    LaunchPanel := Gui("+Owner" Panel.Hwnd,"Chrome sessions")
    g := LaunchPanel
    g.BackColor := "F4F6FA"
    g.SetFont("s15 w600 c172033","Segoe UI")
    g.AddText("x22 y18 w590 h30","Separate Chrome sessions")
    g.SetFont("s10 w400 c637087")
    g.AddText("x22 y58 w590 h62","Fresh, separate Chrome sessions every time you open them.`nCookies and logins are never reused, even with the same session number.`nClose all windows belonging to a session to end it.")
    g.AddText("x22 y136 w180 h24","Website")
    file := A_ScriptDir "\chrome-sessions.ini"
    url := g.AddEdit("x22 y165 w590 h30",IniRead(file,"Launcher","url","about:blank"))
    g.AddText("x22 y213 w265 h24","Number of sessions")
    count := g.AddEdit("x22 y242 w265 h30",IniRead(file,"Launcher","count",3))
    g.AddText("x325 y213 w265 h24","Start numbering at")
    first := g.AddEdit("x325 y242 w287 h30",IniRead(file,"Launcher","first",1))
    note := g.AddText("x22 y290 w590 h60","Temporary profiles are cleaned up after Chrome exits. Each launch is always new.`nKeep the same browser size and zoom when reusing your saved click points.")
    openBtn := g.AddButton("x22 y366 w170 h36","Open sessions")
    openBtn.OnEvent("Click",(*) => QueueChromeSessions(url,count,first,note,openBtn))
    g.AddButton("x206 y366 w170 h36","Stop opening / close").OnEvent("Click",(*) => CloseChromeSessions())
    g.OnEvent("Close",(*) => CloseChromeSessions())
    g.Show("w634 h425")
}
FindChrome() {
    for path in [A_ProgramFiles "\Google\Chrome\Application\chrome.exe",EnvGet("ProgramFiles(x86)") "\Google\Chrome\Application\chrome.exe",EnvGet("LOCALAPPDATA") "\Google\Chrome\Application\chrome.exe"]
        if FileExist(path)
            return path
    throw Error("Google Chrome was not found. Install Chrome, then try again.")
}
ValidateLaunch(url,count,first) {
    url := Trim(url)
    if url != "about:blank" && !RegExMatch(url,"i)^https?://[^\s" Chr(34) "]+$")
        throw Error("Use an http:// or https:// website address, or about:blank.")
    for value in [count,first]
        if !RegExMatch(value,"^\d+$") || value+0 < 1 || value+0 > 2147483647
            throw Error("Session count and starting number must be positive whole numbers.")
    if count+0 + first+0 > 2147483648
        throw Error("Session number is too large.")
    return {url:url,count:Integer(count),first:Integer(first)}
}
ChromeSessionCommand(exe,folder,url) {
    ; Each path and URL is a separate quoted argument. No shell is used.
    q := Chr(34)
    for part in [exe,folder,url]
        if InStr(part,q) || InStr(part,"`n") || InStr(part,"`r")
            throw Error("Invalid character in launch value")
    return q exe q " --user-data-dir=" q folder q " --incognito --disable-background-mode --no-first-run --no-default-browser-check --start-maximized --new-window " q url q
}
QueueChromeSessions(urlControl,countControl,firstControl,note,button) {
    global LaunchQueue
    if IsObject(LaunchQueue)
        return
    try {
        options := ValidateLaunch(urlControl.Value,Trim(countControl.Value),Trim(firstControl.Value))
        exe := FindChrome()
        if !FileExist(A_ScriptDir "\chrome-session-cleanup.ahk")
            throw Error("Keep chrome-session-cleanup.ahk beside this script.")
        file := A_ScriptDir "\chrome-sessions.ini"
        IniWrite options.url,file,"Launcher","url"
        IniWrite options.count,file,"Launcher","count"
        IniWrite options.first,file,"Launcher","first"
        LaunchQueue := {exe:exe,url:options.url,next:options.first,left:options.count,total:options.count,note:note,button:button}
        button.Enabled := false
        note.Text := "Opening sessions. You can stop the queue at any time."
        SetTimer LaunchNextChrome,-1
    } catch Error as err {
        note.Text := err.Message
    }
}
LaunchNextChrome() {
    global LaunchQueue
    if !IsObject(LaunchQueue)
        return
    job := LaunchQueue
    try {
        folder := FreshChromeFolder(job.next)
        DirCreate folder
        marker := folder "\.disposable-session.ini"
        IniWrite "controller-temporary-chrome-v1",marker,"Owner","kind"
        Run ChromeSessionCommand(job.exe,folder,job.url),,, &browserPid
        IniWrite browserPid,marker,"Owner","pid"
        q := Chr(34)
        Run q A_AhkPath q " " q A_ScriptDir "\chrome-session-cleanup.ahk" q " " q folder q " " browserPid,,"Hide"
        job.left -= 1
        job.note.Text := "Opened session " job.next ". " (job.total-job.left) " / " job.total "."
        job.next += 1
        if job.left > 0
            SetTimer LaunchNextChrome,-600
        else {
            job.note.Text := "Fresh Chrome sessions opened. Navigate to your page, then use Add windows - reuse 3 points. No previous cookies were reused."
            job.button.Enabled := true
            LaunchQueue := 0
        }
    } catch Error as err {
        job.note.Text := err.Message
        job.button.Enabled := true
        LaunchQueue := 0
    }
}
CloseChromeSessions() {
    global LaunchQueue, LaunchPanel
    SetTimer LaunchNextChrome,0
    LaunchQueue := 0
    if IsObject(LaunchPanel)
        LaunchPanel.Destroy()
    LaunchPanel := 0
}


BeginPeriodicCapture() {
    global CaptureTarget, CaptureCountdown
    if Running
        return
    if IsObject(CaptureDraft) {
        Status.Text := "Finish or cancel the three-point recording first."
        return
    }
    HidePreview()
    CaptureTarget := {periodic:true}, CaptureCountdown := 3
    Status.Text := "Hover over the extra button in an assigned browser for 3 seconds."
    SetTimer CaptureFieldTick,1000
}
SavePeriodicPoint(root,x,y) {
    global PeriodicPoint
    selected := 0
    for t in Targets {
        if t.hwnd = root && WinExist("ahk_id " root) && WinGetPID("ahk_id " root) = t.pid {
            selected := t
            break
        }
    }
    if !IsObject(selected)
        throw Error("Record the extra click inside one of your assigned browsers.")
    WinGetClientPos ,,&w,&h,"ahk_id " root
    if w != selected.point.w || h != selected.point.h
        throw Error("Browser size changed; restore its recorded size first.")
    pt := MapPoint(0,root,x,y)
    if pt.x < 0 || pt.y < 0 || pt.x >= w || pt.y >= h
        throw Error("Hover inside the browser content.")
    value := {x:pt.x,y:pt.y,w:w,h:h}
    WritePeriodicSettings(PeriodicEvery,value)
    PeriodicPoint := value
    UpdatePeriodicLabel()
    Status.Text := "Extra click saved for matching-size browsers."
}
SavePeriodicInterval() {
    global PeriodicEvery
    if Running
        return
    try {
        value := PeriodicInput.Value
        if !RegExMatch(value,"^\d+$") || value > 2147483647
            throw Error("Enter a whole loop count from 0 to 2147483647.")
        value := Integer(value)
        WritePeriodicSettings(value,PeriodicPoint)
        PeriodicEvery := value
        UpdatePeriodicLabel()
        Status.Text := "Extra-click interval saved."
    } catch Error as err {
        Status.Text := err.Message
    }
}
WritePeriodicSettings(every,point) {
    file := A_ScriptDir "\controller-sequence-periodic.ini", tmp := file ".pending"
    if FileExist(tmp)
        FileDelete tmp
    IniWrite every,tmp,"ExtraClick","Every"
    if IsObject(point)
        for key in ["x","y","w","h"]
            IniWrite point.%key%,tmp,"ExtraClick",key
    FileMove tmp,file,1
}
LoadPeriodicSettings() {
    global PeriodicEvery, PeriodicPoint
    file := A_ScriptDir "\controller-sequence-periodic.ini"
    try {
        every := Integer(IniRead(file,"ExtraClick","Every",10))
        if every < 0 || every > 2147483647
            throw Error("Invalid loop interval")
        PeriodicEvery := every
        if IniRead(file,"ExtraClick","x","") != "" {
            pt := {}
            for key in ["x","y","w","h"]
                pt.%key% := Integer(IniRead(file,"ExtraClick",key))
            if pt.x < 0 || pt.y < 0 || pt.x >= pt.w || pt.y >= pt.h
                throw Error("Invalid extra point")
            PeriodicPoint := pt
        }
    } catch {
        PeriodicPoint := 0
        Status.Text := "Extra-click settings could not load; record the point again."
    }
    PeriodicInput.Value := PeriodicEvery
    UpdatePeriodicLabel()
}
UpdatePeriodicLabel() {
    if !IsObject(PeriodicPoint) {
        PeriodicLabel.Text := "No extra click recorded. The existing loop runs normally."
        return
    }
    PeriodicLabel.Text := "Saved extra point: X " PeriodicPoint.x ", Y " PeriodicPoint.y " (browser client coordinates)."
        . "`nRecorded client size: " PeriodicPoint.w " × " PeriodicPoint.h
        . "`n" (PeriodicEvery ? "Clicks once after every " PeriodicEvery " completed loops in each browser." : "Extra click is turned off; the point remains saved.")
}


FreshChromeFolder(number) {
    guid := Buffer(16,0), text := Buffer(78,0)
    if DllCall("ole32\CoCreateGuid","Ptr",guid,"Int") != 0
        throw Error("Could not create a fresh session ID")
    DllCall("ole32\StringFromGUID2","Ptr",guid,"Ptr",text,"Int",39)
    token := Trim(StrGet(text,"UTF-16"),"{}")
    return A_ScriptDir "\chrome-sessions-temporary\session-" number "-" token
}
