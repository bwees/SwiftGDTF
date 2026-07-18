import XCTest
@testable import SwiftGDTF

/// Offline tests for `<Geometries>` / `<Models>` parsing and GeometryReference expansion.
final class GeometryTests: XCTestCase {

    // A minimal 3-cell fixture: a top-level "Beam" geometry carrying 4 DMX channels
    // (Dimmer, R, G, B at offsets 1..4) instantiated 3 times via GeometryReference,
    // with break offsets 1, 5, 9. Expected footprint: 12.
    private static let description = """
    <?xml version="1.0" encoding="UTF-8"?>
    <GDTF DataVersion="1.2">
      <FixtureType Name="Test Bar" ShortName="TB" LongName="Test Bar" Manufacturer="ACME" Description="test" FixtureTypeID="11111111-2222-3333-4444-555555555555">
        <AttributeDefinitions>
          <Attributes>
            <Attribute Name="Dimmer" Pretty="Dim"/>
            <Attribute Name="ColorAdd_R" Pretty="R"/>
            <Attribute Name="ColorAdd_G" Pretty="G"/>
            <Attribute Name="ColorAdd_B" Pretty="B"/>
          </Attributes>
        </AttributeDefinitions>
        <Models>
          <Model Name="Beam" File="BeamFile" PrimitiveType="Cube" Length="0.1" Width="0.2" Height="0.3"/>
        </Models>
        <Geometries>
          <Geometry Name="Body" Position="{1,0,0,0}{0,1,0,0}{0,0,1,0}{0,0,0,1}">
            <GeometryReference Geometry="Beam" Name="Pixel1" Position="{1,0,0,0.5}{0,1,0,0}{0,0,1,0}{0,0,0,1}">
              <Break DMXBreak="1" DMXOffset="1"/>
            </GeometryReference>
            <GeometryReference Geometry="Beam" Name="Pixel2" Position="{1,0,0,1.5}{0,1,0,0}{0,0,1,0}{0,0,0,1}">
              <Break DMXBreak="1" DMXOffset="5"/>
            </GeometryReference>
            <GeometryReference Geometry="Beam" Name="Pixel3" Position="{1,0,0,2.5}{0,1,0,0}{0,0,1,0}{0,0,0,1}">
              <Break DMXBreak="1" DMXOffset="9"/>
            </GeometryReference>
          </Geometry>
          <Beam Name="Beam" Model="Beam" BeamAngle="10" FieldAngle="20" BeamType="Spot" ColorTemperature="6500" LuminousFlux="1000" Position="{1,0,0,0}{0,1,0,0}{0,0,1,0}{0,0,0,1}"/>
        </Geometries>
        <DMXModes>
          <DMXMode Name="Default" Description="">
            <DMXChannels>
              <DMXChannel Geometry="Beam" DMXBreak="1" Offset="1">
                <LogicalChannel Attribute="Dimmer">
                  <ChannelFunction Name="Dimmer 1" Attribute="Dimmer" DMXFrom="0/1" Default="0/1"/>
                </LogicalChannel>
              </DMXChannel>
              <DMXChannel Geometry="Beam" DMXBreak="1" Offset="2">
                <LogicalChannel Attribute="ColorAdd_R">
                  <ChannelFunction Name="Red 1" Attribute="ColorAdd_R" DMXFrom="0/1" Default="0/1"/>
                </LogicalChannel>
              </DMXChannel>
              <DMXChannel Geometry="Beam" DMXBreak="1" Offset="3">
                <LogicalChannel Attribute="ColorAdd_G">
                  <ChannelFunction Name="Green 1" Attribute="ColorAdd_G" DMXFrom="0/1" Default="0/1"/>
                </LogicalChannel>
              </DMXChannel>
              <DMXChannel Geometry="Beam" DMXBreak="1" Offset="4">
                <LogicalChannel Attribute="ColorAdd_B">
                  <ChannelFunction Name="Blue 1" Attribute="ColorAdd_B" DMXFrom="0/1" Default="0/1"/>
                </LogicalChannel>
              </DMXChannel>
            </DMXChannels>
          </DMXMode>
        </DMXModes>
      </FixtureType>
    </GDTF>
    """

    private func loadTestFixture() throws -> GDTF {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftgdtf-geometry-\(UUID().uuidString).xml")
        try Self.description.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        return try loadGDTFDescription(url: url)
    }

    func testModelsParsed() throws {
        let fixture = try loadTestFixture().fixtureType
        XCTAssertEqual(fixture.models.count, 1)
        let model = try XCTUnwrap(fixture.models.first)
        XCTAssertEqual(model.name, "Beam")
        XCTAssertEqual(model.file, "BeamFile")
        XCTAssertEqual(model.primitiveType, .cube)
        XCTAssertEqual(model.length, 0.1, accuracy: 1e-6)
        XCTAssertEqual(model.width, 0.2, accuracy: 1e-6)
        XCTAssertEqual(model.height, 0.3, accuracy: 1e-6)
    }

    func testGeometryTreeParsed() throws {
        let fixture = try loadTestFixture().fixtureType

        // Top level: "Body" geometry and a "Beam".
        XCTAssertEqual(fixture.geometries.count, 2)

        let body = try XCTUnwrap(fixture.geometries.first { $0.name == "Body" })
        XCTAssertEqual(body.kind, .geometry)
        XCTAssertEqual(body.children.count, 3)
        XCTAssertTrue(body.children.allSatisfy { $0.kind == .reference })

        let beam = try XCTUnwrap(fixture.geometries.first { $0.name == "Beam" })
        XCTAssertEqual(beam.kind, .beam)
        XCTAssertEqual(beam.model, "Beam")
        let beamData = try XCTUnwrap(beam.beam)
        XCTAssertEqual(beamData.beamType, .spot)
        XCTAssertEqual(try XCTUnwrap(beamData.beamAngle), 10, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(beamData.fieldAngle), 20, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(beamData.colorTemperature), 6500, accuracy: 1e-6)
    }

    func testPositionMatrixRead() throws {
        let fixture = try loadTestFixture().fixtureType
        let body = try XCTUnwrap(fixture.geometries.first { $0.name == "Body" })
        let pixel1 = try XCTUnwrap(body.children.first { $0.name == "Pixel1" })
        // Translation component (row 0, col 3) of Pixel1's position.
        XCTAssertEqual(pixel1.position.matrix[0][3], 0.5, accuracy: 1e-6)
    }

    func testReferenceBreaksParsed() throws {
        let fixture = try loadTestFixture().fixtureType
        let body = try XCTUnwrap(fixture.geometries.first { $0.name == "Body" })
        let pixel2 = try XCTUnwrap(body.children.first { $0.name == "Pixel2" })
        XCTAssertEqual(pixel2.reference?.geometry, "Beam")
        XCTAssertEqual(pixel2.reference?.breaks.count, 1)
        XCTAssertEqual(pixel2.reference?.breaks.first?.dmxBreak, 1)
        XCTAssertEqual(pixel2.reference?.breaks.first?.dmxOffset, 5)
    }

    func testExpandedToThreeCells() throws {
        let fixture = try loadTestFixture().fixtureType
        let mode = try XCTUnwrap(fixture.getDMXMode(mode: "Default"))

        let cells = try XCTUnwrap(mode.cells)
        XCTAssertEqual(cells.count, 3)
        XCTAssertEqual(cells.map(\.name), ["Pixel1", "Pixel2", "Pixel3"])

        // Each cell instantiates the 4 template channels.
        XCTAssertTrue(cells.allSatisfy { $0.channels.count == 4 })
    }

    func testPerCellOffsetsShifted() throws {
        let fixture = try loadTestFixture().fixtureType
        let mode = try XCTUnwrap(fixture.getDMXMode(mode: "Default"))
        let cells = try XCTUnwrap(mode.cells)

        // Break offsets 1, 5, 9 -> channel offsets shift by (offset - 1).
        XCTAssertEqual(cells[0].channels.map { $0.offset.first }, [1, 2, 3, 4])
        XCTAssertEqual(cells[1].channels.map { $0.offset.first }, [5, 6, 7, 8])
        XCTAssertEqual(cells[2].channels.map { $0.offset.first }, [9, 10, 11, 12])
    }

    func testFlattenedChannelsAndFootprint() throws {
        let fixture = try loadTestFixture().fixtureType
        let mode = try XCTUnwrap(fixture.getDMXMode(mode: "Default"))

        // 3 cells x 4 channels each; the literal template channels are not double-counted.
        XCTAssertEqual(mode.flattenedChannels?.count, 12)
        XCTAssertEqual(mode.allChannels.count, 12)
        XCTAssertEqual(mode.dmxFootprint, 12)
    }

    func testCellPositionsAvailable() throws {
        let fixture = try loadTestFixture().fixtureType
        let mode = try XCTUnwrap(fixture.getDMXMode(mode: "Default"))
        let cells = try XCTUnwrap(mode.cells)
        // Spatial layout: each cell carries its own transform.
        XCTAssertEqual(cells[0].position.matrix[0][3], 0.5, accuracy: 1e-6)
        XCTAssertEqual(cells[1].position.matrix[0][3], 1.5, accuracy: 1e-6)
        XCTAssertEqual(cells[2].position.matrix[0][3], 2.5, accuracy: 1e-6)
    }
}
