import Foundation
import Testing
@testable import GPSTest

/// Expected values from a Python reference of the same propagator and from the sgp4 library (SGP4/SDP4).
struct SatelliteTests {
    static let epoch = Date(timeIntervalSince1970: 1_791_547_200) // 2026-10-09T12:00:00Z

    static let gps = OrbitalElements(name: "GPS BIIR-2  (PRN 13)", noradID: 24876, epoch: epoch, meanMotion: 2.00562,
                                     eccentricity: 0.012, inclination: 55.2, rightAscension: 120, argumentOfPerigee: 40,
                                     meanAnomaly: 200)

    @Test func inertialPositionMatchesReference() {
        let r = Orbit.position(Self.gps, at: Self.epoch)
        #expect(abs(r.x - 18252.1288) < 0.01)
        #expect(abs(r.y - -5186.9051) < 0.01)
        #expect(abs(r.z - -19011.5258) < 0.01)
        let later = Orbit.position(Self.gps, at: Self.epoch.addingTimeInterval(1.5 * 86400))
        #expect(abs(later.x - 17965.5247) < 0.01)
        #expect(abs(later.y - -3944.4433) < 0.01)
        #expect(abs(later.z - -19566.255) < 0.01)
    }

    @Test func siderealTime() {
        #expect(abs(Orbit.gmst(Self.epoch) - 3.4578566765097953) < 1e-9)
    }

    @Test func lookAnglesMatchSGP4() {
        let date = Self.epoch.addingTimeInterval(7 * 3600)
        let p = Orbit.position(of: Self.gps, at: date, latitude: 51.5, longitude: -0.12)
        // Same algorithm in Python:
        #expect(abs(p.azimuth - 312.021) < 0.01)
        #expect(abs(p.elevation - 27.4008) < 0.01)
        // Full SGP4/SDP4 (sgp4 2.27): within 0.1°.
        #expect(abs(p.azimuth - 312.0415) < 0.1)
        #expect(abs(p.elevation - 27.3348) < 0.1)
        #expect(p.rangeKm > 20000 && p.rangeKm < 26000)
        #expect(p.label == "G13")
        #expect(p.constellation == .gps)
    }

    @Test func subpointRoundTrip() {
        // A point 20 000 km above 40° N 10° E.
        let lat = 40.0 * Double.pi / 180, lon = 10.0 * Double.pi / 180
        let a = 6378.137, f = 1 / 298.257_223_563, e2 = f * (2 - f), h = 20_000.0
        let n = a / (1 - e2 * sin(lat) * sin(lat)).squareRoot()
        let ecef = SIMD3((n + h) * cos(lat) * cos(lon), (n + h) * cos(lat) * sin(lon), (n * (1 - e2) + h) * sin(lat))
        let ground = Orbit.subpoint(ecef)
        #expect(abs(ground.latitude - 40) < 1e-6)
        #expect(abs(ground.longitude - 10) < 1e-6)
        let look = Orbit.lookAngles(ecef, latitude: 40, longitude: 10)
        #expect(abs(look.elevation - 90) < 1e-6)
        #expect(abs(look.range - h) < 1e-6)
    }

    @Test func decodesCelesTrakJSON() throws {
        let json = """
        [{"OBJECT_NAME":"GPS BIIF-1  (PRN 25)","OBJECT_ID":"2010-022A","EPOCH":"2026-10-08T21:04:12.345678",
          "MEAN_MOTION":2.00561234,"ECCENTRICITY":0.0101234,"INCLINATION":54.9876,"RA_OF_ASC_NODE":123.4567,
          "ARG_OF_PERICENTER":56.789,"MEAN_ANOMALY":303.21,"EPHEMERIS_TYPE":0,"CLASSIFICATION_TYPE":"U",
          "NORAD_CAT_ID":36585,"ELEMENT_SET_NO":999,"REV_AT_EPOCH":11804,"BSTAR":0,"MEAN_MOTION_DOT":-6.9e-7,
          "MEAN_MOTION_DDOT":0},
         {"OBJECT_NAME":"COSMOS 2433 (720)","NORAD_CAT_ID":32275,"EPOCH":"2026-10-09T03:00:00.000000",
          "MEAN_MOTION":2.13103,"ECCENTRICITY":0.001,"INCLINATION":64.8,"RA_OF_ASC_NODE":10,"ARG_OF_PERICENTER":20,
          "MEAN_ANOMALY":30}]
        """
        let elements = try OrbitalElements.decode(Data(json.utf8))
        #expect(elements.count == 2)
        let gps = try #require(elements.first)
        #expect(gps.noradID == 36585)
        #expect(gps.label == "G25")
        #expect(abs(gps.epoch.timeIntervalSince1970 - 1_791_493_452.345678) < 1e-3)
        #expect(elements[1].constellation == .glonass)
        #expect(elements[1].label == "R720")
    }

    @Test func labelsAndConstellations() {
        func element(_ name: String) -> OrbitalElements {
            OrbitalElements(name: name, noradID: 1, epoch: Self.epoch, meanMotion: 2, eccentricity: 0, inclination: 55,
                            rightAscension: 0, argumentOfPerigee: 0, meanAnomaly: 0)
        }
        #expect(element("GPS BIII-1  (PRN 04)").label == "G04")
        #expect(element("GSAT0210 (GALILEO 13)").label == "E210")
        #expect(element("GSAT0210 (GALILEO 13)").constellation == .galileo)
        #expect(element("BEIDOU-3 M1 (C19)").label == "C19")
        #expect(element("BEIDOU-3 M1 (C19)").constellation == .beidou)
        #expect(element("QZS-2 (QZSS/PRN 184)").label == "J184")
        #expect(element("IRNSS-1I").constellation == .navic)
        #expect(element("IRNSS-1B").label == "I1B")
        #expect(element("NVS-01 (IRNSS-1J)").label == "I1J")
        #expect(element("SES-5 (EGNOS/PRN 136)").label == "S136")
        #expect(element("COSMOS 2620").label == "R2620")
    }

    @Test func catalogSortsByElevationAndDropsOldOrbits() {
        let old = OrbitalElements(name: "GPS OLD (PRN 01)", noradID: 2, epoch: Self.epoch.addingTimeInterval(-60 * 86400),
                                  meanMotion: 2.00562, eccentricity: 0.01, inclination: 55, rightAscension: 0,
                                  argumentOfPerigee: 0, meanAnomaly: 0)
        let catalog = SatelliteCatalog(elements: SampleOrbits.elements(epoch: Self.epoch) + [old])
        let positions = catalog.positions(at: Self.epoch, latitude: 51.5, longitude: -0.12)
        #expect(!positions.contains { $0.id == 2 })
        #expect(positions.count == SampleOrbits.elements(epoch: Self.epoch).count)
        #expect(zip(positions, positions.dropFirst()).allSatisfy { $0.elevation >= $1.elevation })
        #expect(positions.contains { $0.elevation > 0 })
    }

    @Test func epochParsing() {
        #expect(OrbitalElements.parseEpoch("2026-10-09T12:00:00") == Self.epoch)
        #expect(OrbitalElements.parseEpoch("2026-10-09T12:00:00.500000")?.timeIntervalSince(Self.epoch) == 0.5)
        #expect(OrbitalElements.parseEpoch("nonsense") == nil)
    }
}

/// Reference values from numpy (least squares with one clock per system).
struct DilutionOfPrecisionTests {
    private func sat(_ c: Constellation, _ az: Double, _ el: Double, _ id: Int) -> SatellitePosition {
        SatellitePosition(id: id, label: "", constellation: c, azimuth: az, elevation: el, rangeKm: 20000, latitude: 0, longitude: 0)
    }

    @Test func zenithPlusThreeOnTheHorizon() throws {
        let dop = try #require(DilutionOfPrecision.predict(from: [sat(.gps, 0, 90, 1), sat(.gps, 0, 0, 2), sat(.gps, 120, 0, 3),
                                                                  sat(.gps, 240, 0, 4)], mask: 0))
        #expect(abs(dop.horizontal - 1.1547005383792517) < 1e-9)
        #expect(abs(dop.vertical - 1.1547005383792515) < 1e-9)
        #expect(abs(dop.position - 1.632993161855452) < 1e-9)
    }

    @Test func twoSystemsWithSeparateClocks() throws {
        let satellites = [sat(.gps, 0, 90, 1), sat(.gps, 45, 30, 2), sat(.gps, 135, 30, 3), sat(.gps, 225, 30, 4),
                          sat(.gps, 315, 30, 5), sat(.galileo, 10, 60, 6), sat(.galileo, 190, 20, 7), sat(.galileo, 100, 45, 8)]
        let dop = try #require(DilutionOfPrecision.predict(from: satellites))
        #expect(abs(dop.horizontal - 1.0096756946332062) < 1e-9)
        #expect(abs(dop.vertical - 1.876901619276039) < 1e-9)
        #expect(abs(dop.position - 2.1312448702047506) < 1e-9)
        #expect(dop.satelliteCount == 8)
    }

    @Test func masksLowSatellitesAndSBASAndNeedsEnough() {
        let satellites = [sat(.gps, 0, 90, 1), sat(.gps, 0, 5, 2), sat(.gps, 120, 30, 3), sat(.other, 240, 40, 4)]
        #expect(DilutionOfPrecision.predict(from: satellites) == nil)
        #expect(DilutionOfPrecision.invert([[1, 2], [2, 4]]) == nil)
    }

    @Test func realisticSkyGivesLowDOP() throws {
        let date = SatelliteTests.epoch
        let positions = SatelliteCatalog(elements: SampleOrbits.elements(epoch: date))
            .positions(at: date, latitude: 51.5, longitude: -0.12)
        let dop = try #require(DilutionOfPrecision.predict(from: positions))
        #expect(dop.horizontal > 0.3 && dop.horizontal < 1.5)
        #expect(dop.expectedAccuracy >= DilutionOfPrecision.accuracyFloor)
    }

    @Test func skyViewFromAccuracyRatio() {
        #expect(SkyView(reported: 4.7, expected: 3) == .open)
        #expect(SkyView(reported: 12, expected: 3) == .partial)
        #expect(SkyView(reported: 40, expected: 3) == .obstructed)
    }
}
