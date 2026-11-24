import Foundation
import Testing
@testable import ToddlerDailyTracker

@MainActor
@Suite("Baby onboarding")
struct BabyOnboardingTests {
    @Test("No profile routes to onboarding")
    func noProfileRoutesToOnboarding() {
        let repository = InMemoryBabyProfileRepository(profile: nil)
        let viewModel = AppLaunchViewModel(repository: repository)

        viewModel.load()

        #expect(viewModel.state == .needsBabyProfile)
    }

    @Test("Existing profile routes directly to the app")
    func existingProfileRoutesToApp() {
        let repository = InMemoryBabyProfileRepository(profile: BabyProfile(name: "小安", birthday: .now))
        let viewModel = AppLaunchViewModel(repository: repository)

        viewModel.load()

        #expect(viewModel.state == .ready)
    }

    @Test("Whitespace-only name is rejected")
    func whitespaceNameIsRejected() {
        #expect(throws: BabyProfileValidationError.emptyName) {
            try BabyProfileValidator.validate(name: "   ", birthday: .now)
        }
    }

    @Test("Future birthday is rejected")
    func futureBirthdayIsRejected() {
        #expect(throws: BabyProfileValidationError.futureBirthday) {
            try BabyProfileValidator.validate(name: "小安", birthday: .now.addingTimeInterval(86_400))
        }
    }

    @Test("Saving a valid profile routes to the app")
    func validProfileRoutesToApp() {
        let repository = InMemoryBabyProfileRepository(profile: nil)
        let viewModel = AppLaunchViewModel(repository: repository)

        viewModel.load()
        let saved = viewModel.save(name: " 小安 ", birthday: .now)

        #expect(saved)
        #expect(viewModel.state == .ready)
        #expect(repository.profile?.name == "小安")
    }

    @Test("Reset completion returns to onboarding and resets the selected tab")
    func resetCompletionReturnsToOnboarding() {
        let suiteName = "BabyOnboardingTests.resetCompletionReturnsToOnboarding"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        MedicationReminderNavigation.selectReminder(in: defaults)
        let repository = InMemoryBabyProfileRepository(profile: BabyProfile(name: "小安", birthday: .now))
        let viewModel = AppLaunchViewModel(repository: repository, defaults: defaults)
        viewModel.load()

        viewModel.showOnboarding()

        #expect(viewModel.state == .needsBabyProfile)
        #expect(MedicationReminderNavigation.selectedTab(in: defaults) == .today)
    }
}

@MainActor
private final class InMemoryBabyProfileRepository: BabyProfileRepository {
    var profile: BabyProfile?

    init(profile: BabyProfile?) { self.profile = profile }

    func fetchProfile() throws -> BabyProfile? { profile }

    func createProfile(name: String, birthday: Date) throws -> BabyProfile {
        guard profile == nil else { throw BabyProfileRepositoryError.profileAlreadyExists }
        let value = BabyProfile(name: name, birthday: birthday)
        profile = value
        return value
    }

    func updateProfile(_ profile: BabyProfile) throws { self.profile = profile }
}
