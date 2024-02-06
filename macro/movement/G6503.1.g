; G6502.1.g: RECTANGLE BLOCK - EXECUTE
;
; Probe the X and Y edges of a rectangular block.
; Calculate the dimensions of the block and set the
; WCS origin to the probed center of the block, if requested.

if { exists(param.W) && param.W != null && (param.W < 1 || param.W > #global.mosWorkOffsetCodes) }
    abort { "WCS number (W..) must be between 1 and " ^ #global.mosWorkOffsetCodes ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate width and length using H and I parameters!" }

var probeId = { global.mosFeatureTouchProbe ? global.mosTouchProbeID : null }

var clearance = { exists(param.T) ? param.T : global.mosProbeClearance }
var overtravel = { exists(param.O) ? param.O : global.mosProbeOvertravel }

M7500 S{"Clearance: " ^ var.clearance ^ " Overtravel: " ^ var.overtravel }

; Switch to probe tool if necessary
var needsProbeTool = { global.mosProbeToolID != state.currentTool }
if { var.needsProbeTool }
    T T{global.mosProbeToolID}

; J = start position X
; K = start position Y
; L = start position Z - our probe height
; H = approximate width of block in X
; I = approximate length of block in Y

; Approximate center of block
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }
var fW   = { param.H }
var fL   = { param.I }
var hW   = { var.fW/2 }
var hL   = { var.fL/2 }

; TODO: Start position should be center of Y when probing X,
; and calculated center of X when probing Y.

; We can calculate the squareness of the block by probing inwards
; from each edge and calculating an angle.
; Our start position is then inwards by the clearance distance from
; both ends of the face.
; We need 8 probes to calculate the squareness of the block (2 for each edge).

var pX = { null, null, null, null }
var pY = { null, null, null, null }

; We use D1 on all of our probe points. This means that the probe
; macro does not automatically move back to its' safe Z position after
; probing, and we must manage this ourselves.

; Store our own safe Z position as the current position. We return to
; this position where necessary to make moves across the workpiece to
; the next probe point.
var safeZ = { move.axes[2].machinePosition }

; First probe point - left edge, inwards from front face by clearance distance
; towards the face plus overtravel distance.
G6512 I{var.probeId} D1 J{(var.sX - var.hW - var.clearance)} K{(var.sY - var.hL + var.clearance)} L{param.L} X{(var.sX - var.hW + var.overtravel)}
set var.pX[0] = { global.mosProbeCoordinate[0] }

; Return to our starting position
G6550 X{(var.sX - var.hW - var.clearance)}

; Second probe point - left edge, inwards from rear face by clearance distance
; towards the face minus overtravel distance.
G6512 I{var.probeId} D1 J{(var.sX - var.hW - var.clearance)} K{(var.sY + var.hL - var.clearance)} L{param.L} X{(var.sX - var.hW + var.overtravel)}
set var.pX[1] = { global.mosProbeCoordinate[0] }

; Return to our starting position and then raise the probe
G6550 X{(var.sX - var.hW - var.clearance)}
G6550 Z{var.safeZ}

; NOTE: Second surface probes from the rear first
; as this shortens the movement distance.

; Third probe point - right edge, inwards from rear face by clearance distance
; towards the face minus overtravel distance.
G6512 I{var.probeId} D1 J{(var.sX + var.hW + var.clearance)} K{(var.sY + var.hL - var.clearance)} L{param.L} X{(var.sX + var.hW - var.overtravel)}
set var.pX[2] = { global.mosProbeCoordinate[0] }

; Return to our starting position
G6550 X{(var.sX + var.hW + var.clearance)}

; Fourth probe point - right edge, inwards from front face by clearance distance
; towards the face plus overtravel distance.
G6512 I{var.probeId} D1 J{(var.sX + var.hW + var.clearance)} K{(var.sY - var.hL + var.clearance)} L{param.L} X{(var.sX + var.hW - var.overtravel)}
set var.pX[3] = { global.mosProbeCoordinate[0] }

; Return to our starting position and then raise the probe
G6550 X{(var.sX + var.hW + var.clearance)}
G6550 Z{var.safeZ}

; Okay, we now have 2 'lines' representing the X edges of the block.
; Line 1: var.pX[0] to var.pX[1]
; Line 2: var.pX[2] to var.pX[3]

; These lines are not necessarily perpendicular to the X axis if the
; block or the vice is not trammed correctly with the probe.

; We may be able to compensate for this by applying a G68 co-ordinate
; rotation.

; They may also not be parallel to each other if the block itself
; is not completely square.

; If the lines are not parallel, we should abort if the angle is
; higher than a certain threshold.

; Calculate the angle of each line.
; We can calculate the angle of a line using the arctan of the slope.
; The slope of a line is the change in Y divided by the change in X.

; Our variable names are a bit confusing here, but we are using
; the X axis to probe the Y edges of the block, so we are calculating
; the angle of the Y edges of the block.

; Calculate the angle difference of each line.
var xA1 = { atan((var.pX[1] - var.pX[0]) / (var.fL - (2*var.clearance))) }
var xA2 = { atan((var.pX[2] - var.pX[3]) / (var.fL - (2*var.clearance))) }
var xAngleDiff = { degrees(abs(var.xA1 - var.xA2)) }

M7500 S{"X Surface Angle difference: " ^ var.xAngleDiff ^ " Threshold: " ^ global.mosProbeSquareAngleThreshold }

; If the angle difference is greater than a certain threshold, abort.
; We do this because the below code makes assumptions about the
; squareness of the block, and if these assumptions are not correct
; then there is a chance we could damage the probe or incorrectly
; calculate dimensions or centerpoint.
if { var.xAngleDiff > global.mosProbeSquareAngleThreshold }
    abort { "Rectangular block surfaces on X axis are not parallel - this block does not appear to be square. (" ^ var.xAngleDiff ^ " degrees difference in surface angle and our threshold is " ^ global.mosProbeSquareAngleThreshold ^ " degrees!)" }

; Now we have validated that the block is square in X, we need to calculate
; the real center position of the block so we can probe the Y surfaces.

; Our midpoint for each line is the average of the 2 points, so
; we can just add all of the points together and divide by 4.
set var.sX = { (var.pX[0] + var.pX[1] + var.pX[2] + var.pX[3]) / 4 }
set global.mosWorkPieceCenterPos[0] = { var.sX }

; Use the recalculated center of the block to probe Y surfaces.

; Probe Y surfaces

; First probe point - front edge, inwards from right face by clearance distance
; towards the face minus overtravel distance.
G6512 I{var.probeId} D1 K{(var.sY - var.hL - var.clearance)} J{(var.sX + var.hW - var.clearance)} L{param.L} Y{(var.sY - var.hL + var.overtravel)}
set var.pY[0] = { global.mosProbeCoordinate[1] }

; Return to our starting position
G6550 Y{(var.sY - var.hL - var.clearance)}

; Second probe point - front edge, inwards from left face by clearance distance
; towards the face plus overtravel distance.
G6512 I{var.probeId} D1 K{(var.sY - var.hL - var.clearance)} J{(var.sX - var.hW + var.clearance)} L{param.L} Y{(var.sY - var.hL + var.overtravel)}
set var.pY[1] = { global.mosProbeCoordinate[1] }

; Return to our starting position and then raise the probe
G6550 Y{(var.sY - var.hL - var.clearance)}
G6550 Z{var.safeZ}

; Third probe point - rear edge, inwards from left face by clearance distance
; towards the face plus overtravel distance.
G6512 I{var.probeId} D1 K{(var.sY + var.hL + var.clearance)} J{(var.sX - var.hW + var.clearance)} L{param.L} Y{(var.sY + var.hL - var.overtravel)}
set var.pY[2] = { global.mosProbeCoordinate[1] }

; Return to our starting position
G6550 Y{(var.sY + var.hL + var.clearance)}

; Fourth probe point - rear edge, inwards from right face by clearance distance
; towards the face minus overtravel distance.
G6512 I{var.probeId} D1 K{(var.sY + var.hL + var.clearance)} J{(var.sX + var.hW - var.clearance)} L{param.L} Y{(var.sY + var.hL - var.overtravel)}
set var.pY[3] = { global.mosProbeCoordinate[1] }

; Return to our starting position and then raise the probe
G6550 Y{(var.sY + var.hL + var.clearance)}
G6550 Z{var.safeZ}

; Okay like before, we now have 2 'lines' representing the Y edges of the block.
; Line 1: var.pY[0] to var.pY[1]
; Line 2: var.pY[2] to var.pY[3]

; Calculate the angle of each line.
var yA1 = { atan((var.pY[1] - var.pY[0]) / (var.fW - (2*var.clearance))) }
var yA2 = { atan((var.pY[2] - var.pY[3]) / (var.fW - (2*var.clearance))) }
var yAngleDiff = { degrees(abs(var.yA1 - var.yA2)) }

M7500 S{"Y Surface Angle difference: " ^ var.yAngleDiff ^ " Threshold: " ^ global.mosProbeSquareAngleThreshold }

; Abort if the angle difference is greater than a certain threshold like
; we did for the X axis.
if { var.yAngleDiff > global.mosProbeSquareAngleThreshold }
    abort { "Rectangular block surfaces on Y axis are not parallel - this block does not appear to be square. (" ^ var.yAngleDiff ^ " degrees difference in surface angle and our threshold is " ^ global.mosProbeSquareAngleThreshold ^ " degrees!)" }

M7500 S{"Surface Angles X1=" ^ degrees(var.xA1) ^ " X2=" ^ degrees(var.xA2) ^ " Y1=" ^ degrees(var.yA1) ^ " Y2=" ^ degrees(var.yA2) }

; Okay, we have now validated that the block surfaces are square in both X and Y.
; But this does not mean they are square to each other, so we need to calculate
; the angle of one corner between 2 lines and check it meets our threshold.
; If one of the corners is square, then the other corners must also be square -
; because the probed surfaces are sufficiently parallel.

; Calculate the angle of the corner between X line 1 and Y line 1.
; This is the angle of the front-left corner of the block.
; The angles are between the line and their respective axis, so
; a perfect 90 degree corner with completely squared machine axes
; would report an error of 0 degrees.
var cornerAngleError = { abs(degrees(var.xA1 - var.yA1)) }

M7500 S{"Rectangle Block Corner Angle Error: " ^ var.cornerAngleError }

; Abort if the corner angle is greater than a certain threshold.
if { (var.cornerAngleError > global.mosProbeSquareAngleThreshold) }
    abort { "Rectangular block corner angle is not 90 degrees - this block does not appear to be square. (" ^ var.cornerAngleError ^ " degrees difference in corner angle and our threshold is " ^ global.mosProbeSquareAngleThreshold ^ " degrees!)" }

; Calculate Y centerpoint as before.
set var.sY = { (var.pY[0] + var.pY[1] + var.pY[2] + var.pY[3]) / 4 }
set global.mosWorkPieceCenterPos[1] = { var.sY }

; We can now calculate the actual dimensions of the block.
; The dimensions are the difference between the average of each
; pair of points of each line.
set global.mosWorkPieceDimensions[0] = { ((var.pX[2] + var.pX[3]) / 2) - ((var.pX[0] + var.pX[1]) / 2) }
set global.mosWorkPieceDimensions[1] = { ((var.pY[2] + var.pY[3]) / 2) - ((var.pY[0] + var.pY[1]) / 2) }


; Calculate the rotation of the block against the X axis.
; After the checks above, we know the block is rectangular,
; within our threshold for squareness, but it might still be
; rotated in relation to our axes. At this point, the angle
; of the entire block's rotation can be assumed to be the same
; as the angle of the first X line.

; Calculate the slope and angle of the first X line.
set global.mosWorkPieceRotationAngle = var.xA1

M7500 S{"Rectangle Block Rotation from X axis: " ^ global.mosWorkPieceRotationAngle ^ " degrees" }

if { !global.mosExpertMode }
    ; Save as local variables because these variable names are
    ; hella long and the echo would otherwise exceed the
    ; maximum command length.
    var ctr = { global.mosWorkPieceCenterPos }
    var dim = { global.mosWorkPieceDimensions }
    var rot = { global.mosWorkPieceRotationAngle }
    echo { "Rectangle Block - Center X=" ^ var.ctr[0] ^ " Y=" ^ var.ctr[1] ^ " Dimensions X=" ^ var.dim[0] ^ " Y=" ^ var.dim[1] ^ " Rotation=" ^ var.rot ^ " degrees" }
else
    echo { "global.mosWorkPieceCenterPos=" ^ global.mosWorkPieceCenterPos }
    echo { "global.mosWorkPieceDimensions=" ^ global.mosWorkPieceDimensions }
    echo { "global.mosWorkPieceRotationAngle=" ^ global.mosWorkPieceRotationAngle }

; Set WCS origin to the probed center, if requested
if { exists(param.W) }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin to center of rectangle block" }
    G10 L2 P{param.W} X{global.mosWorkPieceCenterPos[0]} Y{global.mosWorkPieceCenterPos[1]}

; Save code of last probe cycle
set global.mosLastProbeCycle = "G6503"