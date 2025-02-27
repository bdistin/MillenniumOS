; G37.g: TOOL LENGTH PROBE: EXECUTE

; Probe the current tool length and save its offset.
;
; When running a toolsetter on its' own, the only important
; thing is the difference in length between two tools. We
; use the manually-probed position of the toolsetter activation
; switch with a datum tool to identify the offset of each
; subsequent tool. This offset might be positive or negative
; depending on if the tool is longer than the datum tool or not.

; With a touch probe, we cannot know the installed length of the
; probe itself, because we cannot activate the toolsetter with the
; touch probe at the same point. We use a reference surface whose
; relative position with the toolsetter activation point does not
; change, and we probe this whenever the touch probe is plugged in.
; Our offsets then take this distance into account, so they know
; where the toolsetter switch _should_ activate with an installed
; datum tool, and calculate the offset from that.

; With no toolsetter or touch probe installed, zeroing each tool
; is manual. We can guide the user to move the tool to touch a
; particular surface and calculate the offset based on that.
; TODO: Pick a surface and probe it manually, does the reference
; surface work for this?
;
;
; USAGE: "G37"
;
; NOTE: This is designed to work with a NEGATIVE Z - that is, MAX is 0 and MIN is -<something>

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Make sure we're in the default motion system
M598

; Without a toolsetter, the operator will have to zero the tool themselves.
if { ! global.mosFeatToolSetter }
    abort { "Tool length probing without a toolsetter is not currently supported!" }

if { global.mosFeatTouchProbe && global.mosTSAP == null }
    abort { "Touch probe feature is enabled but reference surface has not been probed. Please run <b>G6511</b> before probing tool lengths!" }

G27 Z1    ; park spindle

if { state.status == "paused" }
    M291 P{"Cannot run G37 while paused due to safety concerns around resume positions ignoring axis limits."} R"MillenniumOS: Tool Change" S3
    M99


; Offsets are calculated based on our mosTSP[2] which
; is the activation point of the toolsetter with a dowel installed.
; Due to the Z movement limits of the machine, the installed dowel
; will need to have ~15-20mm of stickout to be able to reach the
; reference surface.

; All tool length offsets are relative to this, so we can have both
; positive and negative offsets depending on if the tool is shorter
; (positive) or longer (negative) than the dowel used to calibrate
; the toolsetter.

if { state.currentTool == -1 }
    abort { "No tool selected. Run <b>T<N> P0</b> to select a tool before running G37 manually!" }

; Reset the tool offset before probing
G10 P{state.currentTool} Z0

echo {"Probing tool #" ^ state.currentTool ^ " length at X=" ^ global.mosTSP[0] ^ ", Y=" ^ global.mosTSP[1] }

; TODO: Should we probe towards global.mosTSP[2] minus a static value
; rather than the axis minimum? Right now, if we miss the toolsetter
; due to a homing issue or missing steps, there's a high chance we
; will plunge the tool into the table.

; Probe towards axis minimum until toolsetter is activated
G6512 I{global.mosTSID} J{global.mosTSP[0]} K{global.mosTSP[1]} L{move.axes[2].max} Z{move.axes[2].min}

; If touch probe is configured, then our position in Z is relative to
; the installed height of the touch probe, which we don't know. What we
; _do_ know is the Z co-ordinate of a reference surface probed by both
; the 'datum tool' and the touch probe, and the Z co-ordinate of the
; expected activation point of the toolsetter when activated by the
; datum tool.
; Using this, we calculate the expected activation point of the toolsetter
; based on the reference surface probed height, and then calculate our
; offset from there instead.

var toolOffset = 0
if { global.mosFeatTouchProbe }
    set var.toolOffset = { -(global.mosPCZ - global.mosTSAP) }
else
    set var.toolOffset = { -(abs(global.mosTSP[2]) - abs(global.mosPCZ)) }

echo {"Tool #" ^ state.currentTool ^ " Offset=" ^ var.toolOffset ^ "mm"}

; Park spindle in Z ready for next operation
G27 Z1

G10 P{state.currentTool} X0 Y0 Z{var.toolOffset}
