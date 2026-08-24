package hashtag

import (
	"context"
	"strings"
)

// curatedBank is the real Bank implementation. It holds a curated, deterministic
// set of hashtags organized by platform and topic. The bank is brand-safe and
// locally relevant (Ethiopian market, PRD §6.3).
//
// The bank does NOT call any external API — it's a local lookup, so it's fast,
// free, and deterministic. Topics are matched by keyword extraction from the
// input text.
type curatedBank struct {
	// platformTopics maps platform → topic → hashtags.
	platformTopics map[string]map[string][]string

	// globalTopics are platform-agnostic hashtags added to every response.
	globalTopics []string
}

// NewCuratedBank builds the hashtag bank with the default curated dataset.
func NewCuratedBank() Bank {
	return &curatedBank{
		platformTopics: buildPlatformTopics(),
		globalTopics:   buildGlobalTopics(),
	}
}

func (b *curatedBank) Suggest(_ context.Context, platform, topic string, n int) ([]string, error) {
	if n <= 0 {
		n = 5
	}
	if n > 8 {
		n = 8
	}

	platform = strings.ToLower(strings.TrimSpace(platform))
	topic = strings.ToLower(strings.TrimSpace(topic))

	// Collect hashtags from three sources:
	// 1. Topic-specific hashtags for this platform
	// 2. Global (platform-agnostic) hashtags
	// 3. Platform-specific generic hashtags
	var candidates []string

	// Topic-specific for this platform.
	if topics, ok := b.platformTopics[platform]; ok {
		if tags, ok := topics[topic]; ok {
			candidates = append(candidates, tags...)
		}
		// Also check if topic matches any broader category.
		for cat, tags := range topics {
			if cat != topic && strings.Contains(topic, cat) {
				candidates = append(candidates, tags...)
			}
		}
	}

	// Global hashtags (Ethiopian market, brand-safe).
	candidates = append(candidates, b.globalTopics...)

	// Platform-specific generics.
	if topics, ok := b.platformTopics[platform]; ok {
		if tags, ok := topics["_generic"]; ok {
			candidates = append(candidates, tags...)
		}
	}

	// Deduplicate and trim to n.
	seen := make(map[string]bool)
	var result []string
	for _, tag := range candidates {
		tag = normalizeHashtag(tag)
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		result = append(result, tag)
		if len(result) >= n {
			break
		}
	}

	// If we still don't have enough, add fallback generic tags.
	fallbacks := []string{"#kelal", "#ethiopia", "#smallbusiness", "#madewithkelal", "#addisababa", "#ethiopianbusiness", "#supportlocal", "#madeinethiopia"}
	for _, fb := range fallbacks {
		fb = normalizeHashtag(fb)
		if !seen[fb] {
			result = append(result, fb)
			seen[fb] = true
		}
		if len(result) >= n {
			break
		}
	}

	return result, nil
}

// normalizeHashtag ensures the tag starts with # and is lowercase alphanumeric.
func normalizeHashtag(tag string) string {
	tag = strings.TrimSpace(tag)
	if tag == "" {
		return ""
	}
	if !strings.HasPrefix(tag, "#") {
		tag = "#" + tag
	}
	// Keep only alphanumeric after #.
	var b strings.Builder
	b.WriteByte('#')
	for _, r := range tag[1:] {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	result := b.String()
	if result == "#" {
		return ""
	}
	return result
}

// buildGlobalTopics returns platform-agnostic hashtags for the Ethiopian market.
func buildGlobalTopics() []string {
	return []string{
		"#kelal",
		"#ethiopia",
		"#ethiopian",
		"#addisababa",
		"#madewithkelal",
	}
}

// buildPlatformTopics returns the curated hashtag database keyed by platform
// and topic. Topics are broad categories that match keywords in user input.
func buildPlatformTopics() map[string]map[string][]string {
	return map[string]map[string][]string{
		"instagram": {
			"_generic": {
				"#instagood",
				"#photooftheday",
				"#instadaily",
				"#reels",
				"#explore",
				"#instalike",
			},
			"food": {
				"#ethiopianfood",
				"#injera",
				"#ethiopiancuisine",
				"#foodie",
				"#foodporn",
				"#yummy",
				"#delicious",
				"#tasty",
				"#eatlocal",
			},
			"fashion": {
				"#ethiopianfashion",
				"#fashion",
				"#style",
				"#ootd",
				"#fashionblogger",
				"#clothing",
				"#handmade",
				"#traditional",
				"#habesha",
			},
			"coffee": {
				"#ethiopiancoffee",
				"#coffee",
				"#coffeelover",
				"#coffetime",
				"#coffeeaddict",
				"#barista",
				"#coffeeshop",
				"#bunna",
			},
			"tech": {
				"#ethiopiantech",
				"#tech",
				"#startup",
				"#innovation",
				"#digital",
				"#app",
				"#technology",
				"#entrepreneur",
			},
			"beauty": {
				"#ethiopianbeauty",
				"#beauty",
				"#skincare",
				"#beautytips",
				"#naturalbeauty",
				"#glow",
				"#selfcare",
				"#beautyblogger",
			},
			"travel": {
				"#ethiopiatravel",
				"#travel",
				"#tourism",
				"#visitethiopia",
				"#adventure",
				"#explore",
				"#wanderlust",
				"#beautifuldestinations",
			},
			"art": {
				"#ethiopianart",
				"#art",
				"#painting",
				"#artist",
				"#artwork",
				"#creative",
				"#handmade",
				"#crafts",
			},
			"business": {
				"#ethiopianbusiness",
				"#smallbusiness",
				"#entrepreneur",
				"#businessowner",
				"#startup",
				"#hustle",
				"#businessgrowth",
				"#supportlocal",
			},
			"fitness": {
				"#ethiopianfitness",
				"#fitness",
				"#workout",
				"#gym",
				"#health",
				"#motivation",
				"#fitfam",
				"#healthy",
			},
		},
		"tiktok": {
			"_generic": {
				"#fyp",
				"#foryou",
				"#viral",
				"#trending",
				"#tiktokethiopia",
				"#explorepage",
			},
			"food": {
				"#ethiopianfood",
				"#foodtok",
				"#cooking",
				"#recipe",
				"#foodie",
				"#injera",
				"#yum",
				"#foodreview",
			},
			"fashion": {
				"#fashiontok",
				"#ootd",
				"#style",
				"#fashion",
				"#trend",
				"#outfit",
				"#handmade",
				"#habesha",
			},
			"coffee": {
				"#coffeetok",
				"#coffee",
				"#barista",
				"#coffeelover",
				"#coffeetime",
				"#ethiopiancoffee",
				"#bunna",
			},
			"tech": {
				"#techtok",
				"#tech",
				"#gadget",
				"#innovation",
				"#future",
				"#digital",
				"#startup",
			},
			"business": {
				"#businesstok",
				"#entrepreneur",
				"#smallbusiness",
				"#money",
				"#hustle",
				"#businessowner",
				"#success",
			},
		},
		"telegram": {
			"_generic": {
				"#telegram",
				"#channel",
				"#joinus",
				"#follow",
			},
			"food": {
				"#ethiopianfood",
				"#food",
				"#recipe",
				"#cooking",
				"#injera",
			},
			"fashion": {
				"#fashion",
				"#style",
				"#clothing",
				"#handmade",
			},
			"business": {
				"#business",
				"#entrepreneur",
				"#shop",
				"#deals",
				"#offer",
			},
		},
	}
}

// MatchTopic extracts the most relevant topic from input text by keyword
// matching. Returns "business" as the default fallback.
func MatchTopic(inputText string) string {
	lower := strings.ToLower(inputText)

	// Ordered by specificity — first match wins.
	rules := []struct {
		topic   string
		keywords []string
	}{
		{"coffee", []string{"coffee", "bunna", "espresso", "cappuccino", "latte", "brew", "roast"}},
		{"food", []string{"food", "eat", "restaurant", "cook", "recipe", "meal", "lunch", "dinner", "breakfast", "injera", "kitfo", "doro", "tibs"}},
		{"fashion", []string{"fashion", "clothes", "dress", "shirt", "style", "wear", "outfit", "leather", "bag", "shoes", "textile"}},
		{"beauty", []string{"beauty", "skin", "makeup", "cosmetic", "hair", "glow", "cream", "lotion"}},
		{"tech", []string{"tech", "app", "software", "digital", "code", "startup", "ai", "platform"}},
		{"travel", []string{"travel", "tour", "visit", "hotel", "flight", "destination", "adventure", "explore"}},
		{"art", []string{"art", "paint", "draw", "sculpt", "craft", "design", "creative"}},
		{"fitness", []string{"fitness", "gym", "workout", "exercise", "health", "sport", "run"}},
	}

	for _, rule := range rules {
		for _, kw := range rule.keywords {
			if strings.Contains(lower, kw) {
				return rule.topic
			}
		}
	}

	return "business"
}

// MergeHashtags combines provider-generated hashtags with bank-suggested ones,
// deduplicates, and returns exactly n hashtags (5–8 per contract).
func MergeHashtags(providerHashtags, bankHashtags []string, n int) []string {
	if n < 5 {
		n = 5
	}
	if n > 8 {
		n = 8
	}

	seen := make(map[string]bool)
	var result []string

	// Provider hashtags first (they're model-generated and context-specific).
	for _, tag := range providerHashtags {
		tag = normalizeHashtag(tag)
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		result = append(result, tag)
	}

	// Bank hashtags fill remaining slots.
	for _, tag := range bankHashtags {
		tag = normalizeHashtag(tag)
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		result = append(result, tag)
		if len(result) >= n {
			break
		}
	}

	// Fallback if still not enough.
	if len(result) < n {
		fallbacks := []string{"#kelal", "#ethiopia", "#smallbusiness", "#madewithkelal", "#addisababa", "#ethiopianbusiness", "#supportlocal", "#madeinethiopia"}
		for _, fb := range fallbacks {
			fb = normalizeHashtag(fb)
			if !seen[fb] {
				result = append(result, fb)
				seen[fb] = true
			}
			if len(result) >= n {
				break
			}
		}
	}

	return result
}
