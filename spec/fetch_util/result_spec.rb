# frozen_string_literal: true

RSpec.describe FetchUtil::Result do
  def result_from(payload)
    described_class.from_payload(
      url: "https://example.test/post/1",
      final_url: "https://social.example.test/post/1",
      payload: payload,
      canonical_url: "https://social.example.test/post/1",
      content_type: "article",
      warnings: [],
      suspect: false
    )
  end

  it "maps social payload fields to readers, metadata, and serialization" do
    result = result_from(
      "socialKind" => "post",
      "platform" => "mastodon",
      "handle" => "@fetcher@ruby.social",
      "replyCount" => 7,
      "community" => "Ruby",
      "score" => 42
    )

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
end
