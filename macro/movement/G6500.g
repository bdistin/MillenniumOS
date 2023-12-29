; G6500.g: PROBE WORK PIECE - BORE
;
; Meta macro to gather operator input before executing a
; bore probe cycle (G6500.1). The macro will explain to
; the operator what is about to happen and ask for an
; approximate bore diameter. The macro will then ask the
; operator to jog the probe into the center of the bore
; and hit OK, at which point the bore probe cycle will
; be executed.

if { !global.expertMode }
    M291 P"This operation finds the center of a circular bore by probing outwards in 3 directions. You will be asked to enter a bore diameter, an overtravel distance and to jog the touch probe into the bore, below the top surface." R"Probe: BORE" J1 T0 S3
    if { result != 0 }
        abort { "Bore probe aborted!" }

; Prompt for bore diameter
M291 P"Please enter approximate bore diameter. This is used to set our probing distance." R"Probe: BORE" J1 T0 S6 F6.0
if { result != 0 }
    abort { "Bore probe aborted!" }
else
    var boreDiameter = { input }

    ; Prompt for overtravel distance
    M291 P"Please enter overtravel distance in mm. This is added to the approximate bore diameter and is how far the probe will move outwards from the centerpoint when trying to find the bore edge." R"Probe: BORE" J1 T0 S6 F{global.mosProbeOvertravel}
    if { result != 0 }
        abort { "Bore probe aborted!" }
    else
        var overTravel = { input }
        M291 P"Please jog the probe into the bore, below the top surface and press OK." R"Probe: BORE" X1 Y1 Z1 J1 T0 S3
        if { result != 0 }
            abort { "Bore probe aborted!" }
        else
            ; Run the bore probe cycle
            G6500.1 W{param.W} H{var.boreDiameter} O{var.overTravel} J{move.axes[global.mosIX].machinePosition} K{move.axes[global.mosIY].machinePosition} L{move.axes[global.mosIZ].machinePosition}
