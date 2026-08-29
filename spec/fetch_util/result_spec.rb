# frozen_string_literal: true

RSpec.describe FetchUtil::Result do
  def result_from(payload, warnings: [])
    described_class.from_payload(
      url: "https://example.test/post/1",
      final_url: "https://social.example.test/post/1",
      payload: payload,
      canonical_url: "https://social.example.test/post/1",
      content_type: "article",
      warnings: warnings,
      suspect: false
    )
  end

  it "maps every payload metadata field through the result contract" do
    payload = {
      "title" => "A complete result",
      "byline" => "Example Author",
      "excerpt" => "Result summary",
      "siteName" => "Example",
      "publishedTime" => "2026-08-29T12:00:00Z",
      "language" => "en",
      "name" => "Example name",
      "company" => "Example Company",
      "location" => "Example City",
      "description" => "Structured description",
      "ingredients" => %w[one two],
      "instructions" => %w[first second],
      "bedrooms" => 3,
      "bathrooms" => 2,
      "areaSqft" => 1428,
      "html" => "<article>Complete</article>",
      "markdown" => "# Complete",
      "readerMode" => true,
      "contentCompletenessRatio" => "0.75",
      "contentFormat" => "article",
      "paywallState" => "none",
      "price" => "$199.99",
      "rating" => 4.8,
      "address" => "1 Example Street",
      "socialKind" => "post",
      "platform" => "mastodon",
      "handle" => "@example@test.social",
      "replyCount" => 7,
      "community" => "Ruby",
      "score" => 42
    }

    result = result_from(payload)
    expected_metadata = {
      title: "A complete result", byline: "Example Author", excerpt: "Result summary", site_name: "Example",
      published_time: "2026-08-29T12:00:00Z", canonical_url: "https://social.example.test/post/1", language: "en",
      name: "Example name", company: "Example Company", location: "Example City", description: "Structured description",
      ingredients: %w[one two], instructions: %w[first second], bedrooms: 3, bathrooms: 2, area_sqft: 1428,
      content_url: "https://social.example.test/post/1", reader_mode: true, content_type: "article", suspect: false,
      warnings: [], content_completeness_ratio: 0.75, content_format: "article", paywall_state: "none", price: "$199.99",
      rating: 4.8, address: "1 Example Street", social_kind: "post", platform: "mastodon",
      handle: "@example@test.social", reply_count: 7, community: "Ruby", score: 42
    }

    expect(result.metadata).to eq(expected_metadata)
    expect(result.metadata.keys).to eq(expected_metadata.keys)
    expected_metadata.except(:content_url).each do |field, value|
      expect(result.public_send(field)).to eq(value)
      expect(result.to_h.fetch(field)).to eq(value)
    end
    expect(result).to have_attributes(
      url: "https://example.test/post/1", final_url: "https://social.example.test/post/1",
      html: "<article>Complete</article>", markdown: "# Complete"
    )
  end

  it "maps social payload fields to readers, metadata, and serialization" do
    payload = {
      "socialKind" => "post",
      "platform" => "mastodon",
      "handle" => "@fetcher@ruby.social",
      "replyCount" => 7,
      "community" => "Ruby",
      "score" => 42
    }
    result = result_from(payload)

    expect(result).to have_attributes(
      social_kind: "post",
      platform: "mastodon",
      handle: "@fetcher@ruby.social",
      reply_count: 7,
      community: "Ruby",
      score: 42,
      content_type: "article"
    )
    expect(result.metadata).to include(
      social_kind: "post",
      platform: "mastodon",
      handle: "@fetcher@ruby.social",
      reply_count: 7,
      community: "Ruby",
      score: 42
    )
    expect(result.metadata).to be_frozen
    expect(result.to_h).to include(
      social_kind: "post",
      platform: "mastodon",
      handle: "@fetcher@ruby.social",
      reply_count: 7,
      community: "Ruby",
      score: 42
    )
  end

  it "keeps social fields nil for legacy payloads" do
    result = result_from({})

    expect(result).to have_attributes(
      social_kind: nil,
      platform: nil,
      handle: nil,
      reply_count: nil,
      community: nil,
      score: nil
    )
    expect(result.metadata.slice(:social_kind, :platform, :handle, :reply_count, :community, :score).values).to all(be_nil)
  end

  it "keeps social fields nil for error results" do
    result = described_class.error(url: "https://example.test", warning: "network_error", message: "unavailable")

    expect(result).to have_attributes(
      social_kind: nil,
      platform: nil,
      handle: nil,
      reply_count: nil,
      community: nil,
      score: nil
    )
  end

  it "owns one immutable warning collection for error results" do
    warning = +"network_error"
    result = described_class.error(url: "https://example.test", warning: warning, message: "unavailable")
    warning.replace("changed")

    expect(result.warnings).to eq(["network_error"])
    expect(result.metadata.fetch(:warnings)).to equal(result.warnings)
    expect(result.warnings).to be_frozen
    expect { result.metadata.fetch(:warnings) << "changed" }.to raise_error(FrozenError)
  end

  it "owns warning strings for successful results" do
    warning = +"truncated_content"
    warnings = [warning]
    result = result_from({}, warnings: warnings)

    warning.replace("changed")
    warnings << "another_warning"

    expect(result.warnings).to eq(["truncated_content"])
    expect(result.metadata.fetch(:warnings)).to equal(result.warnings)
    expect(result.warnings.first).to be_frozen
    expect(result.warnings).to be_frozen
    expect(warnings).not_to be_frozen
  end
end
