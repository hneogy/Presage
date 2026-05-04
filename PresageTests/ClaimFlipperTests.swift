import Testing
import Foundation
@testable import Pari

@Suite("ClaimFlipper")
struct ClaimFlipperTests {

    @Test("Flips 'I will' to 'I won't'")
    func willToWont() {
        #expect(ClaimFlipper.flip("I will go to the gym") == "I won't go to the gym")
    }

    @Test("Flips 'I won't' to 'I will'")
    func wontToWill() {
        #expect(ClaimFlipper.flip("I won't finish the book") == "I will finish the book")
    }

    @Test("Flips 'I will not' to 'I will'")
    func willNotToWill() {
        #expect(ClaimFlipper.flip("I will not call them") == "I will call them")
    }

    @Test("Flips 'I'm going to' to 'I'm not going to'")
    func goingToToNotGoingTo() {
        let result = ClaimFlipper.flip("I'm going to ship it")
        #expect(result == "I'm not going to ship it")
    }

    @Test("Round-trips: flipping twice returns close to original")
    func roundTrip() {
        let original = "I will go running tomorrow"
        let once = ClaimFlipper.flip(original) ?? ""
        let twice = ClaimFlipper.flip(once) ?? ""
        #expect(twice == original)
    }

    @Test("Falls back to 'Not:' prefix for unrecognized claims")
    func unrecognizedFallback() {
        let result = ClaimFlipper.flip("The package arrives by Friday")
        #expect(result == "Not: The package arrives by Friday")
    }

    @Test("Removes 'Not:' prefix on second flip")
    func removesNotPrefix() {
        let once = ClaimFlipper.flip("The package arrives by Friday")
        let twice = ClaimFlipper.flip(once ?? "")
        #expect(twice == "The package arrives by Friday")
    }

    @Test("Empty input returns nil")
    func emptyInput() {
        #expect(ClaimFlipper.flip("") == nil)
        #expect(ClaimFlipper.flip("   ") == nil)
    }
}
