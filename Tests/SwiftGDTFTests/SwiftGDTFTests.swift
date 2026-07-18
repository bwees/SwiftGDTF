import Testing
import Foundation

let env = ProcessInfo.processInfo.environment

// These fixtures have known issues with their profiles
// and should be ignored in reguards to validating this library
// as they do not follow proper spec

let FIXTURE_BLACKLIST = [
    "S380H IP_Terbly_D3950060-1900-4193-97A5-24FEDFD38E73.gdtf",
    "S380H_Terbly_EDB6335A-E04D-40AC-871F-234419A60D6B.gdtf",
    "TMH S-200_Eurolite_CC902559-910C-46E3-92FF-5D4F460C12B3.gdtf",
    "Gemini 1x1 Hard_Litepanels_C06B8887-F9CD-49B0-9A05-F735D19B228B.gdtf",
    "Gemini 1x1 Soft_Litepanels_2319CD84-61C3-4AE6-830C-E5284BF9A4AB.gdtf",
    "Moonlight Kugel 60cm_Boehlke Beleuchtung_8B5119CF-4C53-4BBE-8CA9-657C67729691.gdtf",
    "Gemini 2x1 Soft_Litepanels_E5EB68B1-680A-48AA-A0F9-F26DC612985C.gdtf",
    "Gemini 2x1 Hard_Litepanels_6D5063F5-9B6A-42D2-8D8C-21BCF5B06BF8.gdtf",
    "LED TMH-S200_Eurolite_9D17D5E9-3776-4315-8104-14BE1BDE8AA4.gdtf",

    // Fine Art: unescaped '<' in XML attribute values (invalid XML per XML 1.0 §3.1); two also
    // contain invalid UTF-8. Not parser-fixable — the payload is malformed.
    "FINE 1000L BSWF_Fine Art_1EC6BB99-CCFF-49B7-9FE4-0A6FA5865CE8.gdtf",
    "FINE 1000L PERF_Fine Art_69F70DA9-D00E-46DD-A47C-84911900CC0B.gdtf",
    "FINE 1000ZL PERF_Fine Art_FAB10C13-C86F-4DD1-9444-F12B75234C2D.gdtf",
    "FINE 1200LH PERF_Fine Art_271FEDD5-C32F-4044-AA13-3DB060C3EF18.gdtf",
    "FINE 1400JD PERF_Fine Art_B18BE566-4403-4BE8-AD27-507EFA46A784.gdtf",
    "FINE 1400LH BSWF_Fine Art_E4974826-7491-4917-851D-430EF8EC9264.gdtf",
    "FINE 1400ZL PERF_Fine Art_6066C2B1-D575-4546-988F-6C925871A802.gdtf",
    "FINE 1700LB BSWF IP_Fine Art_AA82281D-68FC-45C6-86E1-7829A0B0A239.gdtf",
    "FINE 1700LH BSWF_Fine Art_D5780B95-A1C0-4503-8382-CCFC926AB126.gdtf",
    "FINE 1800 BEAM WASH_Fine Art_56B9E714-6BBF-4FEF-A7A6-5BF62876831D.gdtf",
    "FINE 1800 BWF_Fine Art_7E54622F-6642-4E3C-A0DF-36A0121F1C07.gdtf",
    "FINE 1800 PERF_Fine Art_0D849F65-E23B-44B7-999E-8883A8B365A6.gdtf",
    "FINE 2000L BSWF_Fine Art_BF1822BA-0F2C-4C6F-9974-5FB5BA847D81.gdtf",
    "FINE 4025 PIXIE_Fine Art_BF579FB7-EF02-448A-9692-28EF17625C12.gdtf",
    "Fine 420L Perf_Fine Art_9069C7CE-7456-47C7-82D8-3ECAD7702111.gdtf",
    "FINE 420LH Spot_Fine Art_15E6810E-ADF4-4601-A3E0-BBEF7C206632.gdtf",
    "FINE 440 BSW ENHA_Fine Art_3DFE3E8B-F1EC-4CF6-922D-DBE2F5D17A1E.gdtf",
    "FINE 470 BSW OD_Fine Art_A42E9293-253D-45A2-B832-BEDE785A81CC.gdtf",
    "FINE 550 BSW PLUS_Fine Art_646DFF1A-B518-4884-B7AE-E3542F69E529.gdtf",
    "FINE 600L BWSF_Fine Art_44DED7CD-D8F9-416E-9C9D-9234C82B30A8.gdtf",
    "Fine Xtreme 330_Fine Art_C8CE2955-3B27-4153-A63F-97F7F78312A1.gdtf",

    // Event Lighting: FixtureType is missing the XSD-required Description attribute
    "LM250_Event Lighting_C399DE59-076B-40B5-80A4-CF91ECB07E50.gdtf",
]

// MARK: - Credentials

struct Credentials {
    let username: String
    let password: String
}

// MARK: - Fixture

struct Fixture: Decodable {
    var uuid: String?
    var rid: Int
    var fixture: String
    var manufacturer: String
    var creationDate: Int

    func filename() -> String {
        return "\(self.fixture)_\(self.manufacturer)_\(self.uuid ?? "unknown").gdtf".replacingOccurrences(of: "/", with: "_")
    }
}

// MARK: - Session Manager

actor SessionManager {
    private let credentials: Credentials
    private var isLoggedIn = false

    init(credentials: Credentials) {
        self.credentials = credentials
    }

    func login() async throws {
        guard !isLoggedIn else { return }

        let loginURL = URL(string: "https://gdtf-share.com/apis/public/login.php")!
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "user": credentials.username,
            "password": credentials.password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "LoginError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        isLoggedIn = true
    }

    func invalidateSession() {
        isLoggedIn = false
    }
}

// MARK: - GDTF Downloader

class GDTFDownloader {
    private let sessionManager: SessionManager
    private let downloadDirectory: URL
    private var fixtures: [Fixture] = []

    init(credentials: Credentials, downloadDirectory: URL) {
        self.sessionManager = SessionManager(credentials: credentials)
        self.downloadDirectory = downloadDirectory
    }

    func start() async throws {
        try await sessionManager.login()
        try await fetchFixtures()
        try await downloadFixtures()
    }

    private func fetchFixtures() async throws {
        let listURL = URL(string: "https://gdtf-share.com/apis/public/getList.php")!
        var request = URLRequest(url: listURL)
        request.httpMethod = "GET"

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpMaximumConnectionsPerHost = 200
        
        let session = URLSession(configuration: configuration)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "FetchFixturesError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        struct ListResponse: Decodable {
            let result: Bool
            let list: [Fixture]
        }

        let decoder = JSONDecoder()
        let responseObj = try decoder.decode(ListResponse.self, from: data)

        // Group by UUID and pick the newest creationDate
        var latestByUUID: [String: Fixture] = [:]

        for fixture in responseObj.list {
            guard let uuid = fixture.uuid else { continue }   // skip entries with no uuid (can't be downloaded)
            if let existing = latestByUUID[uuid] {
                if fixture.creationDate > existing.creationDate {
                    latestByUUID[uuid] = fixture
                }
            } else {
                latestByUUID[uuid] = fixture
            }
        }

        self.fixtures = Array(latestByUUID.values.sorted(by: { $0.rid < $1.rid }))
    }

    private func downloadFixtures() async throws {
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true, attributes: nil)
        print("downloading to \(downloadDirectory)")
        var downloadedCount = 0

        await withTaskGroup(of: Void.self) { group in
            func addTask(_ fixture: Fixture) {
                group.addTask {
                    do {
                        try await self.downloadFixture(fixture)
                        downloadedCount += 1
                    } catch {
                        print("Failed to download fixture \(fixture.uuid): \(error)")
                    }
                }
            }
            var fixtures = fixtures.makeIterator()
            var i = 0
            while let fixture = fixtures.next(), i < 20 {
                i += 1
                addTask(fixture)
            }
            for await _ in group {
                if let fixture = fixtures.next() {
                    addTask(fixture)
                } else {
                    break
                }
            }
        }
    }

    private func downloadFixture(_ fixture: Fixture) async throws {
        let destinationURL = downloadDirectory.appendingPathComponent(fixture.filename())

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            // already downloaded, skip
            return
        }

        let downloadURL = URL(string: "https://gdtf-share.com/apis/public/downloadFile.php?rid=\(fixture.rid)")!
        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        let session = URLSession(configuration: configuration)

        let (tempURL, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: try Data(contentsOf: tempURL), encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "DownloadError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        print("Downloaded \(fixture.filename())")
    }
}

import SwiftGDTF

// MARK: - GDTF Validator

class GDTFValidator {
    private let fixturesDirectory: URL
    private var successes: [String] = []
    private var failures: [(String, String)] = []

    init(fixturesDirectory: URL) {
        self.fixturesDirectory = fixturesDirectory
    }

    func validateAll() async throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: fixturesDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let gdtfFiles = fileURLs.filter { $0.pathExtension.lowercased() == "gdtf" }

        print("Found \(gdtfFiles.count) GDTF files to validate.\n")

        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            for fileURL in gdtfFiles {
                let filename = fileURL.lastPathComponent

                if (FIXTURE_BLACKLIST.contains(filename)) {
                    print("Skipping " + filename)
                    continue
                }
                
                group.addTask {
                    do {
                        _ = try loadGDTF(url: fileURL)
                        return (filename, .success(()))
                    } catch {
                        return (filename, .failure(error))
                    }
                }
            }

            for await (filename, result) in group {
                switch result {
                case .success:
                    successes.append(filename)
                case .failure(let error):
                    failures.append((filename, "\(error)"))
                    print("❌ Failed to parse: \(filename)\n   Error: \(error)")
                }
            }
        }

        // Summary
        print("\nValidation Summary:")
        print("✅ Successes: \(successes.count)")
        print("❌ Failures: \(failures.count)")

        
        if !failures.isEmpty {
            let errorGrouped = Dictionary.init(zip(failures.map(\.1), repeatElement(1, count: .max)), uniquingKeysWith: +).sorted(by: { $0.value > $1.value})
            
            print("Failure Reasons")
            for error in errorGrouped {
                print("\(error.key): \(error.value)")
            }
            
            print("\nFailed Files:")
            for (filename, errorDescription) in failures {
                print(" - \(filename): \(errorDescription)")
            }

            // fail the test
            throw NSError(domain: "GDTFValidationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "GDTF validation failed for \(failures.count) files."])
        }
    }
}

// MARK: - Main Execution

@Suite
struct GDTFShare {
    let downloadFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".cache")
        .appendingPathComponent("Fixtures")

    let credentials = Credentials(username: "SwiftGDTF", password: env["GDTF_SHARE_PASSWORD"]!)
    
    @Test func parseAllFixtures() async throws {
        
        let downloader = GDTFDownloader(credentials: credentials, downloadDirectory: downloadFolder)
        try await downloader.start()

        try await GDTFValidator(fixturesDirectory: downloadFolder).validateAll()
    }
    
    // Useful for debugging
//    @Test func testIndividual() async throws {
//        _ = try loadGDTF(url: downloadFolder.appending(component: "Reflect Color Studio_Brother Brother and Sons_379FE751-C45E-4734-A6C8-843A2BF28F42.gdtf"))
//    }
}
