# frozen_string_literal: true

RSpec.shared_context 'cli spec helpers' do
  def default_result_fields
    {
      url: "https://a.test",
      final_url: "https://a.test/final",
      canonical_url: "https://a.test/canonical",
      title: "A",
      excerpt: "about a",
      byline: nil,
      language: nil,
      social_kind: nil,
      platform: nil,
      handle: nil,
      reply_count: nil,
      community: nil,
      score: nil,
      markdown: "body a",
      content_type: "article",
      suspect: false,
      warnings: [],
      metadata: { noisy: true },
      reader_mode: true,
      html: "<p>A</p>"
    }
  end

  def result_double(**overrides)
    fields = default_result_fields.merge(overrides)

    instance_double(FetchUtil::Result, to_h: fields, markdown: fields[:markdown], html: fields[:html])
  end

  def run_cli(*args)
    original = $stdout
    $stdout = StringIO.new
    described_class.start(args)
    $stdout.string
  ensure
    $stdout = original
  end
end
