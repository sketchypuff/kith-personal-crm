#!/usr/bin/env swift

import AppKit
import Metal
import SceneKit

// Run from the repository root. Review boards are not shipping assets.
// xcrun swift scripts/render-onboarding.swift \
//   --output-directory /tmp/kith-onboarding-artwork --export-assets
// Add --illustration privacy to regenerate only the privacy artwork.
// Keep review output outside the asset catalog; only the six PNGs are exported.
// GPU rasterization can vary by a least-significant colour bit between identical runs.

enum RenderError: Error, CustomStringConvertible {
    case missingOutputDirectory
    case invalidArgument(String)
    case metalUnavailable
    case preparationFailed
    case imageEncodingFailed

    var description: String {
        switch self {
        case .missingOutputDirectory:
            "Usage: xcrun swift scripts/render-onboarding.swift --output-directory <directory> [--illustration people|rhythm|privacy] [--export-assets]"
        case .invalidArgument(let argument):
            "Unknown or incomplete argument: \(argument)"
        case .metalUnavailable:
            "A Metal device is required to render the illustrations."
        case .preparationFailed:
            "SceneKit could not prepare the illustration for rendering."
        case .imageEncodingFailed:
            "The rendered image could not be encoded as PNG."
        }
    }
}

enum Appearance: String, CaseIterable {
    case light
    case dark

    var background: NSColor {
        switch self {
        case .light: colour(0.98, 0.985, 0.99)
        case .dark: colour(0.065, 0.078, 0.105)
        }
    }

    var card: NSColor {
        switch self {
        case .light: colour(0.88, 0.94, 0.99)
        case .dark: colour(0.76, 0.87, 0.98)
        }
    }

    var rim: NSColor {
        switch self {
        case .light: colour(0.97, 0.99, 1)
        case .dark: colour(0.69, 0.84, 0.98)
        }
    }

    var blue: NSColor {
        switch self {
        case .light: colour(0.18, 0.49, 0.87)
        case .dark: colour(0.24, 0.58, 0.97)
        }
    }

    var quietBlue: NSColor {
        switch self {
        case .light: colour(0.53, 0.71, 0.90)
        case .dark: colour(0.37, 0.59, 0.85)
        }
    }

    var line: NSColor {
        switch self {
        case .light: colour(0.58, 0.70, 0.82)
        case .dark: colour(0.41, 0.58, 0.76)
        }
    }

    var warm: NSColor { colour(0.94, 0.69, 0.48) }
}

enum Illustration: String, CaseIterable {
    case people
    case rhythm
    case privacy

    var assetName: String { "Onboarding\(rawValue.capitalized)" }

    func artwork(appearance: Appearance) -> SCNNode {
        switch self {
        case .people: peopleArtwork(appearance: appearance)
        case .rhythm: rhythmArtwork(appearance: appearance)
        case .privacy: privacyArtwork(appearance: appearance)
        }
    }
}

func colour(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func material(
    _ colour: NSColor,
    roughness: CGFloat = 0.32,
    metalness: CGFloat = 0.03,
    opacity: CGFloat = 1
) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.diffuse.contents = colour
    material.roughness.contents = roughness
    material.metalness.contents = metalness
    material.transparency = opacity
    material.transparencyMode = .dualLayer
    material.writesToDepthBuffer = opacity == 1
    material.fresnelExponent = 1.4
    return material
}

func roundedChamferProfile() -> NSBezierPath {
    let profile = NSBezierPath()
    profile.move(to: CGPoint(x: 0, y: 1))
    profile.curve(
        to: CGPoint(x: 1, y: 0),
        controlPoint1: CGPoint(x: 0.5523, y: 1),
        controlPoint2: CGPoint(x: 1, y: 0.5523)
    )
    profile.flatness = 0.0005
    return profile
}

func roundedShape(
    width: CGFloat,
    height: CGFloat,
    cornerRadius: CGFloat,
    depth: CGFloat,
    face: SCNMaterial,
    edge: SCNMaterial
) -> SCNShape {
    let path = NSBezierPath(
        roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )
    path.flatness = 0.0005
    let shape = SCNShape(path: path, extrusionDepth: depth)
    shape.chamferRadius = min(depth * 0.28, 0.045)
    shape.chamferProfile = roundedChamferProfile()
    shape.materials = [face, face, edge, edge]
    return shape
}

func detailLine(width: CGFloat, height: CGFloat, colour: NSColor) -> SCNNode {
    let surface = material(colour, roughness: 0.48)
    return SCNNode(geometry: roundedShape(
        width: width,
        height: height,
        cornerRadius: height / 2,
        depth: 0.038,
        face: surface,
        edge: surface
    ))
}

func avatar(colour: NSColor) -> SCNNode {
    let node = SCNNode()
    let surface = material(colour, roughness: 0.43)
    let head = SCNSphere(radius: 0.245)
    head.segmentCount = 64
    head.materials = [surface]
    let headNode = SCNNode(geometry: head)
    headNode.scale = SCNVector3(1, 1, 0.76)
    headNode.position = SCNVector3(0, 0.59, 0.10)
    node.addChildNode(headNode)

    let shoulders = NSBezierPath()
    shoulders.move(to: CGPoint(x: -0.57, y: -0.27))
    shoulders.line(to: CGPoint(x: 0.57, y: -0.27))
    shoulders.line(to: CGPoint(x: 0.57, y: -0.045))
    shoulders.curve(
        to: CGPoint(x: 0, y: 0.29),
        controlPoint1: CGPoint(x: 0.57, y: 0.17),
        controlPoint2: CGPoint(x: 0.29, y: 0.29)
    )
    shoulders.curve(
        to: CGPoint(x: -0.57, y: -0.045),
        controlPoint1: CGPoint(x: -0.29, y: 0.29),
        controlPoint2: CGPoint(x: -0.57, y: 0.17)
    )
    shoulders.close()
    shoulders.flatness = 0.004
    let body = SCNShape(path: shoulders, extrusionDepth: 0.13)
    body.chamferRadius = 0.055
    body.chamferProfile = roundedChamferProfile()
    body.materials = [surface]
    node.addChildNode(SCNNode(geometry: body))
    return node
}

func contactCard(
    appearance: Appearance,
    avatarColour: NSColor,
    opacity: CGFloat,
    scale: CGFloat = 1
) -> SCNNode {
    let face = material(appearance.card, roughness: 0.4, opacity: opacity)
    let rim = material(appearance.rim, roughness: 0.2, metalness: 0.08, opacity: opacity)
    let shape = roundedShape(
        width: 2.18,
        height: 2.74,
        cornerRadius: 0.30,
        depth: 0.24,
        face: face,
        edge: rim
    )
    let card = SCNNode(geometry: shape)
    let front = shape.boundingBox.max.z + 0.055

    let person = avatar(colour: avatarColour)
    person.position = SCNVector3(0, 0.18, front)
    card.addChildNode(person)

    let name = detailLine(width: 1.03, height: 0.11, colour: appearance.line)
    name.position = SCNVector3(0, -0.61, front)
    card.addChildNode(name)

    let detail = detailLine(width: 0.64, height: 0.07, colour: appearance.line)
    detail.position = SCNVector3(0, -0.88, front)
    card.addChildNode(detail)

    card.scale = SCNVector3(scale, scale, scale)
    return card
}

func studioEnvironment() -> NSImage {
    NSImage(size: CGSize(width: 1024, height: 512), flipped: false) { rect in
        let gradient = NSGradient(
            starting: colour(0.30, 0.37, 0.47),
            ending: colour(0.91, 0.95, 1)
        )
        gradient?.draw(in: rect, angle: 90)
        colour(1, 0.98, 0.95).setFill()
        NSBezierPath(
            roundedRect: CGRect(x: 120, y: 195, width: 210, height: 265),
            xRadius: 55,
            yRadius: 55
        ).fill()
        colour(0.77, 0.89, 1).setFill()
        NSBezierPath(
            roundedRect: CGRect(x: 665, y: 200, width: 110, height: 240),
            xRadius: 35,
            yRadius: 35
        ).fill()
        return true
    }
}

func addLight(
    to scene: SCNScene,
    type: SCNLight.LightType,
    position: SCNVector3,
    intensity: CGFloat,
    colour: NSColor,
    castsShadow: Bool = false
) {
    let light = SCNLight()
    light.type = type
    light.intensity = intensity
    light.color = colour
    light.castsShadow = castsShadow
    light.shadowColor = NSColor.black.withAlphaComponent(0.17)
    light.shadowRadius = 7
    light.shadowSampleCount = 32
    light.shadowMapSize = CGSize(width: 2048, height: 2048)
    let node = SCNNode()
    node.light = light
    node.position = position
    node.look(at: SCNVector3Zero)
    scene.rootNode.addChildNode(node)
}

func peopleArtwork(appearance: Appearance) -> SCNNode {
    let artwork = SCNNode()
    let backLeft = contactCard(
        appearance: appearance,
        avatarColour: appearance.quietBlue,
        opacity: 0.70,
        scale: 0.87
    )
    backLeft.position = SCNVector3(-1.10, 0.23, -0.34)
    backLeft.eulerAngles = SCNVector3(-0.06, -0.27, 0.19)
    artwork.addChildNode(backLeft)

    let backRight = contactCard(
        appearance: appearance,
        avatarColour: appearance.warm,
        opacity: 0.77,
        scale: 0.77
    )
    backRight.position = SCNVector3(1.27, 0.41, -0.59)
    backRight.eulerAngles = SCNVector3(0.02, 0.33, -0.20)
    artwork.addChildNode(backRight)

    let hero = contactCard(
        appearance: appearance,
        avatarColour: appearance.blue,
        opacity: 0.94
    )
    hero.position = SCNVector3(0.17, -0.14, 0.43)
    hero.eulerAngles = SCNVector3(-0.075, -0.20, -0.065)
    artwork.addChildNode(hero)

    return artwork
}

func calendar(appearance: Appearance) -> SCNNode {
    let shape = roundedShape(
        width: 2.74,
        height: 2.70,
        cornerRadius: 0.30,
        depth: 0.25,
        face: material(appearance.card, roughness: 0.4, opacity: 0.94),
        edge: material(appearance.rim, roughness: 0.2, metalness: 0.08, opacity: 0.94)
    )
    let calendar = SCNNode(geometry: shape)
    let front = shape.boundingBox.max.z + 0.045

    let header = detailLine(width: 2.22, height: 0.30, colour: appearance.quietBlue)
    header.position = SCNVector3(0, 0.77, front)
    calendar.addChildNode(header)

    for x: CGFloat in [-0.72, 0.72] {
        let surface = material(appearance.quietBlue, roughness: 0.3, metalness: 0.08)
        let binding = SCNNode(geometry: roundedShape(
            width: 0.19,
            height: 0.51,
            cornerRadius: 0.095,
            depth: 0.18,
            face: surface,
            edge: surface
        ))
        binding.position = SCNVector3(x, 1.22, front + 0.025)
        calendar.addChildNode(binding)
    }

    for row in 0..<3 {
        for column in 0..<4 {
            let highlighted = row == 1 && column == 1
            let shape = roundedShape(
                width: highlighted ? 0.42 : 0.26,
                height: highlighted ? 0.42 : 0.24,
                cornerRadius: highlighted ? 0.13 : 0.09,
                depth: highlighted ? 0.07 : 0.032,
                face: material(highlighted ? appearance.blue : appearance.line, roughness: 0.48),
                edge: material(highlighted ? appearance.blue : appearance.line, roughness: 0.4)
            )
            let day = SCNNode(geometry: shape)
            day.position = SCNVector3(
                -0.87 + CGFloat(column) * 0.58,
                0.28 - CGFloat(row) * 0.50,
                front
            )
            if highlighted {
                let dot = SCNSphere(radius: 0.065)
                dot.segmentCount = 40
                dot.materials = [material(appearance.rim, roughness: 0.42)]
                let mark = SCNNode(geometry: dot)
                mark.scale = SCNVector3(1, 1, 0.5)
                mark.position.z = shape.boundingBox.max.z + 0.014
                day.addChildNode(mark)
            }
            calendar.addChildNode(day)
        }
    }
    return calendar
}

func clock(appearance: Appearance) -> SCNNode {
    let rim = material(appearance.quietBlue, roughness: 0.3, metalness: 0.08)
    let shape = roundedShape(
        width: 1.40,
        height: 1.40,
        cornerRadius: 0.70,
        depth: 0.26,
        face: rim,
        edge: rim
    )
    let clock = SCNNode(geometry: shape)
    let face = roundedShape(
        width: 1.15,
        height: 1.15,
        cornerRadius: 0.575,
        depth: 0.06,
        face: material(appearance.rim, roughness: 0.45),
        edge: material(appearance.card, roughness: 0.4)
    )
    let faceNode = SCNNode(geometry: face)
    faceNode.position.z = shape.boundingBox.max.z + 0.02
    clock.addChildNode(faceNode)
    let front = face.boundingBox.max.z + 0.025

    let minute = detailLine(width: 0.075, height: 0.35, colour: appearance.blue)
    minute.position = SCNVector3(0, 0.14, front)
    faceNode.addChildNode(minute)

    let hour = detailLine(width: 0.29, height: 0.075, colour: appearance.blue)
    hour.position = SCNVector3(0.11, -0.015, front + 0.004)
    hour.eulerAngles.z = -0.24
    faceNode.addChildNode(hour)

    let pin = SCNSphere(radius: 0.087)
    pin.segmentCount = 48
    pin.materials = [material(appearance.warm, roughness: 0.35)]
    let pinNode = SCNNode(geometry: pin)
    pinNode.scale = SCNVector3(1, 1, 0.5)
    pinNode.position = SCNVector3(0, 0, front + 0.025)
    faceNode.addChildNode(pinNode)
    return clock
}

func rhythmArtwork(appearance: Appearance) -> SCNNode {
    let artwork = SCNNode()
    let back = SCNNode(geometry: roundedShape(
        width: 2.74,
        height: 2.70,
        cornerRadius: 0.30,
        depth: 0.20,
        face: material(appearance.card, roughness: 0.4, opacity: 0.65),
        edge: material(appearance.rim, roughness: 0.2, metalness: 0.08, opacity: 0.65)
    ))
    back.position = SCNVector3(0.22, 0.16, -0.38)
    back.eulerAngles = SCNVector3(-0.025, 0.16, -0.16)
    artwork.addChildNode(back)

    let hero = calendar(appearance: appearance)
    hero.position = SCNVector3(-0.43, -0.03, 0.25)
    hero.eulerAngles = SCNVector3(-0.075, -0.20, 0.055)
    artwork.addChildNode(hero)

    let reminder = clock(appearance: appearance)
    reminder.position = SCNVector3(1.29, -0.67, 0.78)
    reminder.eulerAngles = SCNVector3(-0.075, -0.22, -0.10)
    artwork.addChildNode(reminder)
    return artwork
}

func shackle(appearance: Appearance) -> SCNNode {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: -0.72, y: 0.25))
    path.line(to: CGPoint(x: -0.72, y: 0.65))
    path.curve(
        to: CGPoint(x: 0, y: 1.30),
        controlPoint1: CGPoint(x: -0.72, y: 1.02),
        controlPoint2: CGPoint(x: -0.40, y: 1.30)
    )
    path.curve(
        to: CGPoint(x: 0.72, y: 0.65),
        controlPoint1: CGPoint(x: 0.40, y: 1.30),
        controlPoint2: CGPoint(x: 0.72, y: 1.02)
    )
    path.line(to: CGPoint(x: 0.72, y: 0.25))
    path.line(to: CGPoint(x: 0.46, y: 0.25))
    path.line(to: CGPoint(x: 0.46, y: 0.65))
    path.curve(
        to: CGPoint(x: 0, y: 1.04),
        controlPoint1: CGPoint(x: 0.46, y: 0.87),
        controlPoint2: CGPoint(x: 0.25, y: 1.04)
    )
    path.curve(
        to: CGPoint(x: -0.46, y: 0.65),
        controlPoint1: CGPoint(x: -0.25, y: 1.04),
        controlPoint2: CGPoint(x: -0.46, y: 0.87)
    )
    path.line(to: CGPoint(x: -0.46, y: 0.25))
    path.close()
    path.flatness = 0.0005
    let shape = SCNShape(path: path, extrusionDepth: 0.28)
    shape.chamferRadius = 0.085
    shape.chamferProfile = roundedChamferProfile()
    shape.materials = [material(appearance.rim, roughness: 0.38, metalness: 0.32)]
    return SCNNode(geometry: shape)
}

func lock(appearance: Appearance) -> SCNNode {
    let lock = SCNNode()
    let loop = shackle(appearance: appearance)
    loop.position.z = -0.04
    lock.addChildNode(loop)

    let body = roundedShape(
        width: 2.22,
        height: 1.82,
        cornerRadius: 0.40,
        depth: 0.38,
        face: material(appearance.card, roughness: 0.48),
        edge: material(appearance.rim, roughness: 0.32, metalness: 0.04)
    )
    body.chamferRadius = 0.095
    let bodyNode = SCNNode(geometry: body)
    bodyNode.position = SCNVector3(0, -0.38, 0.08)
    lock.addChildNode(bodyNode)

    let keyhole = NSBezierPath()
    keyhole.move(to: CGPoint(x: -0.075, y: -0.02))
    keyhole.curve(
        to: CGPoint(x: -0.145, y: 0.11),
        controlPoint1: CGPoint(x: -0.13, y: 0.01),
        controlPoint2: CGPoint(x: -0.145, y: 0.05)
    )
    keyhole.curve(
        to: CGPoint(x: 0, y: 0.255),
        controlPoint1: CGPoint(x: -0.145, y: 0.19),
        controlPoint2: CGPoint(x: -0.08, y: 0.255)
    )
    keyhole.curve(
        to: CGPoint(x: 0.145, y: 0.11),
        controlPoint1: CGPoint(x: 0.08, y: 0.255),
        controlPoint2: CGPoint(x: 0.145, y: 0.19)
    )
    keyhole.curve(
        to: CGPoint(x: 0.075, y: -0.02),
        controlPoint1: CGPoint(x: 0.145, y: 0.05),
        controlPoint2: CGPoint(x: 0.13, y: 0.01)
    )
    keyhole.line(to: CGPoint(x: 0.115, y: -0.21))
    keyhole.line(to: CGPoint(x: -0.115, y: -0.21))
    keyhole.close()
    keyhole.flatness = 0.0005
    let inlay = SCNShape(path: keyhole, extrusionDepth: 0.016)
    inlay.chamferRadius = 0.006
    inlay.chamferProfile = roundedChamferProfile()
    inlay.materials = [material(appearance.blue, roughness: 0.68)]
    let inlayNode = SCNNode(geometry: inlay)
    inlayNode.position = SCNVector3(0, -0.02, body.boundingBox.max.z + 0.012)
    bodyNode.addChildNode(inlayNode)
    return lock
}

func cloud(appearance: Appearance) -> SCNNode {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: -0.54, y: -0.32))
    path.line(to: CGPoint(x: 0.52, y: -0.32))
    path.curve(
        to: CGPoint(x: 0.86, y: 0.02),
        controlPoint1: CGPoint(x: 0.71, y: -0.32),
        controlPoint2: CGPoint(x: 0.86, y: -0.17)
    )
    path.curve(
        to: CGPoint(x: 0.57, y: 0.36),
        controlPoint1: CGPoint(x: 0.86, y: 0.21),
        controlPoint2: CGPoint(x: 0.74, y: 0.36)
    )
    path.curve(
        to: CGPoint(x: 0.10, y: 0.76),
        controlPoint1: CGPoint(x: 0.51, y: 0.61),
        controlPoint2: CGPoint(x: 0.33, y: 0.76)
    )
    path.curve(
        to: CGPoint(x: -0.37, y: 0.42),
        controlPoint1: CGPoint(x: -0.14, y: 0.76),
        controlPoint2: CGPoint(x: -0.33, y: 0.63)
    )
    path.curve(
        to: CGPoint(x: -0.68, y: 0.34),
        controlPoint1: CGPoint(x: -0.50, y: 0.50),
        controlPoint2: CGPoint(x: -0.64, y: 0.44)
    )
    path.curve(
        to: CGPoint(x: -0.90, y: 0.02),
        controlPoint1: CGPoint(x: -0.81, y: 0.30),
        controlPoint2: CGPoint(x: -0.90, y: 0.17)
    )
    path.curve(
        to: CGPoint(x: -0.54, y: -0.32),
        controlPoint1: CGPoint(x: -0.90, y: -0.18),
        controlPoint2: CGPoint(x: -0.74, y: -0.32)
    )
    path.close()
    path.flatness = 0.0005
    let shape = SCNShape(path: path, extrusionDepth: 0.32)
    shape.chamferRadius = 0.10
    shape.chamferProfile = roundedChamferProfile()
    let face = material(appearance.quietBlue, roughness: 0.44)
    let rim = material(appearance.card, roughness: 0.38, metalness: 0.04)
    shape.materials = [face, face, rim, rim]
    return SCNNode(geometry: shape)
}

func privacyArtwork(appearance: Appearance) -> SCNNode {
    let artwork = SCNNode()
    let person = contactCard(
        appearance: appearance,
        avatarColour: appearance.warm,
        opacity: 0.92,
        scale: 0.86
    )
    person.position = SCNVector3(-0.92, 0.28, -0.38)
    person.eulerAngles = SCNVector3(-0.04, -0.25, 0.13)
    artwork.addChildNode(person)

    let sync = cloud(appearance: appearance)
    sync.position = SCNVector3(1.38, 1.26, 0.05)
    sync.eulerAngles = SCNVector3(0.02, -0.18, -0.055)
    sync.scale = SCNVector3(0.80, 0.80, 0.80)
    artwork.addChildNode(sync)

    let hero = lock(appearance: appearance)
    hero.position = SCNVector3(0.40, -0.34, 0.52)
    hero.eulerAngles = SCNVector3(-0.025, -0.15, -0.045)
    artwork.addChildNode(hero)
    artwork.scale = SCNVector3(1.13, 1.13, 1.13)
    return artwork
}

func studio(artwork: SCNNode, environment: NSImage) -> (SCNScene, SCNNode) {
    let scene = SCNScene()
    scene.background.contents = NSColor.clear
    scene.lightingEnvironment.contents = environment
    scene.lightingEnvironment.intensity = 0.70
    scene.rootNode.addChildNode(artwork)

    addLight(
        to: scene,
        type: .directional,
        position: SCNVector3(-3, 6, 7),
        intensity: 420,
        colour: colour(1, 0.97, 0.92),
        castsShadow: true
    )
    addLight(
        to: scene,
        type: .omni,
        position: SCNVector3(5, 1, 4),
        intensity: 140,
        colour: colour(0.70, 0.84, 1)
    )
    addLight(
        to: scene,
        type: .omni,
        position: SCNVector3(1, 5, -4),
        intensity: 230,
        colour: colour(0.85, 0.93, 1)
    )

    let camera = SCNCamera()
    camera.usesOrthographicProjection = true
    camera.orthographicScale = 2.95
    camera.zNear = 0.1
    camera.zFar = 40
    camera.wantsHDR = true
    camera.wantsExposureAdaptation = false
    camera.exposureOffset = -0.45
    camera.bloomIntensity = 0
    camera.screenSpaceAmbientOcclusionIntensity = 0.24
    camera.screenSpaceAmbientOcclusionRadius = 0.19
    let cameraNode = SCNNode()
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(1.2, 2.1, 10)
    cameraNode.look(at: SCNVector3(0, 0.12, 0))
    scene.rootNode.addChildNode(cameraNode)

    return (scene, cameraNode)
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    else {
        throw RenderError.imageEncodingFailed
    }
    try png.write(to: url, options: .atomic)
}

func reviewBoard(images: [Appearance: NSImage]) -> NSImage {
    let panelWidth: CGFloat = 800
    let height: CGFloat = 660
    return NSImage(size: CGSize(width: panelWidth * 2, height: height), flipped: false) { _ in
        for (index, appearance) in Appearance.allCases.enumerated() {
            let left = CGFloat(index) * panelWidth
            appearance.background.setFill()
            CGRect(x: left, y: 0, width: panelWidth, height: height).fill()
            images[appearance]?.draw(in: CGRect(x: left, y: 50, width: panelWidth, height: 600))
            let label = appearance.rawValue.capitalized as NSString
            label.draw(
                at: CGPoint(x: left + 34, y: 25),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 17, weight: .medium),
                    .foregroundColor: appearance == .light
                        ? colour(0.37, 0.43, 0.50)
                        : colour(0.68, 0.75, 0.84)
                ]
            )
        }
        return true
    }
}

struct Options {
    let outputDirectory: URL
    let exportAssets: Bool
    let illustration: Illustration?
}

func options() throws -> Options {
    let arguments = Array(CommandLine.arguments.dropFirst())
    var directory: URL?
    var exportAssets = false
    var illustration: Illustration?
    var index = 0
    while index < arguments.count {
        switch arguments[index] {
        case "--output-directory":
            guard directory == nil, index + 1 < arguments.count,
                  !arguments[index + 1].isEmpty, !arguments[index + 1].hasPrefix("--")
            else {
                throw RenderError.invalidArgument(arguments[index])
            }
            index += 1
            directory = URL(fileURLWithPath: arguments[index], isDirectory: true)
        case "--export-assets":
            guard !exportAssets else { throw RenderError.invalidArgument(arguments[index]) }
            exportAssets = true
        case "--illustration":
            guard illustration == nil, index + 1 < arguments.count,
                  let selected = Illustration(rawValue: arguments[index + 1]) else {
                throw RenderError.invalidArgument("--illustration (choose people, rhythm, or privacy)")
            }
            illustration = selected
            index += 1
        default:
            throw RenderError.invalidArgument(arguments[index])
        }
        index += 1
    }
    guard let directory else { throw RenderError.missingOutputDirectory }
    return Options(outputDirectory: directory, exportAssets: exportAssets, illustration: illustration)
}

func render() throws {
    let options = try options()
    let directory = options.outputDirectory
    let assets = URL(fileURLWithPath: "Kith/Assets.xcassets", isDirectory: true)
    guard let device = MTLCreateSystemDefaultDevice() else { throw RenderError.metalUnavailable }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let environment = studioEnvironment()

    let illustrations = options.illustration.map { [$0] } ?? Illustration.allCases
    for illustration in illustrations {
        var images: [Appearance: NSImage] = [:]
        for appearance in Appearance.allCases {
            let image = try autoreleasepool {
                let (scene, camera) = studio(
                    artwork: illustration.artwork(appearance: appearance),
                    environment: environment
                )
                let renderer = SCNRenderer(device: device, options: nil)
                renderer.scene = scene
                renderer.pointOfView = camera
                guard renderer.prepare(scene, shouldAbortBlock: nil) else { throw RenderError.preparationFailed }
                return renderer.snapshot(
                    atTime: 0,
                    with: CGSize(width: 1536, height: 1152),
                    antialiasingMode: .multisampling4X
                )
            }
            images[appearance] = image
            let filename = "onboarding-\(illustration.rawValue)-\(appearance.rawValue).png"
            let output = directory.appending(path: filename)
            try writePNG(image, to: output)
            print(output.path)

            if options.exportAssets {
                let imageSet = assets.appending(path: "\(illustration.assetName).imageset")
                try FileManager.default.createDirectory(at: imageSet, withIntermediateDirectories: true)
                let destination = imageSet.appending(path: filename)
                try Data(contentsOf: output).write(to: destination, options: .atomic)
                print("Asset: \(destination.path)")
            }
        }

        let review = directory.appending(path: "onboarding-\(illustration.rawValue)-review.png")
        try writePNG(reviewBoard(images: images), to: review)
        print(review.path)
    }
}

do {
    try render()
} catch {
    FileHandle.standardError.write(Data("Onboarding artwork: \(error)\n".utf8))
    exit(1)
}
