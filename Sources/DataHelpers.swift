//
//  DataHelpers.swift
//  
//
//  Created by Brandon Wees on 7/6/24.
//

import Foundation

extension FixtureType {
    public func getDMXMode(mode: String) -> DMXMode? {
        return self.dmxModes.first(where: {$0.name == mode})
    }
}

extension DMXMode {
    public var dmxFootprint: Int {
        // Multi-cell modes: the footprint is the highest DMX offset used across
        // all expanded per-cell channels.
        if let flattenedChannels {
            return flattenedChannels.flatMap { $0.offset }.max() ?? 0
        }

        // Legacy behavior for modes without geometry references.
        var total = 0

        for channel in self.channels {
            total += channel.initialFunction?.dmxDefault.byteCount ?? 1
        }

        return total
    }

}

extension DMXChannel {
    public var byteCount: Int {
        return self.initialFunction?.dmxDefault.byteCount ?? 1
    }
}
