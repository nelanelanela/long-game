import Testing
@testable import LongGame

struct CraftSuggestionsTests {
    @Test func fiveGroupsInOrder() {
        #expect(CraftSuggestions.groups.map(\.name) == ["Music", "Visual arts & making", "Performing arts", "Words & mind", "Professions"])
        #expect(CraftSuggestions.groups[2].crafts == ["Acting", "Dance", "Ballet", "Directing"])
        #expect(CraftSuggestions.groups[1].crafts.last == "Jewellery")
    }

    @Test func customNamesNeedTwoToFortyCharacters() {
        #expect(!CraftSuggestions.isValidName("a"))
        #expect(CraftSuggestions.isValidName("Ab"))
        #expect(CraftSuggestions.isValidName(String(repeating: "x", count: 40)))
        #expect(!CraftSuggestions.isValidName(String(repeating: "x", count: 41)))
    }
}
