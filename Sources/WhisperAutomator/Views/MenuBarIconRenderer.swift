import AppKit

/// Menu bar template icon: four rounded-L corner brackets + centred outline microphone.
/// Each bracket is drawn as one path (arm → explicit quad-curve vertex → arm) so the
/// corner bend is a large, clearly visible curve matching the reference artwork.
enum MenuBarIconRenderer {

    enum Kind: Hashable {
        case outlineMicrophone
        case filledMicrophone
        case transcribing
    }

    static func kind(for state: DictationController.DictationState) -> Kind {
        switch state {
        case .idle, .success, .error:   .outlineMicrophone
        case .recording:                .filledMicrophone
        case .transcribing:             .transcribing
        }
    }

    private static let outlineImage     = makeImage(kind: .outlineMicrophone)
    private static let filledImage      = makeImage(kind: .filledMicrophone)
    private static let transcribingImage = makeImage(kind: .transcribing)

    static func nsImage(for state: DictationController.DictationState) -> NSImage {
        switch kind(for: state) {
        case .outlineMicrophone:    outlineImage
        case .filledMicrophone:     filledImage
        case .transcribing:         transcribingImage
        }
    }

    // MARK: - Image factory

    private static func makeImage(kind: Kind) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { bounds in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            // Flip to a top-left / y-down user space so all coordinates read naturally.
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)

            let w = bounds.width, h = bounds.height

            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)   // belt-and-suspenders; vertices are explicit curves anyway
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setLineWidth(2.0)

            drawBrackets(ctx: ctx, w: w, h: h)

            switch kind {
            case .outlineMicrophone:    drawMic(ctx: ctx, w: w, h: h, filled: false)
            case .filledMicrophone:     drawMic(ctx: ctx, w: w, h: h, filled: true)
            case .transcribing:         drawDots(ctx: ctx, w: w, h: h)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Brackets
    //
    // Each bracket is one stroked path:
    //   end-of-arm-A  →  line to curve-start  →  quadCurve to curve-end  →  line to end-of-arm-B
    //
    // The quadratic control point sits exactly at the outer vertex, producing a smooth circular-arc
    // corner whose radius equals `cornerR`.  This is what gives the large rounded bend in the
    // reference rather than the hairline rounding from lineJoin alone.

    private static func drawBrackets(ctx: CGContext, w: CGFloat, h: CGFloat) {
        let inset:   CGFloat = 1.7   // center-of-stroke distance from canvas edge
        let armLen:  CGFloat = 4.6   // visible straight portion of each bracket arm
        let cornerR: CGFloat = 2.0   // quad-curve tangent offset → apparent corner radius

        let x0 = inset,         x1 = w - inset
        let y0 = inset,         y1 = h - inset
        let xa = inset + armLen, xb = w - inset - armLen
        let ya = inset + armLen, yb = h - inset - armLen

        // Top-left ────────────────────────────────────────────────────────────
        ctx.beginPath()
        ctx.move(to: CGPoint(x: xa, y: y0))
        ctx.addLine(to: CGPoint(x: x0 + cornerR, y: y0))
        ctx.addQuadCurve(to: CGPoint(x: x0, y: y0 + cornerR),
                         control: CGPoint(x: x0, y: y0))
        ctx.addLine(to: CGPoint(x: x0, y: ya))
        ctx.strokePath()

        // Top-right ───────────────────────────────────────────────────────────
        ctx.beginPath()
        ctx.move(to: CGPoint(x: xb, y: y0))
        ctx.addLine(to: CGPoint(x: x1 - cornerR, y: y0))
        ctx.addQuadCurve(to: CGPoint(x: x1, y: y0 + cornerR),
                         control: CGPoint(x: x1, y: y0))
        ctx.addLine(to: CGPoint(x: x1, y: ya))
        ctx.strokePath()

        // Bottom-left ─────────────────────────────────────────────────────────
        ctx.beginPath()
        ctx.move(to: CGPoint(x: xa, y: y1))
        ctx.addLine(to: CGPoint(x: x0 + cornerR, y: y1))
        ctx.addQuadCurve(to: CGPoint(x: x0, y: y1 - cornerR),
                         control: CGPoint(x: x0, y: y1))
        ctx.addLine(to: CGPoint(x: x0, y: yb))
        ctx.strokePath()

        // Bottom-right ────────────────────────────────────────────────────────
        ctx.beginPath()
        ctx.move(to: CGPoint(x: xb, y: y1))
        ctx.addLine(to: CGPoint(x: x1 - cornerR, y: y1))
        ctx.addQuadCurve(to: CGPoint(x: x1, y: y1 - cornerR),
                         control: CGPoint(x: x1, y: y1))
        ctx.addLine(to: CGPoint(x: x1, y: yb))
        ctx.strokePath()
    }

    // MARK: - Microphone
    //
    // Three separate stroked elements drawn in the same line-weight as the brackets:
    //   1. Rounded-rectangle capsule (the head)
    //   2. U-arch (the stand opening)
    //   3. Vertical stem + horizontal foot

    private static func drawMic(ctx: CGContext, w: CGFloat, h: CGFloat, filled: Bool) {
        let cx = w / 2

        // --- capsule (head) ---
        let capW:  CGFloat = 3.8
        let capH:  CGFloat = 6.4
        let capTop: CGFloat = 4.8
        let capR = capW / 2   // fully-rounded pill

        let capsule = CGPath(
            roundedRect: CGRect(x: cx - capW / 2, y: capTop, width: capW, height: capH),
            cornerWidth: capR, cornerHeight: capR,
            transform: nil
        )

        if filled {
            ctx.addPath(capsule); ctx.fillPath()
        } else {
            ctx.addPath(capsule); ctx.strokePath()
        }

        // --- U-arch (stand) ---
        // Two short vertical arms that curve into each other at the bottom via a cubic
        // Bézier.  Cubic with both control points pulled straight down gives a smooth,
        // symmetric U whose depth is clearly distinct from the capsule.
        let archLx:  CGFloat = cx - 3.5
        let archRx:  CGFloat = cx + 3.5
        let archTopY: CGFloat = 11.6     // where the arch arms begin
        let archCtrlY: CGFloat = 16.0   // pull-down for cubic control points
        //   visual bottom ≈ archTopY + 0.75*(archCtrlY - archTopY) = 14.95

        ctx.beginPath()
        ctx.move(to: CGPoint(x: archLx, y: archTopY))
        ctx.addCurve(
            to:       CGPoint(x: archRx, y: archTopY),
            control1: CGPoint(x: archLx, y: archCtrlY),
            control2: CGPoint(x: archRx, y: archCtrlY)
        )
        ctx.strokePath()

        // --- stem + foot ---
        let stemTopY:    CGFloat = 14.85  // ≈ visual bottom of arch
        let stemBottomY: CGFloat = 16.1
        let footHalf:    CGFloat = 2.1

        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: stemTopY))
        ctx.addLine(to: CGPoint(x: cx, y: stemBottomY))
        ctx.move(to: CGPoint(x: cx - footHalf, y: stemBottomY))
        ctx.addLine(to: CGPoint(x: cx + footHalf, y: stemBottomY))
        ctx.strokePath()
    }

    // MARK: - Transcribing indicator (three dots)

    private static func drawDots(ctx: CGContext, w: CGFloat, h: CGFloat) {
        let cx = w / 2
        let cy: CGFloat = 9.2
        let spacing: CGFloat = 3.1
        let r: CGFloat = 0.95
        for dx: CGFloat in [-spacing, 0, spacing] {
            ctx.fillEllipse(in: CGRect(x: cx + dx - r, y: cy - r, width: r * 2, height: r * 2))
        }
    }
}

extension DictationController {
    var menuBarIconImage: NSImage {
        MenuBarIconRenderer.nsImage(for: state)
    }
}
