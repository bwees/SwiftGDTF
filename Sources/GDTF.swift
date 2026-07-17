//
//  GDTF.swift
//  
//
//  Created by Brandon Wees on 7/4/24.
//

import Foundation
import SWXMLHash

/// This is used to show a String that maps to a node that we cannot currently process
/// (usually because it results in a recursive type)
public typealias Node = String

public struct GDTF: Codable {
    public var dataVersion: String
    public var fixtureType: FixtureType
}

public struct FixtureType: Codable {
    public var name: String
    public var shortName: String
    public var longName: String
    public var manufacturer: String
    public var description: String
    public var fixtureTypeID: UUID
    public var refFT: String?
    public var thumbnail: FileResource?
    
    public var attributeDefinitions: AttributeDefinitions
    public var wheels: [Wheel]
    public var physicalDescriptions: PhysicalDescriptions?
    public var dmxModes: [DMXMode]
}

// this is an identical copy to FixtureType but only includes top level attributes
public struct FixtureInfo: Codable {
    public var name: String
    public var shortName: String
    public var longName: String
    public var manufacturer: String
    public var description: String
    public var fixtureTypeID: String
    public var refFT: String?
    public var thumbnail: FileResource?
}

///
/// AttributeDefinitions Schema
///

public struct AttributeDefinitions: Codable {
    public var activationGroups: [ActivationGroup]?
    public var featureGroups: [FeatureGroup]
    public var attributes: [FixtureAttribute]
}

public struct ActivationGroup: Codable {
    public var name: String
}

public struct FeatureGroup: Codable {
    public var name: String
    public var pretty: String
    
    public var features: [Feature]
}

public struct Feature: Codable {
    public var name: String
}

public struct FixtureAttribute: Codable {
    public var name: String
    public var type: AttributeType
    public var pretty: String
    public var activationGroup: ActivationGroup?
    public var feature: Feature?
    
    // This is a node but results in recursive type
    public var mainAttribute: Node?
    
    public var physicalUnit: PhysicalUnit = .none
    public var color: ColorCIE?
    
    public var subPhysicalUnits: [SubPhysicalUnit] = []
}

public struct SubPhysicalUnit: Codable {
    public var type: SubPhysicalType?
    public var physicalUnit: PhysicalUnit = .none
    public var physicalFrom: Double = 0
    public var physicalTo: Double = 1
}

///
/// Wheels Schema
///

public struct Wheel: Codable {
    public var name: String
    public var slots: [Slot]
}

public struct Slot: Codable {
    public var name: String
    public var color: ColorCIE
    public var filter: Filter?
    public var mediaFileName: FileResource?
    public var slotIndex: Int
    
    public var facets: [PrismFacet]
    public var animationSystem: AnimationSystem?
}

public struct PrismFacet: Codable {
    public var color: ColorCIE
    public var rotation: Rotation
}

public struct AnimationSystem: Codable {
    public var p1: [Double]
    public var p2: [Double]
    public var p3: [Double]
    
    public var radius: Double
}

///
/// Physical Description Schema
///

public struct PhysicalDescriptions: Codable {
    public var emitters: [Emitter]
    public var filters: [Filter]
    public var colorSpace: ColorSpace?
    public var additionalColorSpaces: [ColorSpace]
    public var dmxProfiles: [DMXProfile]
    public var properties: Properties?
}

public struct Emitter: Codable {
    public var name: String
    public var color: ColorCIE?
    public var dominantWavelength: Double?
    public var diodePart: String?    
}

public struct GDTFMeasurement: Codable {
    public var physical: Double
    public var luminousIntensity: Double?
    public var transmission: Double?
    public var interpolationTo: InterpolationTo
    
    public var measurements: [MeasurementPoint]
}

public struct MeasurementPoint: Codable {
    public var wavelength: Double
    public var energy: Double
}

public struct Filter: Codable {
    public var name: String
    public var color: ColorCIE
    
    public var measurements: [GDTFMeasurement]
}

public struct ColorSpace: Codable {
    public var name: String
    public var mode: ColorSpaceMode
    
    // Only used when mode is .custom
    public var red: ColorCIE?
    public var green: ColorCIE?
    public var blue: ColorCIE?
    public var whitePoint: ColorCIE?
}

public struct DMXProfile: Codable {
    public var name: String
    public var points: [Point]
}

public struct Point: Codable {
    public var dmxPercentage: Double
    public var cfc0: Double
    public var cfc1: Double
    public var cfc2: Double
    public var cfc3: Double
}

public struct Properties: Codable {
    public var operatingTemp: OperatingTemp
    public var weight: Double
    public var legHeight: Double
}

public struct OperatingTemp: Codable {
    public var low: Double
    public var high: Double
}

///
/// DMX Mode Schema
///

public struct DMXMode: Codable {
    public var name: String
    public var description: String
    
    public var channels: [DMXChannel]
    public var relations: [Relation]
    public var macros: [Macro]
}

public struct DMXChannel: Codable {
    public var name: String?
    public var dmxBreak: Int
    public var offset: [Int]
    public var initialFunction: ChannelFunction?
    public var highlight: DMXValue?
    
    public var logicalChannels: [LogicalChannel]
    public var geometry: String
}

public struct LogicalChannel: Codable {
    public var attribute: FixtureAttribute
    public var snap: Snap
    public var master: Master
    public var mibFade: Double
    public var dmxChangeTimeLimit: Double
    
    public var channelFunctions: [ChannelFunction]
}

public struct ChannelFunction: Codable {
    public var name: String
    public var attribute: FixtureAttribute?
    public var originalAttribute: String
    public var dmxFrom: DMXValue
    public var dmxDefault: DMXValue
    public var physicalFrom: Double
    public var physicalTo: Double
    public var realFade: Double
    public var realAcceleration: Double
    
    public var wheel: Wheel?
    public var emitter: Emitter?
    public var filter: Filter?
    public var colorSpace: ColorSpace?
    
    // modeMaster is a node but can have multiple types
    // wil revisit this later
    public var modeMaster: Node?
    public var modeFrom: DMXValue?
    public var modeTo: DMXValue?
    
    public var dmxProfile: DMXProfile?
    
    public var minimum: Double
    public var maximum: Double
    public var customName: String?
    
    public var channelSets: [ChannelSet]
    public var subChannelSets: [SubChannelSet]
}

public struct ChannelSet: Codable {
    public var name: String
    public var dmxFrom: DMXValue
    public var physicalFrom: Double
    public var physicalTo: Double
    public var wheelSlotIndex: Int?
}

public struct SubChannelSet: Codable {
    public var name: String
    public var physicalFrom: Double
    public var physicalTo: Double
    public var subPhysicalUnit: SubPhysicalUnit?
    public var wheelSlotIndex: Int?
    public var dmxProfile: DMXProfile?
}

public struct Relation: Codable {
    public var name: String
    public var master: DMXChannel
    public var follower: ChannelFunction
    public var type: RelationType
}

public struct Macro: Codable {
    public var name: String
    public var channelFunction: ChannelFunction?
    
    public var steps: [MacroStep]
}

public struct MacroStep: Codable {
    public var duration: Double
    public var values: [MacroValue]
}

public struct MacroValue: Codable {
    public var value: DMXValue
    public var dmxChannel: DMXChannel
}

// see Annex A: https://github.com/mvrdevelopment/spec/blob/main/gdtf-spec.md#annex-a-normative-attribute-definitions
public enum AttributeType: Hashable, Codable {
    case dimmer
    case pan
    case tilt
    case panRotate
    case tiltRotate
    case positionEffect
    case positionEffectRate
    case positionEffectFade
    case xYZ_X
    case xYZ_Y
    case xYZ_Z
    case rot_X
    case rot_Y
    case rot_Z
    case scale_X
    case scale_Y
    case scale_Z
    case scale_XYZ
    case gobo(n: Int)
    case goboSelectSpin(n: Int)
    case goboSelectShake(n: Int)
    case goboSelectEffects(n: Int)
    case goboWheelIndex(n: Int)
    case goboWheelSpin(n: Int)
    case goboWheelShake(n: Int)
    case goboWheelRandom(n: Int)
    case goboWheelAudio(n: Int)
    case goboPos(n: Int)
    case goboPosRotate(n: Int)
    case goboPosShake(n: Int)
    case animationWheel(n: Int)
    case animationWheelAudio(n: Int)
    case animationWheelMacro(n: Int)
    case animationWheelRandom(n: Int)
    case animationWheelSelectEffects(n: Int)
    case animationWheelSelectShake(n: Int)
    case animationWheelSelectSpin(n: Int)
    case animationWheelPos(n: Int)
    case animationWheelPosRotate(n: Int)
    case animationWheelPosShake(n: Int)
    case animationSystem(n: Int)
    case animationSystemRamp(n: Int)
    case animationSystemShake(n: Int)
    case animationSystemAudio(n: Int)
    case animationSystemRandom(n: Int)
    case animationSystemPos(n: Int)
    case animationSystemPosRotate(n: Int)
    case animationSystemPosShake(n: Int)
    case animationSystemPosRandom(n: Int)
    case animationSystemPosAudio(n: Int)
    case animationSystemMacro(n: Int)
    case mediaFolder(n: Int)
    case mediaContent(n: Int)
    case modelFolder(n: Int)
    case modelContent(n: Int)
    case playMode
    case playBegin
    case playEnd
    case playSpeed
    case colorEffects(n: Int)
    case color(n: Int)
    case colorWheelIndex(n: Int)
    case colorWheelSpin(n: Int)
    case colorWheelRandom(n: Int)
    case colorWheelAudio(n: Int)
    case colorAdd_R
    case colorAdd_G
    case colorAdd_B
    case colorAdd_C
    case colorAdd_M
    case colorAdd_Y
    case colorAdd_RY
    case colorAdd_GY
    case colorAdd_GC
    case colorAdd_BC
    case colorAdd_BM
    case colorAdd_RM
    case colorAdd_W
    case colorAdd_WW
    case colorAdd_CW
    case colorAdd_UV
    case colorSub_R
    case colorSub_G
    case colorSub_B
    case colorSub_C
    case colorSub_M
    case colorSub_Y
    case colorMacro(n: Int)
    case colorMacroRate(n: Int)
    case cTO
    case cTC
    case cTB
    case tint
    case hSB_Hue
    case hSB_Saturation
    case hSB_Brightness
    case hSB_Quality
    case cIE_X
    case cIE_Y
    case cIE_Brightness
    case colorRGB_Red
    case colorRGB_Green
    case colorRGB_Blue
    case colorRGB_Cyan
    case colorRGB_Magenta
    case colorRGB_Yellow
    case colorRGB_Quality
    case videoBoost_R
    case videoBoost_G
    case videoBoost_B
    case videoHueShift
    case videoSaturation
    case videoBrightness
    case videoContrast
    case videoKeyColor_R
    case videoKeyColor_G
    case videoKeyColor_B
    case videoKeyIntensity
    case videoKeyTolerance
    case strobeDuration
    case strobeRate
    case strobeFrequency
    case strobeModeShutter
    case strobeModeStrobe
    case strobeModePulse
    case strobeModePulseOpen
    case strobeModePulseClose
    case strobeModeRandom
    case strobeModeRandomPulse
    case strobeModeRandomPulseOpen
    case strobeModeRandomPulseClose
    case strobeModeEffect
    case shutter(n: Int)
    case shutterStrobe(n: Int)
    case shutterStrobePulse(n: Int)
    case shutterStrobePulseClose(n: Int)
    case shutterStrobePulseOpen(n: Int)
    case shutterStrobeRandom(n: Int)
    case shutterStrobeRandomPulse(n: Int)
    case shutterStrobeRandomPulseClose(n: Int)
    case shutterStrobeRandomPulseOpen(n: Int)
    case shutterStrobeEffect(n: Int)
    case iris
    case irisStrobe
    case irisStrobeRandom
    case irisPulseClose
    case irisPulseOpen
    case irisRandomPulseClose
    case irisRandomPulseOpen
    case frost(n: Int)
    case frostPulseOpen(n: Int)
    case frostPulseClose(n: Int)
    case frostRamp(n: Int)
    case prism(n: Int)
    case prismSelectSpin(n: Int)
    case prismMacro(n: Int)
    case prismPos(n: Int)
    case prismPosRotate(n: Int)
    case effects(n: Int)
    case effectsRate(n: Int)
    case effectsFade(n: Int)
    case effectsAdjust(n: Int, m: Int)
    case effectsPos(n: Int)
    case effectsPosRotate(n: Int)
    case effectsSync
    case beamShaper
    case beamShaperMacro
    case beamShaperPos
    case beamShaperPosRotate
    case zoom
    case zoomModeSpot
    case zoomModeBeam
    case digitalZoom
    case focus(n: Int)
    case focusAdjust(n: Int)
    case focusDistance(n: Int)
    case control(n: Int)
    case dimmerMode
    case dimmerCurve
    case blackoutMode
    case lEDFrequency
    case lEDZoneMode
    case pixelMode
    case panMode
    case tiltMode
    case panTiltMode
    case positionModes
    case goboWheelMode(n: Int)
    case goboWheelShortcutMode
    case animationWheelMode(n: Int)
    case animationWheelShortcutMode
    case colorMode(n: Int)
    case colorWheelShortcutMode
    case cyanMode
    case magentaMode
    case yellowMode
    case colorMixMode
    case chromaticMode
    case colorCalibrationMode
    case colorConsistency
    case colorControl
    case colorModelMode
    case colorSettingsReset
    case colorUniformity
    case cRIMode
    case customColor
    case uVStability
    case wavelengthCorrection
    case whiteCount
    case strobeMode
    case zoomMode
    case focusMode
    case irisMode
    case fanMode(n: Int)
    case followSpotMode
    case beamEffectIndexRotateMode
    case intensityMSpeed
    case positionMSpeed
    case colorMixMSpeed
    case colorWheelSelectMSpeed
    case goboWheelMSpeed(n: Int)
    case irisMSpeed
    case prismMSpeed(n: Int)
    case focusMSpeed
    case frostMSpeed(n: Int)
    case zoomMSpeed
    case frameMSpeed
    case globalMSpeed
    case reflectorAdjust
    case fixtureGlobalReset
    case dimmerReset
    case shutterReset
    case beamReset
    case colorMixReset
    case colorWheelReset
    case focusReset
    case frameReset
    case goboWheelReset
    case intensityReset
    case irisReset
    case positionReset
    case panReset
    case tiltReset
    case zoomReset
    case cTBReset
    case cTOReset
    case cTCReset
    case animationSystemReset
    case fixtureCalibrationReset
    case function
    case lampControl
    case displayIntensity
    case dMXInput
    case noFeature
    case blower(n: Int)
    case fan(n: Int)
    case fog(n: Int)
    case haze(n: Int)
    case lampPowerMode
    case fans
    case bladeA(n: Int)
    case bladeB(n: Int)
    case bladeRot(n: Int)
    case shaperRot
    case shaperMacros
    case shaperMacrosSpeed
    case bladeSoftA(n: Int)
    case bladeSoftB(n: Int)
    case keyStoneA(n: Int)
    case keyStoneB(n: Int)
    case video
    case videoEffectType(n: Int)
    case videoEffectParameter(n: Int, m: Int)
    case videoCamera(n: Int)
    case videoSoundVolume(n: Int)
    case videoBlendMode
    case inputSource
    case fieldOfView
    case custom
}

