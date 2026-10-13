using AimPark.API.Helpers;
using Xunit;

namespace AimPark.API.Tests
{
    public class SearchTermTests
    {
        [Fact]
        public void A_plate_typed_with_a_space_matches_the_stored_spelling()
        {
            var term = SearchTerm.Parse("ncd 4417");

            Assert.Equal("NCD4417", term.Plate);
            Assert.True(term.UsablePlate);
        }

        [Fact]
        public void A_card_typed_with_colons_matches_the_stored_spelling()
        {
            var term = SearchTerm.Parse("04:a1:22:f9");

            Assert.Equal("04A122F9", term.Tag);
            Assert.True(term.UsableTag);
        }

        [Fact]
        public void A_name_is_never_mistaken_for_a_card()
        {
            // "Gilbert" has letters that are not hex digits.
            Assert.False(SearchTerm.Parse("Gilbert").UsableTag);
        }

        [Fact]
        public void A_name_made_only_of_hex_letters_still_needs_four_characters_to_count_as_a_card()
        {
            Assert.False(SearchTerm.Parse("Ada").UsableTag);
            Assert.True(SearchTerm.Parse("Face").UsableTag);
        }

        [Theory]
        [InlineData("")]
        [InlineData("   ")]
        [InlineData("g")]
        public void Too_little_typed_finds_nothing(string typed)
        {
            Assert.True(SearchTerm.Parse(typed).IsEmpty);
        }

        [Fact]
        public void Nothing_at_all_is_empty()
        {
            Assert.True(SearchTerm.Parse(null).IsEmpty);
        }

        [Fact]
        public void Two_letters_is_enough_for_a_name_but_not_for_a_plate()
        {
            var term = SearchTerm.Parse("Gi");

            Assert.True(term.UsableText);
            Assert.False(term.UsablePlate);
        }
    }
}
