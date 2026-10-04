# frozen_string_literal: true

RSpec.describe "documentation URL classification" do
  it "recognizes the established host and path families through the public helper" do
    values = [
      "https://react.dev/learn", "https://project.readthedocs.io/en/latest/",
      "https://docs.example.org/", "https://developer.example.org/",
      "https://developers.example.org/", "https://api.example.org/",
      "https://www.wiktionary.org/", "https://go.dev/ref/spec",
      "https://example.org/Getting-Started/", "https://example.org/en/sdk/one",
      "https://example.org/products/reference-index", URI("https://docs.rs/serde")
    ]

    values.each { |value| expect(FetchUtil.docs_like_url?(value)).to be(true), value.to_s }
  end

  it "rejects non-document, non-HTTP, relative and malformed URLs" do
    values = [nil, "", "https://example.org/products/widget", "https://go.dev/blog/",
              "https://example.org/doctors", "ftp://docs.example.org/", "/docs/guide", "https://[bad"]

    values.each { |value| expect(FetchUtil.docs_like_url?(value)).to be(false), value.to_s }
  end

  it "retains the existing classifier constants for callers" do
    expect(FetchUtil::DOCS_LIKE_EXACT_HOSTS).to include("react.dev", "docs.rs")
    expect(FetchUtil::DOCS_LIKE_PATH_KEYWORDS).to include("reference", "sdk")
    expect(FetchUtil::DOCS_LIKE_PATH_PATTERN).to match("/reference/api")
    expect(FetchUtil::DOCS_LIKE_EXACT_HOSTS).to be_frozen
  end
end
