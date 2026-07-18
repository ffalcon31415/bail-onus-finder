#Requires AutoHotkey v2.0
#SingleInstance Force
;==============================================================================
; Bail Onus Finder  (rules as of July 18, 2026)
;
; A step-by-step questionnaire that determines whether bail is CROWN ONUS or
; REVERSE ONUS. If reverse onus, the triggering section numbers (only), comma-
; separated, are placed on the clipboard.
;
; Flow:
;   Step 1  Youth vs Adult      -> Youth finishes immediately (Crown, YCJA)
;   Step 2  Checklist A         -> conditions that apply regardless of class.
;   Step 3  Indictable? (gate)  -> straight indictable / hybrid-not-summary?
;   Step 4  Checklist B         -> shown ONLY if step 3 is "Yes"
;
; The reverse-onus conditions live in an editable config file (OnusRules.txt),
; loaded at startup. Edit that file to change the questionnaire - no code needed.
;==============================================================================

; ---- Rule data (populated from OnusRules.txt) -------------------------------
groupA := []      ; Checklist A - apply REGARDLESS of offence classification
groupB := []      ; Checklist B - apply only on the indictable / not-summary track
LoadRules()

; ---- Shared state across steps (lets Back/Start-over restore selections) -----
state := { isYouth: false, indictable: false, aVals: [], bVals: [] }
ResetState()
StepYouthAdult()      ; launch the wizard
return

; ---- Load the rule config ---------------------------------------------------
LoadRules() {
    global groupA, groupB
    path := A_ScriptDir "\OnusRules.txt"
    if !FileExist(path) {
        MsgBox("Configuration file not found:`n`n" path "`n`n"
            . "OnusRules.txt must sit in the same folder as this script.",
            "Bail Onus Finder", "Iconx")
        ExitApp()
    }

    target := ""
    for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
        t := Trim(line)
        if (t = "" || SubStr(t, 1, 1) = ";")
            continue                                  ; blank line or comment
        if (SubStr(t, 1, 1) = "[" && SubStr(t, -1) = "]") {
            name := StrUpper(Trim(SubStr(t, 2, StrLen(t) - 2)))
            target := (name = "ALWAYS") ? "A" : (name = "INDICTABLE") ? "B" : ""
            continue                                  ; section header
        }
        pos := InStr(t, "|")
        if (!pos || target = "")
            continue                                  ; skip malformed / ungrouped
        sec  := Trim(SubStr(t, 1, pos - 1))
        desc := Trim(SubStr(t, pos + 1))
        if (sec = "" || desc = "")
            continue
        (target = "A" ? groupA : groupB).Push([desc, sec])
    }

    if (groupA.Length = 0 && groupB.Length = 0) {
        MsgBox("No rules were loaded from:`n`n" path "`n`n"
            . "Check that it contains [ALWAYS] / [INDICTABLE] sections with "
            . "'section | description' lines.",
            "Bail Onus Finder", "Iconx")
        ExitApp()
    }
}

ResetState() {
    global state, groupA, groupB
    state.isYouth := false
    state.indictable := true
    state.aVals := []
    state.bVals := []
    Loop groupA.Length
        state.aVals.Push(false)
    Loop groupB.Length
        state.bVals.Push(false)
}

; ---- Step 1: Youth vs Adult -------------------------------------------------
StepYouthAdult(*) {
    global state
    g := NewStep("Step 1 of 4")
    g.SetFont("s14 Bold")
    g.Add("Text", "xm w700", "Is this a youth matter or an adult matter?")
    g.SetFont("s12 Norm")
    rbAdult := g.Add("Radio", "xm+8 y+10", "Adult")
    rbYouth := g.Add("Radio", "xm+8 y+6", "Youth  (YCJA — always Crown Onus)")
    (state.isYouth ? rbYouth : rbAdult).Value := true

    btnNext := g.Add("Button", "xm y+18 w150 Default", "Next  ▶")
    btnNext.OnEvent("Click", NextH)
    g.Show()

    NextH(*) {
        state.isYouth := rbYouth.Value ? true : false
        g.Destroy()
        if (state.isYouth)
            ShowCrown("Onus for youth matters is always Crown Onus (YCJA).")
        else
            StepGroupA()
    }
}

; ---- Step 2: Checklist A ----------------------------------------------------
StepGroupA(*) {
    global groupA, state
    g := NewStep("Step 2 of 4")
    g.SetFont("s14 Bold")
    g.Add("Text", "xm w700", "Do any of these apply?")
    g.SetFont("s11 Norm")
    g.Add("Text", "xm w700", "These trigger reverse onus regardless of offence classification.")
    g.SetFont("s12 Norm")

    ctrls := []
    for i, item in groupA {
        c := g.Add("Checkbox", "xm+8 y+8 w684", item[1])
        c.Value := state.aVals[i]
        ctrls.Push(c)
    }

    btnBack := g.Add("Button", "xm y+18 w130", "◀  Back")
    btnNext := g.Add("Button", "x+8 yp w150 Default", "Next  ▶")
    Save() {
        for i, c in ctrls
            state.aVals[i] := c.Value ? true : false
    }
    btnBack.OnEvent("Click", (*) => (Save(), g.Destroy(), StepYouthAdult()))
    btnNext.OnEvent("Click", (*) => (Save(), g.Destroy(), StepIndictable()))
    g.Show()
}

; ---- Step 3: Indictable gate ------------------------------------------------
StepIndictable(*) {
    global state
    g := NewStep("Step 3 of 4")
    g.SetFont("s14 Bold")
    g.Add("Text", "xm w700", "Offence classification")
    g.SetFont("s12 Norm")
    g.Add("Text", "xm w700 y+8",
        "Is the offence a straight indictable offence, OR a hybrid offence for which the Crown has NOT elected to proceed summarily?")
    rbYes := g.Add("Radio", "xm+8 y+10", "Yes")
    rbNo  := g.Add("Radio", "xm+8 y+6", "No")
    (state.indictable ? rbYes : rbNo).Value := true

    btnBack := g.Add("Button", "xm y+18 w130", "◀  Back")
    btnNext := g.Add("Button", "x+8 yp w150 Default", "Next  ▶")
    btnBack.OnEvent("Click", (*) => (Save(), g.Destroy(), StepGroupA()))
    btnNext.OnEvent("Click", NextH)
    g.Show()

    Save() {
        state.indictable := rbYes.Value ? true : false
    }
    NextH(*) {
        Save()
        g.Destroy()
        if (state.indictable)
            StepGroupB()
        else
            Finish()
    }
}

; ---- Step 4: Checklist B (only reached when step 3 = Yes) -------------------
StepGroupB(*) {
    global groupB, state
    g := NewStep("Step 4 of 4")
    g.SetFont("s14 Bold")
    g.Add("Text", "xm w700", "Do any of these apply?")
    g.SetFont("s11 Norm")
    g.Add("Text", "xm w700", "Straight indictable / hybrid-not-summary track only.")
    g.SetFont("s12 Norm")

    ctrls := []
    for i, item in groupB {
        c := g.Add("Checkbox", "xm+8 y+8 w684", item[1])
        c.Value := state.bVals[i]
        ctrls.Push(c)
    }

    btnBack := g.Add("Button", "xm y+18 w130", "◀  Back")
    btnDone := g.Add("Button", "x+8 yp w190 Default", "Determine Onus")
    Save() {
        for i, c in ctrls
            state.bVals[i] := c.Value ? true : false
    }
    btnBack.OnEvent("Click", (*) => (Save(), g.Destroy(), StepIndictable()))
    btnDone.OnEvent("Click", (*) => (Save(), g.Destroy(), Finish()))
    g.Show()
}

; ---- Compute the result -----------------------------------------------------
Finish() {
    global groupA, groupB, state
    sections := [], reasons := []

    for i, item in groupA
        if (state.aVals[i]) {
            AddUnique(sections, item[2])
            reasons.Push(CleanLabel(item[1]) " → " item[2])
        }

    if (state.indictable)
        for i, item in groupB
            if (state.bVals[i]) {
                AddUnique(sections, item[2])
                reasons.Push(CleanLabel(item[1]) " → " item[2])
            }

    if (sections.Length = 0) {
        ShowCrown("None of the reverse-onus conditions apply.")
        return
    }

    clip := ""
    for s in sections
        clip .= (clip = "" ? "" : ", ") s
    ShowReverseResult(clip, reasons)
}

; ---- Result windows ---------------------------------------------------------
ShowCrown(msg) {
    r := NewStep("Result")
    r.SetFont("s16 Bold c000000")
    r.Add("Text", "xm w560", "Result:  CROWN ONUS")
    r.SetFont("s12 Norm")
    r.Add("Text", "xm w560 y+12", msg)
    btnRestart := r.Add("Button", "xm y+18 w110", "Start over")
    btnClose := r.Add("Button", "x+8 yp w110 Default", "Close")
    btnRestart.OnEvent("Click", (*) => (r.Destroy(), ResetState(), StepYouthAdult()))
    btnClose.OnEvent("Click", (*) => r.Destroy())
    r.Show()
}

ShowReverseResult(clip, reasons) {
    why := ""
    for r0 in reasons
        why .= "   • " r0 "`n"
    why := RTrim(why, "`n")

    r := NewStep("Result")
    r.SetFont("s16 Bold c000000")
    r.Add("Text", "xm w560", "Result:  REVERSE ONUS")
    r.SetFont("s12 Norm")

    r.Add("Text", "xm w560 y+12", "Section numbers:")
    ; Read-only but fully selectable/copyable preview; nothing is copied until the button is clicked.
    r.Add("Edit", "xm w560 y+4 r1 ReadOnly", clip)

    r.Add("Text", "xm w560 y+12", "Reasons:")
    r.Add("Edit", "xm w560 y+4 r" (reasons.Length < 8 ? reasons.Length : 8) " ReadOnly -Wrap +HScroll", why)

    btnCopy := r.Add("Button", "xm y+16 w220 Default", "Copy to clipboard")
    btnRestart := r.Add("Button", "x+8 yp w130", "Start over")
    btnClose := r.Add("Button", "x+8 yp w110", "Close")
    btnCopy.OnEvent("Click", ReCopy)
    btnRestart.OnEvent("Click", (*) => (r.Destroy(), ResetState(), StepYouthAdult()))
    btnClose.OnEvent("Click", (*) => r.Destroy())

    ReCopy(*) {
        A_Clipboard := clip
        ToolTip("Copied: " clip)
        SetTimer(() => ToolTip(), -1500)
    }
    r.Show()
}

; ---- Helpers ----------------------------------------------------------------
NewStep(subtitle) {
    g := Gui("+AlwaysOnTop", "Bail Onus Finder — " subtitle)
    g.SetFont("s12 c000000", "Segoe UI")
    g.MarginX := 16
    g.MarginY := 14
    g.OnEvent("Close", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    return g
}

AddUnique(arr, val) {
    for v in arr
        if (v = val)
            return
    arr.Push(val)
}

CleanLabel(txt) {
    return RegExReplace(txt, "\s+", " ")
}
