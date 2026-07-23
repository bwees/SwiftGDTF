//
//  GDTFShare.swift
//  SwiftGDTF
//
//  Created by Brandon Wees on 12/21/24.
//

import Foundation

public struct GDTFShare {
    
    public struct LoginResponse: Codable, Sendable {
        // Was login successful
        public let result: Bool

        // Possible error message
        public let error: String?

        // Fun joke from the site (absent on failed logins)
        public let notice: String?

    }
    
    public struct DMXMode: Codable, Sendable {
        public let name: String
        public let dmxFootprint: Int

        private enum CodingKeys : String, CodingKey {
            case name, dmxFootprint = "dmxfootprint"
        }
    }
    
    public struct FixtureEntry: Codable, Sendable {
        public let revisionID: Int
        public let name: String
        public let manufacturer: String
        public let revisionName: String
        public let creationDate: Int
        public let lastModified: Int
        public let uploader: String
        
        private let ratingString: String
        public var rating: Double? { Double(ratingString) }

        public let version: String
        public let creator: String
        
        // Does not change across revisions (rarely null in the Share list)
        public let uuid: UUID?
        
        public let filesize: Int
        public let modes: [DMXMode]
        
        private enum CodingKeys : String, CodingKey {
            case revisionID = "rid"
            case name = "fixture"
            case manufacturer
            case revisionName = "revision"
            case creationDate
            case lastModified
            case uploader
            case ratingString = "rating"
            case version
            case creator
            case uuid
            case filesize
            case modes
        }
    }
    
    public struct ListResponse: Codable, Sendable {
        // was the request for data successful
        public let result: Bool
        
        // Possible error message
        public let error: String?
        
        public let list: [FixtureEntry]?
    }
    
    // Returns the sessionID which is the PHPSESSID cookie
    public static func login(username: String, password: String) async throws -> LoginResponse {
        let url = URL(string: "https://gdtf-share.com/apis/public/login.php")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "user" : username,
            "password" : password
        ])
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.shared.data(for: request)

        // Parse the JSON data
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }
    
    public static func getList() async throws -> ListResponse {
        let url = URL(string: "https://gdtf-share.com/apis/public/getList.php")!
                
        let (data, _) = try await URLSession.shared.data(from: url)

        // Parse the JSON data
        return try JSONDecoder().decode(ListResponse.self, from: data)
    }
    
    public static func download(revisionID: Int) async throws -> Data? {
        let url = URL(string: "https://gdtf-share.com/apis/public/downloadFile.php?rid=\(revisionID)")!
                
        let (data, response) = try await URLSession.shared.data(from: url)
        
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                return data
            } else {
                return nil
            }
        }

        return nil
    }
}

