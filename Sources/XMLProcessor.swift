//
//  XMLProcessor.swift
//
//
//  Created by Brandon Wees on 7/4/24.
//

import Foundation
import SWXMLHash

protocol XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws
}

protocol XMLDecodableWithIndex {
    init(xml: XMLIndexer, index: Int, tree: XMLIndexer) throws
}

protocol XMLDecodableWithParent {
    init(xml: XMLIndexer, parent: XMLIndexer, tree: XMLIndexer) throws
}


extension GDTF {
    init(xml: XMLIndexer) throws {
        
        self.dataVersion = xml["GDTF"].element!.attribute(by: "DataVersion")!.text
        self.fixtureType = try xml["GDTF"]["FixtureType"].parse(tree: xml["GDTF"]["FixtureType"])        
    }
}

extension FixtureType: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = try element.attribute(named: "Name").text
        self.shortName = element.attribute(by: "ShortName")?.text ?? ""
        self.longName = element.attribute(by: "LongName")?.text ?? ""
        self.manufacturer = try element.attribute(named: "Manufacturer").text
        self.description = try element.attribute(named: "Description").text
        self.fixtureTypeID = try element.attribute(named: "FixtureTypeID").uuid
        self.refFT = element.attribute(by: "RefFT")?.text
        self.thumbnail = FileResource(name: element.attribute(by: "Thumbnail")?.text, fileExtension: "png")
                
        self.attributeDefinitions = try xml["AttributeDefinitions"].parse(tree: tree)
        self.physicalDescriptions = try xml["PhysicalDescriptions"].parse(tree: tree)
        self.wheels = try xml["Wheels"].parseChildrenToArray(tree: tree)
        self.dmxModes = try xml["DMXModes"].parseChildrenToArray(tree: tree)
    }
}

extension FixtureInfo: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.name = try element.attribute(named: "Name").text
        self.shortName = element.attribute(by: "ShortName")?.text ?? ""
        self.longName = element.attribute(by: "LongName")?.text ?? ""
        self.manufacturer = try element.attribute(named: "Manufacturer").text
        self.description = try element.attribute(named: "Description").text
        self.fixtureTypeID = try element.attribute(named: "FixtureTypeID").text
        self.refFT = element.attribute(by: "RefFT")?.text
        self.thumbnail = FileResource(name: element.attribute(by: "Thumbnail")?.text, fileExtension: "png")
    }
}

///
/// AttributeDefinitions Schema
///

extension AttributeDefinitions: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        self.activationGroups = try xml["ActivationGroups"].parseChildrenToArray(tree: tree)
        self.featureGroups = try xml["FeatureGroups"].parseChildrenToArray(tree: tree)
        self.attributes = try xml["Attributes"].parseChildrenToArray(tree: tree)
    }
}

extension ActivationGroup: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.name = try element.attribute(named: "Name").text
    }
}

extension FeatureGroup: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.name = try element.attribute(named: "Name").text
        self.pretty = try element.attribute(named: "Pretty").text
        self.features = try xml.parseChildrenToArray(tree: tree)
    }
}

extension Feature: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.name = try element.attribute(named: "Name").text
    }
}

extension FixtureAttribute: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = try element.attribute(named: "Name").text
        self.pretty = try element.attribute(named: "Pretty").text
        
        // Resolve ActivationGroup Node
        self.activationGroup = try element.attribute(by: "ActivationGroup")?.resolveNode(
            base: tree["AttributeDefinitions"]["ActivationGroups"],
            tree: tree)

        // Resolve Feature Node
        self.feature = try element.attribute(by: "Feature")?.resolveNode(
            base: tree["AttributeDefinitions"]["FeatureGroups"],
            tree: tree)
        
        // This is technically a node but results in a recursive type
        self.mainAttribute = element.attribute(by: "MainAttribute")?.text
                
        self.physicalUnit = (try? element.attribute(by: "PhysicalUnit")?.toEnum()) ?? .none
        
        if let colorString = element.attribute(by: "Color")?.text {
            self.color = ColorCIE(from: colorString)
        }
        
        self.subPhysicalUnits = try xml.parseChildrenToArray(tree: tree)
        
        self.type = AttributeType.from(self.name)
    }
}

extension SubPhysicalUnit: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.physicalFrom = element.attribute(by: "PhysicalFrom")?.double ?? 0
        self.physicalTo = element.attribute(by: "PhysicalTo")?.double ?? 1
        
        self.physicalUnit = (try? element.attribute(by: "PhysicalUnit")?.toEnum()) ?? .none

        self.type = try? element.attribute(by: "Type")?.toEnum()
    }
}

///
/// Wheels Schema
///

extension Wheel: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = try element.attribute(named: "Name").text
        self.slots = try xml.parseChildrenToArray(tree: tree)
    }
}

extension Slot: XMLDecodableWithIndex {
    init(xml: XMLIndexer, index: Int, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = try element.attribute(named: "Name").text
        self.color = element.attribute(by: "Color").map { ColorCIE(from: $0.text) } ?? ColorCIE(x: 0.3127, y: 0.3290, Y: 1.0)

        self.filter = try element.attribute(by: "Filter")?.resolveNode(base: tree["PhysicalDescriptions"]["Filters"], tree: tree)
        
        self.mediaFileName = FileResource(name: element.attribute(by: "MediaFileName")?.text, fileExtension: "png")
        self.facets = try xml.filterChildren({ child, _ in child.name == "Facet"}).parseChildrenToArray(tree: tree)
        self.animationSystem = try xml["AnimationSystem"].optionalParse(tree: tree)

        self.slotIndex = index
    }
}

extension PrismFacet: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.color = try ColorCIE(from: element.attribute(named: "Color").text)
        self.rotation = try Rotation(from: element.attribute(named: "Rotation").text)
    }
}

extension AnimationSystem: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.p1 = try element.attribute(named: "P1").text.split(separator: ",").map { Double($0) ?? 0 }
        self.p2 = try element.attribute(named: "P2").text.split(separator: ",").map { Double($0) ?? 0 }
        self.p3 = try element.attribute(named: "P3").text.split(separator: ",").map { Double($0) ?? 0 }
        
        self.radius = try Double(element.attribute(named: "Radius").text) ?? 0
    }
}

///
/// Physical Description Schema
///

extension PhysicalDescriptions: XMLDecodable {
    // this object can not exist in which case we will be null
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        self.emitters = try xml["Emitters"].parseChildrenToArray(tree: tree)
        self.filters = try xml["Filters"].parseChildrenToArray(tree: tree)
        

        self.colorSpace = try xml["ColorSpace"].optionalParse(tree: tree)
        
        self.additionalColorSpaces = try xml["AdditionalColorSpaces"].parseChildrenToArray(tree: tree)
        self.dmxProfiles = try xml["DMXProfiles"].parseChildrenToArray(tree: tree)
        
        self.properties =  try xml["Properties"].parse(tree: tree)
    }
}

extension Emitter: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        self.name = try element.attribute(named: "Name").text
        
        self.color = element.attribute(by: "Color").map { ColorCIE(from: $0.text) }
        self.dominantWavelength = element.attribute(by: "DominantWaveLength")?.double

        
        self.diodePart = element.attribute(by: "DiodePart")?.text
  
        /// You can enable this if you would like, however its a lot of unneccessary data
//        self.measurements = xml.parseChildrenToArray(tree: tree)
    }
}

extension GDTFMeasurement: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.physical = try Double(element.attribute(named: "Physical").text) ?? 0
        
        self.luminousIntensity = element.attribute(by: "LuminousIntensity")?.double
        
        self.transmission = element.attribute(by: "Transmission")?.double
                
        self.interpolationTo = (try? element.attribute(by: "InterpolationTo")?.toEnum()) ?? .linear
        
        self.measurements = try xml.parseChildrenToArray(tree: tree)
    }
}

extension MeasurementPoint: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.energy = try element.attribute(named: "Energy").double ?? 0
        self.wavelength = try element.attribute(named: "WaveLength").double ?? 0
    }
}

extension Filter: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = try element.attribute(named: "Name").text
        self.color = element.attribute(by: "Color").map { ColorCIE(from: $0.text) } ?? ColorCIE(x: 0.3127, y: 0.3290, Y: 1.0)

        self.measurements = try xml.parseChildrenToArray(tree: tree)
    }
}

extension ColorSpace: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = element.attribute(by: "Name")?.text ?? "Default"
        self.mode = (try? element.attribute(by: "Mode")?.toEnum()) ?? .srgb

        // Custom-gamut primaries (used when Mode = Custom).
        self.red = element.attribute(by: "Red").map { ColorCIE(from: $0.text) }
        self.green = element.attribute(by: "Green").map { ColorCIE(from: $0.text) }
        self.blue = element.attribute(by: "Blue").map { ColorCIE(from: $0.text) }
        self.whitePoint = element.attribute(by: "WhitePoint").map { ColorCIE(from: $0.text) }
    }
}

extension DMXProfile: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = element.attribute(by: "Name")?.text ?? ""
        self.points = try xml.parseChildrenToArray(tree: tree)
    }
}

extension Point: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.dmxPercentage = element.attribute(by: "DMXPercentage")?.double ?? 0

        self.cfc0 = element.attribute(by: "CFC0")?.double ?? 0
        self.cfc1 = element.attribute(by: "CFC1")?.double ?? 0
        self.cfc2 = element.attribute(by: "CFC2")?.double ?? 0
        self.cfc3 = element.attribute(by: "CFC3")?.double ?? 0
    }
}

extension Properties: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        self.legHeight = try xml["LegHeight"].element?.attribute(named: "Value").double ?? 0
        self.weight = try xml["Weight"].element?.attribute(named: "Value").double ?? 0
        
        if xml["OperatingTemperature"].element != nil {
            self.operatingTemp = try xml["OperatingTemperature"].parse(tree: tree)
        } else {
            self.operatingTemp = OperatingTemp(low: 0, high: 40)
        }
    }
}

extension OperatingTemp: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.low = element.attribute(by: "Low")?.double ?? 0
        self.high = element.attribute(by: "High")?.double ?? 40
    }
}

///
/// DMX Mode Schema
///

extension DMXMode: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = try element.attribute(named: "Name").text
        self.description = element.attribute(by: "Description")?.text ?? ""
                
        self.channels = try xml["DMXChannels"].parseChildrenToArray(tree: tree)
        self.relations = try xml["Relations"].parseChildrenToArray(parent: xml, tree: tree)
        self.macros = try xml["FTMacros"].parseChildrenToArray(parent: xml, tree: tree)
    }
}

extension DMXChannel: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.offset = []

        // TODO: Handle overrides from geometry nodes
        
        self.dmxBreak = element.attribute(by: "DMXBreak")?.int ?? 1

        if let offset = element.attribute(by: "Offset"), offset.text != "None" {
            self.offset = offset.text.split(separator: ",").map { Int($0) ?? 0 }
        }
        
        
        self.logicalChannels = try xml.parseChildrenToArray(tree: tree)
        
        // Initial Function
        //
        // technically we do have a link but it does not follow convention of Node
        // the default is first logical channel function
        // the name of the channel is actually the first element in the Initial Function attribute
        if element.attribute(by: "InitialFunction") != nil {
            let path = element.attribute(by: "InitialFunction")!.text
            let initialFunctionParts = path.components(separatedBy: ".")
            
            guard initialFunctionParts.count == 3 else { throw XMLParsingError.initialFunctionPathInvalid}
            
            self.name = initialFunctionParts.first
            
            let foundInitial: ChannelFunction? = try xml
                .filterChildren({ child, _ in
                    return (try? child.attribute(named: "Attribute").text == initialFunctionParts[1]) ?? false
                }).children.first?
                .filterChildren({child, _ in
                    return (try? child.attribute(named: "Name").text == initialFunctionParts[2]) ?? false
                }).children.first?.parse(index: 0, tree: tree)
            

            self.initialFunction =  try foundInitial ?? xml["LogicalChannel"].firstChild().parse(index: 0, tree: tree)
            
        } else {
            // "Default value is the first channel function of the first logical function of this DMX channel."
                        
            self.initialFunction = logicalChannels.first?.channelFunctions.first
        }
        
        
        if let highlight = element.attribute(by: "Highlight")?.text, highlight != "None" {
            self.highlight = DMXValue(from: highlight)
        }
        
        self.geometry = try element.attribute(named: "Geometry").text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension LogicalChannel: XMLDecodable {
    init(xml: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.attribute = try element.attribute(named: "Attribute").resolveNode(base: tree["AttributeDefinitions"]["Attributes"], tree: tree)
        
        self.snap = (try? element.attribute(by: "Snap")?.toEnum()) ?? .no
        self.master = (try? element.attribute(by: "Master")?.toEnum()) ?? .none
        
        self.mibFade = (element.attribute(by: "MibFade") ?? element.attribute(by: "MIBFade"))?.double ?? 0
        self.dmxChangeTimeLimit = element.attribute(by: "DMXChangeTimeLimit")?.double ?? 0
        
        self.channelFunctions = try xml.parseChildrenToArray(tree: tree)
    }
}

extension ChannelFunction: XMLDecodableWithIndex {
    init(xml: XMLIndexer, index: Int, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }

        self.name = try element.attribute(by: "Name")?.text ?? element.attribute(named: "Attribute").text + " " + String(index+1)
        
        if (element.attribute(by: "Attribute")?.text != "NoFeature") {
            self.attribute = try element.attribute(by: "Attribute")?.resolveNode(base: tree["AttributeDefinitions"]["Attributes"], tree: tree)
        }
        
        self.originalAttribute = element.attribute(by: "OriginalAttribute")?.text ?? ""
        self.dmxFrom = DMXValue(from: element.attribute(by: "DMXFrom")?.text ?? "0/1")
        self.dmxDefault = DMXValue(from: element.attribute(by: "Default")?.text ?? "0/1")
        
        self.physicalFrom = element.attribute(by: "PhysicalFrom")?.double ?? 0
        self.physicalTo = element.attribute(by: "PhysicalTo")?.double ?? 1
        self.realFade = element.attribute(by: "RealFade")?.double ?? 0
        self.realAcceleration = element.attribute(by: "RealAcceleration")?.double ?? 0
        
        // handle node resolution for each type of function
        
        // Wheel
        self.wheel = try element.attribute(by: "Wheel")?.resolveNode(base: tree["Wheels"], tree: tree)
        
        // Emitter
        self.emitter = try element.attribute(by: "Emitter")?.resolveNode(base: tree["PhysicalDescriptions"]["Emitters"], tree: tree)
        
        // Filter
        self.filter = try element.attribute(by: "Filter")?.resolveNode(base: tree["PhysicalDescriptions"]["Filters"], tree: tree)
        
        // ColorSpace (default child or an AdditionalColorSpaces entry)
        self.colorSpace = try? element.attribute(by: "ColorSpace")?.resolveNode(base: tree["PhysicalDescriptions"], tree: tree)
        
        // Mode Master
        self.modeMaster = element.attribute(by: "ModeMaster")?.text
        // modeFrom/modeTo are only used when modeMaster is prsent
        if self.modeMaster != nil {
            self.modeFrom = DMXValue(from: element.attribute(by: "ModeFrom")?.text ?? "0/1")
            self.modeTo = DMXValue(from: element.attribute(by: "ModeTo")?.text ?? "0/1")
        }
        
        // DMX Profile
        self.dmxProfile = try? element.attribute(by: "DMXProfile")?.resolveNode(base: tree["PhysicalDescriptions"]["DMXProfiles"], tree: tree)
        
        self.minimum = element.attribute(by: "Min")?.double ?? self.physicalFrom
        self.maximum = element.attribute(by: "Max")?.double ?? self.physicalTo
        self.customName = element.attribute(by: "CustomName")?.text
        
        self.channelSets = try xml.filterChildren({ child, _ in child.name == "ChannelSet"}).parseChildrenToArray(parent: xml, tree: tree)
        self.subChannelSets = try xml.filterChildren({ child, _ in child.name == "SubChannelSet"}).parseChildrenToArray(parent: xml, tree: tree)
    }
}


extension ChannelSet: XMLDecodableWithParent {
    init(xml: XMLIndexer, parent: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        guard let parentElement = parent.element else { throw XMLParsingError.elementMissing }
        
        self.name = element.attribute(by: "Name")?.text ?? ""
        
        self.dmxFrom = DMXValue(from: element.attribute(by: "DMXFrom")?.text ?? "0/1")
        
        // the defaults for these reference parent, they will be nil if not provided
        self.physicalFrom = element.attribute(by: "PhysicalFrom")?.double
                                ?? parentElement.attribute(by: "PhysicalFrom")?.double ?? 0
        self.physicalTo = element.attribute(by: "PhysicalTo")?.double
                                ?? parentElement.attribute(by: "PhysicalTo")?.double ?? 1
        
        self.wheelSlotIndex = element.attribute(by: "WheelSlotIndex")?.int
    }
}

extension SubChannelSet: XMLDecodableWithParent {
    init(xml: XMLIndexer, parent: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = element.attribute(by: "Name")?.text ?? ""
        
        self.physicalFrom = (try? element.attribute(named: "PhysicalFrom"))?.double ?? 0
        self.physicalTo = (try? element.attribute(named: "PhysicalTo"))?.double ?? 1
        
        // SubPhysicalUnit is optional; resolve it against the parent function's attribute.
        if let subPhysical = element.attribute(by: "SubPhysicalUnit"),
           let attributeName = parent.element?.attribute(by: "Attribute") {
            let associatedAttribute = try tree["AttributeDefinitions"]["Attributes"].findChild(with: "Name", being: attributeName.text)
            self.subPhysicalUnit = try subPhysical.resolveNode(base: associatedAttribute, tree: tree)
        } else {
            self.subPhysicalUnit = nil
        }

        self.dmxProfile = try? element.attribute(by: "DMXProfile")?.resolveNode(base: tree["PhysicalDescriptions"]["DMXProfiles"], tree: tree)
    }
}

extension Relation: XMLDecodableWithParent {
    init(xml: XMLIndexer, parent: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = try element.attribute(named: "Name").text
        
        self.master = try element.attribute(named: "Master").resolveNode(base: parent.child(named: "DMXChannels"), tree: tree)
        
        self.follower = try element.attribute(named: "Follower").resolveNode(base: parent.child(named: "DMXChannels"), tree: tree)
        
        self.type = try element.attribute(named: "Type").toEnum()
    }
}

extension Macro: XMLDecodableWithParent {
    init(xml: XMLIndexer, parent: XMLIndexer, tree: XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.name = try element.attribute(named: "Name").text
        
        if element.attribute(by: "ChannelFunction") != nil {
            self.channelFunction = try element.attribute(named: "ChannelFunction").resolveNode(base: parent["DMXChannels"], tree: tree)
        }
        
        self.steps = try xml["MacroDMX"].parseChildrenToArray(parent: parent, tree: tree)
    }
}

extension MacroStep: XMLDecodableWithParent {
    init(xml: SWXMLHash.XMLIndexer, parent: SWXMLHash.XMLIndexer, tree: SWXMLHash.XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
        
        self.duration = (try? element.attribute(named: "Duration"))?.double ?? 1
        self.values = try xml.parseChildrenToArray(parent: parent, tree: tree)
    }
}

extension MacroValue: XMLDecodableWithParent {
    init(xml: SWXMLHash.XMLIndexer, parent: SWXMLHash.XMLIndexer, tree: SWXMLHash.XMLIndexer) throws {
        guard let element = xml.element else { throw XMLParsingError.elementMissing }
                
        // do our own lookup of the channel since it does not follow normal Node Name schema
        var foundChannel: DMXChannel? = nil
        
        for child in parent["DMXChannels"].children {
            let parts = child.element?.attribute(by: "InitialFunction")?.text.components(separatedBy: ".")
            
            if try parts?[0] == element.attribute(named: "DMXChannel").text {
                foundChannel = try child.parse(tree: tree)
            }
        }
     
        self.dmxChannel = try foundChannel ?? parent["DMXChannels"].firstChild().parse(tree: tree)
        self.value = try DMXValue(from: element.attribute(named: "Value").text)
    }
}

extension AttributeType {
    static func compile(regex: String) -> NSRegularExpression {
        return try! NSRegularExpression(pattern: regex)
    }
    
    static let enumerationRegex = compile(regex: "[0-9]+")
    
    static let regexes: [NSRegularExpression : ([Int]) -> AttributeType] = [
        compile(regex: "^Dimmer$") : { _ in .dimmer },
        compile(regex: "^Pan$") : { _ in .pan },
        compile(regex: "^Tilt$") : { _ in .tilt },
        compile(regex: "^PanRotate$") : { _ in .panRotate },
        compile(regex: "^TiltRotate$") : { _ in .tiltRotate },
        compile(regex: "^PositionEffect$") : { _ in .positionEffect },
        compile(regex: "^PositionEffectRate$") : { _ in .positionEffectRate },
        compile(regex: "^PositionEffectFade$") : { _ in .positionEffectFade },
        compile(regex: "^XYZ_X$") : { _ in .xYZ_X },
        compile(regex: "^XYZ_Y$") : { _ in .xYZ_Y },
        compile(regex: "^XYZ_Z$") : { _ in .xYZ_Z },
        compile(regex: "^Rot_X$") : { _ in .rot_X },
        compile(regex: "^Rot_Y$") : { _ in .rot_Y },
        compile(regex: "^Rot_Z$") : { _ in .rot_Z },
        compile(regex: "^Scale_X$") : { _ in .scale_X },
        compile(regex: "^Scale_Y$") : { _ in .scale_Y },
        compile(regex: "^Scale_Z$") : { _ in .scale_Z },
        compile(regex: "^Scale_XYZ$") : { _ in .scale_XYZ },
        compile(regex: "^Gobo(?<n>[0-9]+)$") : { e in .gobo(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)SelectSpin$") : { e in .goboSelectSpin(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)SelectShake$") : { e in .goboSelectShake(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)SelectEffects$") : { e in .goboSelectEffects(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)WheelIndex$") : { e in .goboWheelIndex(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)WheelSpin$") : { e in .goboWheelSpin(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)WheelShake$") : { e in .goboWheelShake(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)WheelRandom$") : { e in .goboWheelRandom(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)WheelAudio$") : { e in .goboWheelAudio(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)Pos$") : { e in .goboPos(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)PosRotate$") : { e in .goboPosRotate(n: e[0]) },
        compile(regex: "^Gobo(?<n>[0-9]+)PosShake$") : { e in .goboPosShake(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)$") : { e in .animationWheel(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)Audio$") : { e in .animationWheelAudio(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)Macro$") : { e in .animationWheelMacro(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)Random$") : { e in .animationWheelRandom(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)SelectEffects$") : { e in .animationWheelSelectEffects(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)SelectShake$") : { e in .animationWheelSelectShake(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)SelectSpin$") : { e in .animationWheelSelectSpin(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)Pos$") : { e in .animationWheelPos(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)PosRotate$") : { e in .animationWheelPosRotate(n: e[0]) },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)PosShake$") : { e in .animationWheelPosShake(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)$") : { e in .animationSystem(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)Ramp$") : { e in .animationSystemRamp(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)Shake$") : { e in .animationSystemShake(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)Audio$") : { e in .animationSystemAudio(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)Random$") : { e in .animationSystemRandom(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)Pos$") : { e in .animationSystemPos(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)PosRotate$") : { e in .animationSystemPosRotate(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)PosShake$") : { e in .animationSystemPosShake(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)PosRandom$") : { e in .animationSystemPosRandom(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)PosAudio$") : { e in .animationSystemPosAudio(n: e[0]) },
        compile(regex: "^AnimationSystem(?<n>[0-9]+)Macro$") : { e in .animationSystemMacro(n: e[0]) },
        compile(regex: "^MediaFolder(?<n>[0-9]+)$") : { e in .mediaFolder(n: e[0]) },
        compile(regex: "^MediaContent(?<n>[0-9]+)$") : { e in .mediaContent(n: e[0]) },
        compile(regex: "^ModelFolder(?<n>[0-9]+)$") : { e in .modelFolder(n: e[0]) },
        compile(regex: "^ModelContent(?<n>[0-9]+)$") : { e in .modelContent(n: e[0]) },
        compile(regex: "^PlayMode$") : { _ in .playMode },
        compile(regex: "^PlayBegin$") : { _ in .playBegin },
        compile(regex: "^PlayEnd$") : { _ in .playEnd },
        compile(regex: "^PlaySpeed$") : { _ in .playSpeed },
        compile(regex: "^ColorEffects(?<n>[0-9]+)$") : { e in .colorEffects(n: e[0]) },
        compile(regex: "^Color(?<n>[0-9]+)$") : { e in .color(n: e[0]) },
        compile(regex: "^Color(?<n>[0-9]+)WheelIndex$") : { e in .colorWheelIndex(n: e[0]) },
        compile(regex: "^Color(?<n>[0-9]+)WheelSpin$") : { e in .colorWheelSpin(n: e[0]) },
        compile(regex: "^Color(?<n>[0-9]+)WheelRandom$") : { e in .colorWheelRandom(n: e[0]) },
        compile(regex: "^Color(?<n>[0-9]+)WheelAudio$") : { e in .colorWheelAudio(n: e[0]) },
        compile(regex: "^ColorAdd_R$") : { _ in .colorAdd_R },
        compile(regex: "^ColorAdd_G$") : { _ in .colorAdd_G },
        compile(regex: "^ColorAdd_B$") : { _ in .colorAdd_B },
        compile(regex: "^ColorAdd_C$") : { _ in .colorAdd_C },
        compile(regex: "^ColorAdd_M$") : { _ in .colorAdd_M },
        compile(regex: "^ColorAdd_Y$") : { _ in .colorAdd_Y },
        compile(regex: "^ColorAdd_RY$") : { _ in .colorAdd_RY },
        compile(regex: "^ColorAdd_GY$") : { _ in .colorAdd_GY },
        compile(regex: "^ColorAdd_GC$") : { _ in .colorAdd_GC },
        compile(regex: "^ColorAdd_BC$") : { _ in .colorAdd_BC },
        compile(regex: "^ColorAdd_BM$") : { _ in .colorAdd_BM },
        compile(regex: "^ColorAdd_RM$") : { _ in .colorAdd_RM },
        compile(regex: "^ColorAdd_W$") : { _ in .colorAdd_W },
        compile(regex: "^ColorAdd_WW$") : { _ in .colorAdd_WW },
        compile(regex: "^ColorAdd_CW$") : { _ in .colorAdd_CW },
        compile(regex: "^ColorAdd_UV$") : { _ in .colorAdd_UV },
        compile(regex: "^ColorSub_R$") : { _ in .colorSub_R },
        compile(regex: "^ColorSub_G$") : { _ in .colorSub_G },
        compile(regex: "^ColorSub_B$") : { _ in .colorSub_B },
        compile(regex: "^ColorSub_C$") : { _ in .colorSub_C },
        compile(regex: "^ColorSub_M$") : { _ in .colorSub_M },
        compile(regex: "^ColorSub_Y$") : { _ in .colorSub_Y },
        compile(regex: "^ColorMacro(?<n>[0-9]+)$") : { e in .colorMacro(n: e[0]) },
        compile(regex: "^ColorMacro(?<n>[0-9]+)Rate$") : { e in .colorMacroRate(n: e[0]) },
        compile(regex: "^CTO$") : { _ in .cTO },
        compile(regex: "^CTC$") : { _ in .cTC },
        compile(regex: "^CTB$") : { _ in .cTB },
        compile(regex: "^Tint$") : { _ in .tint },
        compile(regex: "^HSB_Hue$") : { _ in .hSB_Hue },
        compile(regex: "^HSB_Saturation$") : { _ in .hSB_Saturation },
        compile(regex: "^HSB_Brightness$") : { _ in .hSB_Brightness },
        compile(regex: "^HSB_Quality$") : { _ in .hSB_Quality },
        compile(regex: "^CIE_X$") : { _ in .cIE_X },
        compile(regex: "^CIE_Y$") : { _ in .cIE_Y },
        compile(regex: "^CIE_Brightness$") : { _ in .cIE_Brightness },
        compile(regex: "^ColorRGB_Red$") : { _ in .colorRGB_Red },
        compile(regex: "^ColorRGB_Green$") : { _ in .colorRGB_Green },
        compile(regex: "^ColorRGB_Blue$") : { _ in .colorRGB_Blue },
        compile(regex: "^ColorRGB_Cyan$") : { _ in .colorRGB_Cyan },
        compile(regex: "^ColorRGB_Magenta$") : { _ in .colorRGB_Magenta },
        compile(regex: "^ColorRGB_Yellow$") : { _ in .colorRGB_Yellow },
        compile(regex: "^ColorRGB_Quality$") : { _ in .colorRGB_Quality },
        compile(regex: "^VideoBoost_R$") : { _ in .videoBoost_R },
        compile(regex: "^VideoBoost_G$") : { _ in .videoBoost_G },
        compile(regex: "^VideoBoost_B$") : { _ in .videoBoost_B },
        compile(regex: "^VideoHueShift$") : { _ in .videoHueShift },
        compile(regex: "^VideoSaturation$") : { _ in .videoSaturation },
        compile(regex: "^VideoBrightness$") : { _ in .videoBrightness },
        compile(regex: "^VideoContrast$") : { _ in .videoContrast },
        compile(regex: "^VideoKeyColor_R$") : { _ in .videoKeyColor_R },
        compile(regex: "^VideoKeyColor_G$") : { _ in .videoKeyColor_G },
        compile(regex: "^VideoKeyColor_B$") : { _ in .videoKeyColor_B },
        compile(regex: "^VideoKeyIntensity$") : { _ in .videoKeyIntensity },
        compile(regex: "^VideoKeyTolerance$") : { _ in .videoKeyTolerance },
        compile(regex: "^StrobeDuration$") : { _ in .strobeDuration },
        compile(regex: "^StrobeRate$") : { _ in .strobeRate },
        compile(regex: "^StrobeFrequency$") : { _ in .strobeFrequency },
        compile(regex: "^StrobeModeShutter$") : { _ in .strobeModeShutter },
        compile(regex: "^StrobeModeStrobe$") : { _ in .strobeModeStrobe },
        compile(regex: "^StrobeModePulse$") : { _ in .strobeModePulse },
        compile(regex: "^StrobeModePulseOpen$") : { _ in .strobeModePulseOpen },
        compile(regex: "^StrobeModePulseClose$") : { _ in .strobeModePulseClose },
        compile(regex: "^StrobeModeRandom$") : { _ in .strobeModeRandom },
        compile(regex: "^StrobeModeRandomPulse$") : { _ in .strobeModeRandomPulse },
        compile(regex: "^StrobeModeRandomPulseOpen$") : { _ in .strobeModeRandomPulseOpen },
        compile(regex: "^StrobeModeRandomPulseClose$") : { _ in .strobeModeRandomPulseClose },
        compile(regex: "^StrobeModeEffect$") : { _ in .strobeModeEffect },
        compile(regex: "^Shutter(?<n>[0-9]+)$") : { e in .shutter(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)Strobe$") : { e in .shutterStrobe(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)StrobePulse$") : { e in .shutterStrobePulse(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)StrobePulseClose$") : { e in .shutterStrobePulseClose(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)StrobePulseOpen$") : { e in .shutterStrobePulseOpen(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)StrobeRandom$") : { e in .shutterStrobeRandom(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)StrobeRandomPulse$") : { e in .shutterStrobeRandomPulse(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)StrobeRandomPulseClose$") : { e in .shutterStrobeRandomPulseClose(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)StrobeRandomPulseOpen$") : { e in .shutterStrobeRandomPulseOpen(n: e[0]) },
        compile(regex: "^Shutter(?<n>[0-9]+)StrobeEffect$") : { e in .shutterStrobeEffect(n: e[0]) },
        compile(regex: "^Iris$") : { _ in .iris },
        compile(regex: "^IrisStrobe$") : { _ in .irisStrobe },
        compile(regex: "^IrisStrobeRandom$") : { _ in .irisStrobeRandom },
        compile(regex: "^IrisPulseClose$") : { _ in .irisPulseClose },
        compile(regex: "^IrisPulseOpen$") : { _ in .irisPulseOpen },
        compile(regex: "^IrisRandomPulseClose$") : { _ in .irisRandomPulseClose },
        compile(regex: "^IrisRandomPulseOpen$") : { _ in .irisRandomPulseOpen },
        compile(regex: "^Frost(?<n>[0-9]+)$") : { e in .frost(n: e[0]) },
        compile(regex: "^Frost(?<n>[0-9]+)PulseOpen$") : { e in .frostPulseOpen(n: e[0]) },
        compile(regex: "^Frost(?<n>[0-9]+)PulseClose$") : { e in .frostPulseClose(n: e[0]) },
        compile(regex: "^Frost(?<n>[0-9]+)Ramp$") : { e in .frostRamp(n: e[0]) },
        compile(regex: "^Prism(?<n>[0-9]+)$") : { e in .prism(n: e[0]) },
        compile(regex: "^Prism(?<n>[0-9]+)SelectSpin$") : { e in .prismSelectSpin(n: e[0]) },
        compile(regex: "^Prism(?<n>[0-9]+)Macro$") : { e in .prismMacro(n: e[0]) },
        compile(regex: "^Prism(?<n>[0-9]+)Pos$") : { e in .prismPos(n: e[0]) },
        compile(regex: "^Prism(?<n>[0-9]+)PosRotate$") : { e in .prismPosRotate(n: e[0]) },
        compile(regex: "^Effects(?<n>[0-9]+)$") : { e in .effects(n: e[0]) },
        compile(regex: "^Effects(?<n>[0-9]+)Rate$") : { e in .effectsRate(n: e[0]) },
        compile(regex: "^Effects(?<n>[0-9]+)Fade$") : { e in .effectsFade(n: e[0]) },
        compile(regex: "^Effects(?<n>[0-9]+)Adjust(?<m>[0-9]+)$") : { e in .effectsAdjust(n: e[0], m: e[1]) },
        compile(regex: "^Effects(?<n>[0-9]+)Pos$") : { e in .effectsPos(n: e[0]) },
        compile(regex: "^Effects(?<n>[0-9]+)PosRotate$") : { e in .effectsPosRotate(n: e[0]) },
        compile(regex: "^EffectsSync$") : { _ in .effectsSync },
        compile(regex: "^BeamShaper$") : { _ in .beamShaper },
        compile(regex: "^BeamShaperMacro$") : { _ in .beamShaperMacro },
        compile(regex: "^BeamShaperPos$") : { _ in .beamShaperPos },
        compile(regex: "^BeamShaperPosRotate$") : { _ in .beamShaperPosRotate },
        compile(regex: "^Zoom$") : { _ in .zoom },
        compile(regex: "^ZoomModeSpot$") : { _ in .zoomModeSpot },
        compile(regex: "^ZoomModeBeam$") : { _ in .zoomModeBeam },
        compile(regex: "^DigitalZoom$") : { _ in .digitalZoom },
        compile(regex: "^Focus(?<n>[0-9]+)$") : { e in .focus(n: e[0]) },
        compile(regex: "^Focus(?<n>[0-9]+)Adjust$") : { e in .focusAdjust(n: e[0]) },
        compile(regex: "^Focus(?<n>[0-9]+)Distance$") : { e in .focusDistance(n: e[0]) },
        compile(regex: "^Control(?<n>[0-9]+)$") : { e in .control(n: e[0]) },
        compile(regex: "^DimmerMode$") : { _ in .dimmerMode },
        compile(regex: "^DimmerCurve$") : { _ in .dimmerCurve },
        compile(regex: "^BlackoutMode$") : { _ in .blackoutMode },
        compile(regex: "^LEDFrequency$") : { _ in .lEDFrequency },
        compile(regex: "^LEDZoneMode$") : { _ in .lEDZoneMode },
        compile(regex: "^PixelMode$") : { _ in .pixelMode },
        compile(regex: "^PanMode$") : { _ in .panMode },
        compile(regex: "^TiltMode$") : { _ in .tiltMode },
        compile(regex: "^PanTiltMode$") : { _ in .panTiltMode },
        compile(regex: "^PositionModes$") : { _ in .positionModes },
        compile(regex: "^Gobo(?<n>[0-9]+)WheelMode$") : { e in .goboWheelMode(n: e[0]) },
        compile(regex: "^GoboWheelShortcutMode$") : { _ in .goboWheelShortcutMode },
        compile(regex: "^AnimationWheel(?<n>[0-9]+)Mode$") : { e in .animationWheelMode(n: e[0]) },
        compile(regex: "^AnimationWheelShortcutMode$") : { _ in .animationWheelShortcutMode },
        compile(regex: "^Color(?<n>[0-9]+)Mode$") : { e in .colorMode(n: e[0]) },
        compile(regex: "^ColorWheelShortcutMode$") : { _ in .colorWheelShortcutMode },
        compile(regex: "^CyanMode$") : { _ in .cyanMode },
        compile(regex: "^MagentaMode$") : { _ in .magentaMode },
        compile(regex: "^YellowMode$") : { _ in .yellowMode },
        compile(regex: "^ColorMixMode$") : { _ in .colorMixMode },
        compile(regex: "^ChromaticMode$") : { _ in .chromaticMode },
        compile(regex: "^ColorCalibrationMode$") : { _ in .colorCalibrationMode },
        compile(regex: "^ColorConsistency$") : { _ in .colorConsistency },
        compile(regex: "^ColorControl$") : { _ in .colorControl },
        compile(regex: "^ColorModelMode$") : { _ in .colorModelMode },
        compile(regex: "^ColorSettingsReset$") : { _ in .colorSettingsReset },
        compile(regex: "^ColorUniformity$") : { _ in .colorUniformity },
        compile(regex: "^CRIMode$") : { _ in .cRIMode },
        compile(regex: "^CustomColor$") : { _ in .customColor },
        compile(regex: "^UVStability$") : { _ in .uVStability },
        compile(regex: "^WavelengthCorrection$") : { _ in .wavelengthCorrection },
        compile(regex: "^WhiteCount$") : { _ in .whiteCount },
        compile(regex: "^StrobeMode$") : { _ in .strobeMode },
        compile(regex: "^ZoomMode$") : { _ in .zoomMode },
        compile(regex: "^FocusMode$") : { _ in .focusMode },
        compile(regex: "^IrisMode$") : { _ in .irisMode },
        compile(regex: "^Fan(?<n>[0-9]+)Mode$") : { e in .fanMode(n: e[0]) },
        compile(regex: "^FollowSpotMode$") : { _ in .followSpotMode },
        compile(regex: "^BeamEffectIndexRotateMode$") : { _ in .beamEffectIndexRotateMode },
        compile(regex: "^IntensityMSpeed$") : { _ in .intensityMSpeed },
        compile(regex: "^PositionMSpeed$") : { _ in .positionMSpeed },
        compile(regex: "^ColorMixMSpeed$") : { _ in .colorMixMSpeed },
        compile(regex: "^ColorWheelSelectMSpeed$") : { _ in .colorWheelSelectMSpeed },
        compile(regex: "^GoboWheel(?<n>[0-9]+)MSpeed$") : { e in .goboWheelMSpeed(n: e[0]) },
        compile(regex: "^IrisMSpeed$") : { _ in .irisMSpeed },
        compile(regex: "^Prism(?<n>[0-9]+)MSpeed$") : { e in .prismMSpeed(n: e[0]) },
        compile(regex: "^FocusMSpeed$") : { _ in .focusMSpeed },
        compile(regex: "^Frost(?<n>[0-9]+)MSpeed$") : { e in .frostMSpeed(n: e[0]) },
        compile(regex: "^ZoomMSpeed$") : { _ in .zoomMSpeed },
        compile(regex: "^FrameMSpeed$") : { _ in .frameMSpeed },
        compile(regex: "^GlobalMSpeed$") : { _ in .globalMSpeed },
        compile(regex: "^ReflectorAdjust$") : { _ in .reflectorAdjust },
        compile(regex: "^FixtureGlobalReset$") : { _ in .fixtureGlobalReset },
        compile(regex: "^DimmerReset$") : { _ in .dimmerReset },
        compile(regex: "^ShutterReset$") : { _ in .shutterReset },
        compile(regex: "^BeamReset$") : { _ in .beamReset },
        compile(regex: "^ColorMixReset$") : { _ in .colorMixReset },
        compile(regex: "^ColorWheelReset$") : { _ in .colorWheelReset },
        compile(regex: "^FocusReset$") : { _ in .focusReset },
        compile(regex: "^FrameReset$") : { _ in .frameReset },
        compile(regex: "^GoboWheelReset$") : { _ in .goboWheelReset },
        compile(regex: "^IntensityReset$") : { _ in .intensityReset },
        compile(regex: "^IrisReset$") : { _ in .irisReset },
        compile(regex: "^PositionReset$") : { _ in .positionReset },
        compile(regex: "^PanReset$") : { _ in .panReset },
        compile(regex: "^TiltReset$") : { _ in .tiltReset },
        compile(regex: "^ZoomReset$") : { _ in .zoomReset },
        compile(regex: "^CTBReset$") : { _ in .cTBReset },
        compile(regex: "^CTOReset$") : { _ in .cTOReset },
        compile(regex: "^CTCReset$") : { _ in .cTCReset },
        compile(regex: "^AnimationSystemReset$") : { _ in .animationSystemReset },
        compile(regex: "^FixtureCalibrationReset$") : { _ in .fixtureCalibrationReset },
        compile(regex: "^Function$") : { _ in .function },
        compile(regex: "^LampControl$") : { _ in .lampControl },
        compile(regex: "^DisplayIntensity$") : { _ in .displayIntensity },
        compile(regex: "^DMXInput$") : { _ in .dMXInput },
        compile(regex: "^NoFeature$") : { _ in .noFeature },
        compile(regex: "^Blower(?<n>[0-9]+)$") : { e in .blower(n: e[0]) },
        compile(regex: "^Fan(?<n>[0-9]+)$") : { e in .fan(n: e[0]) },
        compile(regex: "^Fog(?<n>[0-9]+)$") : { e in .fog(n: e[0]) },
        compile(regex: "^Haze(?<n>[0-9]+)$") : { e in .haze(n: e[0]) },
        compile(regex: "^LampPowerMode$") : { _ in .lampPowerMode },
        compile(regex: "^Fans$") : { _ in .fans },
        compile(regex: "^Blade(?<n>[0-9]+)A$") : { e in .bladeA(n: e[0]) },
        compile(regex: "^Blade(?<n>[0-9]+)B$") : { e in .bladeB(n: e[0]) },
        compile(regex: "^Blade(?<n>[0-9]+)Rot$") : { e in .bladeRot(n: e[0]) },
        compile(regex: "^ShaperRot$") : { _ in .shaperRot },
        compile(regex: "^ShaperMacros$") : { _ in .shaperMacros },
        compile(regex: "^ShaperMacrosSpeed$") : { _ in .shaperMacrosSpeed },
        compile(regex: "^BladeSoft(?<n>[0-9]+)A$") : { e in .bladeSoftA(n: e[0]) },
        compile(regex: "^BladeSoft(?<n>[0-9]+)B$") : { e in .bladeSoftB(n: e[0]) },
        compile(regex: "^KeyStone(?<n>[0-9]+)A$") : { e in .keyStoneA(n: e[0]) },
        compile(regex: "^KeyStone(?<n>[0-9]+)B$") : { e in .keyStoneB(n: e[0]) },
        compile(regex: "^Video$") : { _ in .video },
        compile(regex: "^VideoEffect(?<n>[0-9]+)Type$") : { e in .videoEffectType(n: e[0]) },
        compile(regex: "^VideoEffect(?<n>[0-9]+)Parameter(?<m>[0-9]+)$") : { e in .videoEffectParameter(n: e[0], m: e[1]) },
        compile(regex: "^VideoCamera(?<n>[0-9]+)$") : { e in .videoCamera(n: e[0]) },
        compile(regex: "^VideoSoundVolume(?<n>[0-9]+)$") : { e in .videoSoundVolume(n: e[0]) },
        compile(regex: "^VideoBlendMode$") : { _ in .videoBlendMode },
        compile(regex: "^InputSource$") : { _ in .inputSource },
        compile(regex: "^FieldOfView$") : { _ in .fieldOfView },
    ]
    
    public static func from(_ str: String) -> Self {
        // Get any numbers out of the string for later
        
        // Helper Function
        func stringMatches(_ string: String, regex: NSRegularExpression) -> (Bool, [Int]) {
            if let match = regex.firstMatch(in: str, options: [], range: NSRange(str.startIndex..<str.endIndex, in: str)) {
                var enumerations: [Int] = []
                
                // Extract the enumerations if the exist
                for capture in ["n", "m"] {
                    let range = match.range(withName: capture)
                    if range.location != NSNotFound {
                        if let e = Int((str as NSString).substring(with: range)) {
                            enumerations.append(e)
                        }
                    }
                }
                
                return (true, enumerations)
            }
            
            return (false, [])
        }
        
        for (regex, generator) in regexes {
            let match = stringMatches(str, regex: regex)
            if match.0 {
                return generator(match.1)
            }
        }
        
        return .custom
    }
}



