import XCTest
@testable import SwiftGDTF

/// Tests covering spec-legal inputs
final class SpecLegalInputsTests: XCTestCase {

    // MARK: DMXValue (dmxtype: "value/byteCount" with optional trailing "s")

    func testDMXValueBasic() {
        let v = DMXValue(from: "255/1")
        XCTAssertEqual(v.value, 255)
        XCTAssertEqual(v.byteCount, 1)
        XCTAssertEqual(v.bytes, [255])
    }

    func testDMXValueSixteenBit() {
        let v = DMXValue(from: "65535/2")
        XCTAssertEqual(v.byteCount, 2)
        XCTAssertEqual(v.bytes, [255, 255])
    }

    func testDMXValueByteShiftingSuffix() {
        // "255/1s" is the byte-shifting form; the "s" must not corrupt byteCount.
        let v = DMXValue(from: "255/1s")
        XCTAssertEqual(v.value, 255)
        XCTAssertEqual(v.byteCount, 1)
        XCTAssertEqual(v.bytes, [255])
    }

    func testDMXValueMissingByteCountDoesNotCrash() {
        let v = DMXValue(from: "5")
        XCTAssertEqual(v.value, 5)
        XCTAssertEqual(v.byteCount, 1)
    }

    // MARK: ColorCIE (vector3type: "x,y,Y"; "None" is legal)

    func testColorCIEFull() {
        let c = ColorCIE(from: "0.3127,0.3290,100")
        XCTAssertEqual(c.x, 0.3127, accuracy: 1e-6)
        XCTAssertEqual(c.y, 0.3290, accuracy: 1e-6)
        XCTAssertEqual(c.Y, 1.0, accuracy: 1e-6)   // Y > 1 is normalized /100
    }

    func testColorCIETwoComponents() {
        let c = ColorCIE(from: "0.5,0.5")
        XCTAssertEqual(c.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(c.Y, 1.0, accuracy: 1e-6)
    }

    func testColorCIENoneFallsBackToWhite() {
        let c = ColorCIE(from: "None")
        XCTAssertEqual(c.x, 0.3127, accuracy: 1e-6)
        XCTAssertEqual(c.y, 0.3290, accuracy: 1e-6)
    }

    func testColorCIEWhitespaceTolerated() {
        let c = ColorCIE(from: "0.5, 0.5, 50")
        XCTAssertEqual(c.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(c.y, 0.5, accuracy: 1e-6)
    }

    // MARK: Rotation (rotationtype: "{..}{..}{..}"; "None" is legal)

    func testRotationMatrix() {
        let r = Rotation(from: "{1,0,0}{0,1,0}{0,0,1}")
        XCTAssertEqual(r.matrix, [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    }

    func testRotationNoneIsIdentity() {
        let r = Rotation(from: "None")
        XCTAssertEqual(r.matrix, [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    }

    func testRotationMalformedDoesNotCrash() {
        let r = Rotation(from: "{1,2}")
        XCTAssertEqual(r.matrix, [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    }
}
