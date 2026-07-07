#Requires AutoHotkey v2.0
#SingleInstance Force
;==============================================================================
; Bail Onus Finder  (rules as of July 18, 2026)
;
; Walks the user through a questionnaire and determines whether bail is CROWN
; ONUS or REVERSE ONUS. If reverse onus, the triggering section numbers (only)
; are copied to the clipboard.
;
; NOTE: rules.md line 12 wrote "525(6)(c)" for the s.145(2)-(5)-while-at-large
;       condition. There is no s.525(6)(c); the correct reverse-onus provision
;       is 515(6)(c), which is what is used below. Change the string on that
;       line if the literal "525(6)(c)" is genuinely intended.
;==============================================================================

; ---- Rule data --------------------------------------------------------------
; Reverse-onus conditions that apply REGARDLESS of offence classification.
groupA := [
    ["A s.524 application has been granted",                                                              "524(4)"],
    ["IPV offence (incl. sexual offence, crim. harassment, HT) AND accused was previously convicted or"
        . " discharged (discharge still on CPIC) for an IPV offence",                                     "515(6)(b.1)"],
    ["IPV offence AND at the time of the offence accused was on an IPV peace bond under s.810",            "515(6)(b.1)"],
    ["Offence under s.145(2)-(5) while at large after being released for another Code offence",           "515(6)(c)"],
    ["CDSA offence punishable by life under ss.5-7, or a conspiracy for such an offence",                 "515(6)(d)"],
    ["Breach of a conditional sentence order",                                                            "742.6(2)"]
]

; Reverse-onus conditions that apply ONLY where the offence is a straight
; indictable offence OR a hybrid offence for which the Crown has NOT elected
; to proceed summarily.
groupB := [
    ["Accused not ordinarily resident in Canada",                                                         "515(6)(b)"],
    ["Any assault or sexual assault where choking, suffocating or strangling is alleged",                 "515(6)(a)(ix)"],
    ["Accused was on release for a straight indictable / hybrid-not-elected-summarily offence",           "515(6)(a)(i)"],
    ["Firearm possession / non-use offence (ss.95, 98, 98.1, 99, 100, 102 or 103)",                       "515(6)(a)(vi)"],
    ["Offence committed with a firearm (ss.244, 244.2, 239, 272, 273, 279(1), 279.1, 344 or 346)",        "515(6)(a)(vi) to (vii)"],
    ["Firearm / ammo / prohibited weapon etc. offence while on a prohibition order",                      "515(6)(a)(viii)"],
    ["Human trafficking offence under s.279.01 or 279.011",                                               "515(6)(a)(x)"],
    ["Motor vehicle theft with violence (s.333.1(3)) or for the benefit of a criminal org (s.333.1(4))",  "515(6)(a)(xi)"],
    ["Extortion where violence or threats are alleged",                                                   "515(6)(a)(xii)"],
    ["Violent offence AND two or more prior commissions of violent offences (Crown not summary)",         "515(6)(a)(xii.1)"],
    ["Residential break & enter",                                                                         "515(6)(a)(xiii)"],
    ["Violent offence w/ weapon (10+ yr max) AND conviction in past 10 yrs in that category (Crown not summary)", "515(6)(b.2)"],
    ["Certain criminal organization, terrorism, or other-Act offences",                                  "515(6)(a)(ii) to (v) and (xiv)"]
]

; ---- Build the GUI ----------------------------------------------------------
g := Gui("+Resize", "Bail Onus Finder")
g.SetFont("s9", "Segoe UI")
g.MarginX := 14
g.MarginY := 12

g.SetFont("s11 Bold")
g.Add("Text", "xm w620", "Bail Onus Finder")
g.SetFont("s8 Norm cGray")
g.Add("Text", "xm w620", "Rules as of July 18, 2026. Answer the questions, then click Determine Onus.")
g.SetFont("s9 Norm")

; Step 1 - youth vs adult
g.SetFont("s9 Bold")
g.Add("Text", "xm w620 y+12", "1.  Is this a youth matter or an adult matter?")
g.SetFont("s9 Norm")
rbAdult := g.Add("Radio", "xm+16 y+6 Checked", "Adult")
rbYouth := g.Add("Radio", "xm+16 y+4", "Youth  (YCJA — always Crown Onus)")

; Step 2 - conditions that apply regardless of classification
g.SetFont("s9 Bold")
g.Add("Text", "xm w620 y+14", "2.  Do any of these apply?  (apply regardless of offence classification)")
g.SetFont("s9 Norm")
cbA := []
for item in groupA {
    c := g.Add("Checkbox", "xm+16 y+6 w600", item[1])
    cbA.Push({ ctrl: c, sec: item[2], label: CleanLabel(item[1]) })
}

; Step 3 - offence classification gate
g.SetFont("s9 Bold")
g.Add("Text", "xm w620 y+14", "3.  Offence classification")
g.SetFont("s9 Norm")
clsCB := g.Add("Checkbox", "xm+16 y+6 w600",
    "Charged with a straight indictable offence, OR a hybrid offence for which the Crown has NOT elected summarily")

; Step 4 - conditions that only apply on the indictable / not-summary track
g.SetFont("s9 Bold")
lblB := g.Add("Text", "xm w620 y+12", "4.  Do any of these apply?  (only if box in step 3 is checked)")
g.SetFont("s9 Norm")
cbB := []
for item in groupB {
    c := g.Add("Checkbox", "xm+16 y+6 w600", item[1])
    cbB.Push({ ctrl: c, sec: item[2], label: CleanLabel(item[1]) })
}

; Buttons
btnGo := g.Add("Button", "xm y+16 w150 Default", "Determine Onus")
btnReset := g.Add("Button", "x+10 yp w110", "Reset")
btnClose := g.Add("Button", "x+10 yp w110", "Close")

; ---- Wire up events ---------------------------------------------------------
rbAdult.OnEvent("Click", UpdateEnabled)
rbYouth.OnEvent("Click", UpdateEnabled)
clsCB.OnEvent("Click", UpdateEnabled)
btnGo.OnEvent("Click", DetermineOnus)
btnReset.OnEvent("Click", ResetForm)
btnClose.OnEvent("Click", (*) => g.Destroy())

UpdateEnabled()          ; set initial enabled/disabled state
g.Show()
return

; ---- Logic ------------------------------------------------------------------
UpdateEnabled(*) {
    global cbA, cbB, clsCB, lblB, rbAdult
    isAdult := rbAdult.Value

    for it in cbA
        it.ctrl.Enabled := isAdult
    clsCB.Enabled := isAdult

    bOn := isAdult && clsCB.Value
    lblB.Enabled := bOn
    for it in cbB
        it.ctrl.Enabled := bOn
}

DetermineOnus(*) {
    global cbA, cbB, clsCB, rbYouth

    ; Youth is always Crown Onus (YCJA) - overrides everything else.
    if (rbYouth.Value) {
        MsgBox("Result:  CROWN ONUS`n`nOnus for youth matters is always Crown Onus (YCJA).",
            "Bail Onus Finder", "Iconi")
        return
    }

    sections := []
    reasons  := []

    for it in cbA
        if (it.ctrl.Value) {
            AddUnique(sections, it.sec)
            reasons.Push(it.label " → " it.sec)
        }

    if (clsCB.Value)
        for it in cbB
            if (it.ctrl.Value) {
                AddUnique(sections, it.sec)
                reasons.Push(it.label " → " it.sec)
            }

    if (sections.Length = 0) {
        MsgBox("Result:  CROWN ONUS`n`nNone of the reverse-onus conditions apply.",
            "Bail Onus Finder", "Iconi")
        return
    }

    ; Reverse onus - put the section numbers (only), comma-separated, on the clipboard.
    clip := ""
    for s in sections
        clip .= (clip = "" ? "" : ", ") s
    A_Clipboard := clip

    ShowReverseResult(clip, reasons)
}

ShowReverseResult(clip, reasons) {
    why := ""
    for r in reasons
        why .= "   • " r "`n"
    why := RTrim(why, "`n")

    r := Gui("+Owner", "Bail Onus Finder — Result")
    r.SetFont("s9", "Segoe UI")
    r.MarginX := 14
    r.MarginY := 12

    r.SetFont("s11 Bold cRed")
    r.Add("Text", "xm w440", "Result:  REVERSE ONUS")
    r.SetFont("s9 Norm")

    r.Add("Text", "xm w440 y+12", "Section numbers (copied to clipboard):")
    ; Read-only but fully selectable/copyable preview of the clipboard contents.
    edit := r.Add("Edit", "xm w440 y+4 r1 ReadOnly", clip)

    r.Add("Text", "xm w440 y+12", "Reasons:")
    r.Add("Edit", "xm w440 y+4 r" (reasons.Length < 8 ? reasons.Length : 8) " ReadOnly -Wrap +HScroll", why)

    btnCopy := r.Add("Button", "xm y+14 w150 Default", "Copy to clipboard again")
    btnOk := r.Add("Button", "x+10 yp w110", "Close")
    btnCopy.OnEvent("Click", ReCopy)
    btnOk.OnEvent("Click", (*) => r.Destroy())
    ReCopy(*) {
        A_Clipboard := clip
        ToolTip("Copied: " clip)
        SetTimer(() => ToolTip(), -1500)
    }

    r.Show()
}

ResetForm(*) {
    global cbA, cbB, clsCB, rbAdult
    rbAdult.Value := true
    clsCB.Value := false
    for it in cbA
        it.ctrl.Value := false
    for it in cbB
        it.ctrl.Value := false
    UpdateEnabled()
}

; ---- Helpers ----------------------------------------------------------------
AddUnique(arr, val) {
    for v in arr
        if (v = val)
            return
    arr.Push(val)
}

CleanLabel(txt) {
    ; collapse any wrapped/continuation whitespace into single spaces for display
    return RegExReplace(txt, "\s+", " ")
}
