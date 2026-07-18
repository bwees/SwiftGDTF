//
//  Geometry.swift
//
//  Parsing and expansion of the GDTF `<Geometries>` and `<Models>` trees.
//

import Foundation
import SWXMLHash

///
/// Model & Geometry Schema
///

/// A `<Models><Model>` entry: a physical part referenced by a geometry.
public struct Model: Codable, Sendable {
    public var name: String
    public var length: Double
    public var width: Double
    public var height: Double
    public var primitiveType: PrimitiveType
    /// Referenced 3D file name (no extension); `nil` when the model has no file.
    public var file: String?
}

/// The kind of geometry node, taken from its XML element name.
public enum GeometryKind: String, Codable, Sendable {
    case geometry
    case axis
    case beam
    case reference
    /// Any other geometry-collection node (FilterBeam, Display, WiringObject, ...).
    case other
}

/// Beam-specific fields, present when `kind == .beam`.
public struct BeamData: Codable, Sendable {
    public var beamAngle: Double?
    public var fieldAngle: Double?
    public var beamType: BeamType?
    public var colorTemperature: Double?
    public var luminousFlux: Double?
}

/// A single `<Break>` inside a `<GeometryReference>`.
public struct GeometryBreak: Codable, Sendable {
    public var dmxBreak: Int
    public var dmxOffset: Int
}

/// Reference-specific fields, present when `kind == .reference`.
public struct GeometryReferenceData: Codable, Sendable {
    /// Name of the top-level geometry this reference instantiates.
    public var geometry: String
    public var breaks: [GeometryBreak]
}

/// A node in the geometry tree. Plain geometries, axes, beams and geometry
/// references share this type; `kind` (plus `beam` / `reference`) distinguishes them.
public struct GDTFGeometry: Codable, Sendable {
    public var name: String
    public var kind: GeometryKind
    /// Name of the referenced `<Model>`, if any.
    public var model: String?
    /// Local 4x4 transform relative to the parent geometry.
    public var position: Matrix
    public var children: [GDTFGeometry]

    public var beam: BeamData?
    public var reference: GeometryReferenceData?
}

/// One instantiated `<GeometryReference>` cell with its position and DMX-shifted channels.
/// (Not `Sendable`: it carries `DMXChannel`, which the module does not mark `Sendable`.)
public struct GeometryCell: Codable {
    /// The reference instance name (e.g. "Pixel 3").
    public var name: String
    /// The top-level geometry this cell instantiates.
    public var referencedGeometry: String
    /// Cell position relative to the fixture.
    public var position: Matrix
    /// The referenced geometry's channels, shifted into this cell's DMX slice.
    public var channels: [DMXChannel]
}

extension GDTFGeometry {
    /// Element names that represent geometry nodes (children we recurse into).
    static let geometryElementNames: Set<String> = [
        "geometry", "axis", "beam", "geometryreference", "filterbeam", "filtercolor",
        "filtergobo", "filtershaper", "mediaserverlayer", "mediaservercamera",
        "mediaservermaster", "display", "laser", "wiringobject", "inventory",
        "structure", "support", "magnet",
    ]

    /// This node and every reference in its subtree.
    func allReferences() -> [GDTFGeometry] {
        var result = kind == .reference ? [self] : []
        for child in children { result.append(contentsOf: child.allReferences()) }
        return result
    }

    /// Names of this geometry and all of its descendants.
    func allDescendantNames() -> Set<String> {
        var names: Set<String> = [name]
        for child in children { names.formUnion(child.allDescendantNames()) }
        return names
    }
}

///
/// XML Parsing
///

extension Model: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.name = try element.attribute(named: "Name").text
        self.length = element.attribute(by: "Length")?.double ?? 0
        self.width = element.attribute(by: "Width")?.double ?? 0
        self.height = element.attribute(by: "Height")?.double ?? 0
        self.primitiveType = (try? element.attribute(by: "PrimitiveType")?.toEnum()) ?? .undefined

        let file = element.attribute(by: "File")?.text
        self.file = (file?.isEmpty == false) ? file : nil
    }
}

extension GDTFGeometry: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.name = try element.attribute(named: "Name").text

        let model = element.attribute(by: "Model")?.text
        self.model = (model?.isEmpty == false) ? model : nil

        if let position = element.attribute(by: "Position")?.text {
            self.position = Matrix(from: position)
        } else {
            self.position = Matrix()
        }

        switch element.name.lowercased() {
        case "axis": self.kind = .axis
        case "beam": self.kind = .beam
        case "geometryreference": self.kind = .reference
        case "geometry": self.kind = .geometry
        default: self.kind = .other
        }

        switch self.kind {
        case .reference:
            let geometry = element.attribute(by: "Geometry")?.text ?? ""
            let breaks: [GeometryBreak] = xml.children
                .filter { $0.element?.name.lowercased() == "break" }
                .map { child in
                    GeometryBreak(
                        dmxBreak: child.element?.attribute(by: "DMXBreak")?.int ?? 1,
                        dmxOffset: child.element?.attribute(by: "DMXOffset")?.int ?? 1
                    )
                }
            self.reference = GeometryReferenceData(geometry: geometry, breaks: breaks)
            self.beam = nil
            self.children = []

        case .beam:
            self.beam = BeamData(
                beamAngle: element.attribute(by: "BeamAngle")?.double,
                fieldAngle: element.attribute(by: "FieldAngle")?.double,
                beamType: try? element.attribute(by: "BeamType")?.toEnum(),
                colorTemperature: element.attribute(by: "ColorTemperature")?.double,
                luminousFlux: element.attribute(by: "LuminousFlux")?.double
            )
            self.reference = nil
            self.children = try Self.parseChildren(xml: xml, tree: tree)

        default:
            self.beam = nil
            self.reference = nil
            self.children = try Self.parseChildren(xml: xml, tree: tree)
        }
    }

    private static func parseChildren(xml: XMLIndexer, tree: XMLIndexer) throws -> [GDTFGeometry] {
        try xml.children
            .filter { geometryElementNames.contains(($0.element?.name ?? "").lowercased()) }
            .map { try $0.parse(tree: tree) }
    }
}

///
/// GeometryReference Expansion
///

extension DMXMode {
    /// Effective channel list: the flattened per-cell channels when the mode
    /// instantiates cells, otherwise the literal `channels`.
    public var allChannels: [DMXChannel] {
        flattenedChannels ?? channels
    }

    /// Expands `<GeometryReference>`s into per-cell channels and attaches the
    /// result (`flattenedChannels` + `cells`). No-op when the mode instantiates
    /// no cells, leaving both `nil` so the literal `channels` remain authoritative.
    mutating func applyGeometryExpansion(geometries: [GDTFGeometry]) {
        let references = geometries.flatMap { $0.allReferences() }
        guard !references.isEmpty else { return }

        // For each top-level geometry, the set of geometry names in its subtree.
        var subtreeNames: [String: Set<String>] = [:]
        for geometry in geometries {
            subtreeNames[geometry.name] = geometry.allDescendantNames()
        }

        let targets = Set(references.compactMap { $0.reference?.geometry })

        func target(forChannelGeometry channelGeometry: String) -> String? {
            targets.first { subtreeNames[$0]?.contains(channelGeometry) ?? false }
        }

        // Split channels into literals (pass through) and per-target templates.
        var literalChannels: [DMXChannel] = []
        var templatesByTarget: [String: [DMXChannel]] = [:]
        for channel in channels {
            if let target = target(forChannelGeometry: channel.geometry) {
                templatesByTarget[target, default: []].append(channel)
            } else {
                literalChannels.append(channel)
            }
        }

        guard templatesByTarget.values.contains(where: { !$0.isEmpty }) else { return }

        var cells: [GeometryCell] = []
        var flattened = literalChannels

        for reference in references {
            guard let data = reference.reference,
                  let templates = templatesByTarget[data.geometry], !templates.isEmpty
            else { continue }

            let breaks = data.breaks.isEmpty ? [GeometryBreak(dmxBreak: 1, dmxOffset: 1)] : data.breaks

            let cellChannels: [DMXChannel] = templates.map { template in
                var channel = template
                let brk = breaks.first { $0.dmxBreak == template.dmxBreak } ?? breaks[0]
                if !channel.offset.isEmpty {
                    channel.offset = channel.offset.map { $0 + brk.dmxOffset - 1 }
                }
                channel.dmxBreak = brk.dmxBreak
                return channel
            }

            cells.append(GeometryCell(
                name: reference.name,
                referencedGeometry: data.geometry,
                position: reference.position,
                channels: cellChannels
            ))
            flattened.append(contentsOf: cellChannels)
        }

        guard !cells.isEmpty else { return }

        self.cells = cells
        self.flattenedChannels = flattened
    }
}
