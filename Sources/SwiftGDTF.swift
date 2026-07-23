//
//  SwiftGDTF.swift
//
//
//  Created by Brandon Wees on 7/4/24.
//

import Foundation
import SWXMLHash
import ZIPFoundation


/// Loads the description.xml data from a GDTF file
/// - Parameter url: URL to the compressed GDTF data
/// - Throws: Errors related to parsing description.xml
/// - Returns: XMLIndexer of the provided XML data
func loadXMLFromGDTF(url: URL) throws -> XMLIndexer {
    return try loadXMLFromGDTF(gdtf: try Data(contentsOf: url))
}


/// Loads the description.xml data from a GDTF file
/// - Parameter url: Compressed GDTF data
/// - Throws: Errors related to parsing description.xml
/// - Returns: XMLIndexer of the  provided XML data
func loadXMLFromGDTF(gdtf data: Data) throws -> XMLIndexer {
    let zipArchive = try Archive(data: data, accessMode: .read)
    
    /// Verify a description.xml file was found, otherwise invalid GDTF
    guard let entry = zipArchive["description.xml"] else {
        throw GDTFError.invalidGDTF
    }
    
    /// Make buffer to append extracted ZIP data
    var xmlData = Data()
    
    /// Extract the data into data buffer
    _ = try zipArchive.extract(entry) { data in
        xmlData.append(data)
    }
    
    return try loadXML(xmlData: xmlData)
}


/// Loads XML data into a XMLIndexer
/// - Parameter xmlData: xml data to load
/// - Throws: Errors related to parsing the XML into a XMLIndexer
/// - Returns: XMLIndexer of the provided XML data
func loadXML(xmlData: Data) throws -> XMLIndexer {
    /// Decode as UTF8, if fails throw
    guard let xmlString = String(data: xmlData, encoding: .utf8) else {
        throw GDTFError.invalidGDTFDescription
    }
    
    /// Setup XML parser config
    let config = XMLHash.config { config in
        config.caseInsensitive = true
        config.shouldProcessLazily = false
        config.detectParsingErrors = true
    }
    
    /// parse XML tree and verify we got a GDTF root node
    let xmlTree = config.parse(xmlString)
    guard (xmlTree["GDTF"].element != nil) else {
        throw GDTFError.invalidGDTFDescription
    }
    
    return xmlTree
}


/// Loads a GDTF from a URL to a GDTF file
/// - Parameter url: URL to compressed GDTF file
/// - Throws: Errors related to loading GDTF file
/// - Returns: GDTF object
public func loadGDTF(url: URL) throws -> GDTF {
    let xmlTree = try loadXMLFromGDTF(url: url)
        
    return try GDTF(xml: xmlTree)
}


/// Loads the GDTF Description given a URL to an uncompressed description.xml file
/// - Parameter url: URL to description.xml
/// - Throws: Errors related to loading the description
/// - Returns: GDTF structure from the parsed XML
public func loadGDTFDescription(url: URL) throws -> GDTF {
    let xmlData = try Data(contentsOf: url)
    let xmlTree = try loadXML(xmlData: xmlData)
    
    return try GDTF(xml: xmlTree)
}


/// Convenience function that loads that necessary files to work with a fixture in the specified mode.
/// - Parameters:
///   - mode: The string of the mode to load
///   - url: URL to the GDTF data to load from (compressed ZIP)
/// - Throws: Errors related to loading the fixture package
/// - Returns:
///   - FixturePackage: All needed data to operate the fixture
public func loadFixtureModePackage(mode: String, url: URL) throws -> FixturePackage {
    return try loadFixtureModePackage(mode: mode, gdtf: try Data(contentsOf: url))
}


/// Loads that necessary files to work with a fixture in the specified mode.
/// - Parameters:
///   - mode: The string of the mode to load
///   - gdtf: The GDTF data to load from (compressed ZIP)
/// - Throws: Errors related to loading the fixture package
/// - Returns:
///   - FixturePackage: All needed data to operate the fixture
public func loadFixtureModePackage(mode: String, gdtf: Data) throws -> FixturePackage {
    let xmlTree = try loadXMLFromGDTF(gdtf: gdtf)["GDTF"]["FixtureType"]
    
    /// Find the requested dmx mode
    guard let modeTree = xmlTree["DMXModes"]
        .filterChildren({ child, _ in
            return (try? child.attribute(named: "Name").text == mode) ?? false
        }).children.first
        else { throw GDTFError.dmxModeNotFound }
    
    /// Get initial description data
    var mode: DMXMode = try modeTree.parse(tree: xmlTree)
    let fixtureInfo: FixtureInfo = try xmlTree.parse(tree: xmlTree)

    /// Expand multi-cell geometry (GeometryReference) so `mode.cells`/`allChannels` are
    /// populated — matching the full `loadGDTF` path, which does this in `FixtureType.init`.
    let geometries: [GDTFGeometry] = try xmlTree["Geometries"].parseChildrenToArray(tree: xmlTree)
    mode.applyGeometryExpansion(geometries: geometries)
    
    ///
    /// Load the wheels associated with this mode
    ///
    let zipArchive = try Archive(data: gdtf, accessMode: .read)
    
    /// Dictionary to load file resources into
    var fileResources: [String : Data] = [:]
    
    // Load wheel images from the mode
    for channel in mode.channels {
        if let wheel = channel.initialFunction?.wheel {
            for slot in wheel.slots {
                // if the wheel has a media filename
                if let slotFile = slot.mediaFileName {
                    /// Verify we havent loaded it yet
                    if fileResources[slotFile.name] != nil { continue }
                    
                    /// Verify a wheel was found
                    guard let entry = zipArchive["wheels/\(slotFile.name).\(slotFile.fileExtension)"] else {
                        throw GDTFError.fileResourceNotFound("wheels/\(slotFile.name)")
                    }
                    
                    /// Extract the data into the dictionary
                    _ = try zipArchive.extract(entry) { data in
                        fileResources[slotFile.name] = data
                    }
                }
            }
        }
    }
    
    /// Load thumbnail into resources
    if let thumbnail = fixtureInfo.thumbnail {
        /// Verify a file resource was found
        guard let entry = zipArchive["\(thumbnail.name).\(thumbnail.fileExtension)"] else {
            throw GDTFError.fileResourceNotFound(thumbnail.name)
        }
        
        /// Extract the data into the dictionary
        _ = try zipArchive.extract(entry) { data in
            fileResources[thumbnail.name] = data
        }
    }
    
    return FixturePackage(info: fixtureInfo, mode: mode, fileResources: fileResources)
}

/// Loads a limited amount of data for a fixture, useful for when showing a patch screen
/// - Parameters:
///   - gdtf: The GDTF data to load from (compressed ZIP)
/// - Throws: Errors related to loading the fixture details
/// - Returns:
///   - fixtureDetails: The high level attributes from the Fixture
public func loadFixtureDetails(url: URL) throws -> FixtureDetails {
    return try loadFixtureDetails(gdtf: try Data(contentsOf: url))
}


/// Loads a limited amount of data for a fixture, useful for when showing a patch screen
/// - Parameters:
///   - gdtf: The GDTF data to load from (compressed ZIP)
/// - Throws: Errors related to loading the fixture details
/// - Returns:
///   - fixtureDetails: The high level attributes from the Fixture
public func loadFixtureDetails(gdtf: Data) throws -> FixtureDetails {
    let xmlTree = try loadXMLFromGDTF(gdtf: gdtf)["GDTF"]["FixtureType"]

    let fixtureInfo: FixtureInfo = try xmlTree.parse(tree: xmlTree)
    
    var modes: [HighLevelMode] = []
    for mode in xmlTree["DMXModes"].children {
        guard let element = mode.element else { throw XMLParsingError.elementMissing }

        let description = try element.attribute(named: "Description").text
        let name = try element.attribute(named: "Name").text
        
        let channelList = try mode.child(named: "DMXChannels").children
        
        guard let lastChannel = channelList.last?.element?.attribute(by: "Offset")?.text.components(separatedBy: ",").last else {
            throw XMLParsingError.attributeMissing(named: "Offset", on: channelList.last?.element)
        }
        
        guard let footprint = UInt(lastChannel) else {
            throw XMLParsingError.failedToParseString
        }
        
        modes.append(HighLevelMode(name: name, description: description, footprint: footprint))
    }
    
    return FixtureDetails(info: fixtureInfo, modes: modes)
}
