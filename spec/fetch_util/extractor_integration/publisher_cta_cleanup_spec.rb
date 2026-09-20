# frozen_string_literal: true

RSpec.describe 'FetchUtil publisher CTA cleanup' do
  include_context 'extractor integration helpers'

  def publisher_cta_article(furniture)
    paragraphs = 4.times.map do |index|
      "<p>Verified report paragraph #{index + 1} preserves public facts and enough substantive context for article extraction.</p>"
    end.join

    <<~HTML
      <html>
        <head><title>Verified public report</title></head>
        <body><main><article><h1>Verified public report</h1>#{paragraphs}#{furniture}</article></main></body>
      </html>
    HTML
  end

  def extract_publisher_cta(furniture)
    with_url_page('https://reports.example/verified-report', publisher_cta_article(furniture)) do |page|
      extractor = extractor_for(true)
      extractor.send(:inject_vendor_assets, page)
      source = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate(extractor.send(:extraction_call))
      yield payload, page.evaluate('document.documentElement.outerHTML'), source
    end
  end

  def clean_publisher_cta_root(furniture)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__cleanPublisherCtaRoot = function(input) {
        var template = document.createElement("template");
        template.innerHTML = input;
        var sourceNode = template.content.firstElementChild;
        var before = sourceNode.outerHTML;
        var clone = sourceNode.cloneNode(true);
        stripPublisherCtaNotes(clone);
        return {clone: clone.outerHTML, before: before, sourceUnchanged: sourceNode.outerHTML === before};
      };
    JS

    with_page('<html><head><meta name="source-sentinel" content="unchanged"></head><body><main>Unchanged source page</main></body></html>') do |page|
      page.add_script_tag(content: source)
      before = page.evaluate('document.documentElement.outerHTML')
      result = page.evaluate("window.__cleanPublisherCtaRoot(#{JSON.generate("<article>#{furniture}</article>")})")
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
      result
    end
  end

  it 'removes short exact-owner notes made only of follow and subscribe actions' do
    furniture = <<~HTML
      <div class="post-disclaimer"><p><strong>Pratite nas na našoj Facebook i Instagram stranici, ali i na X nalogu. Pretplatite se na PDF izdanje lista Danas.</strong></p></div>
      <aside class="publisher-cta">Follow us on Instagram! Subscribe today.</aside>
      <div class="publisher_cta">Пратите нас на Facebook страници！Претплатите се на PDF издање؟</div>
    HTML

    cleaned = clean_publisher_cta_root(furniture)
    expect(cleaned.fetch('before')).to include('Pratite nas', 'Follow us', 'Пратите нас')
    expect(cleaned.fetch('clone')).not_to include('Pratite nas', 'Follow us', 'Пратите нас')
    expect(cleaned.fetch('sourceUnchanged')).to be(true)

    extract_publisher_cta(furniture) do |payload, after, before|
      expect(payload.fetch('markdown')).to include('Verified report paragraph 1', 'Verified report paragraph 4')
      expect(payload.fetch('markdown')).not_to include('Pratite nas', 'Pretplatite se', 'Follow us', 'Subscribe today')
      expect(after).to eq(before)
    end
  end

  it 'preserves publisher notes with page-authored excerpt-marker attributes' do
    furniture = <<~HTML
      <div class="publisher-cta"><p data-fetchutil-excerpt-source="page-authored">Follow us on Facebook.</p></div>
    HTML

    cleaned = clean_publisher_cta_root(furniture)
    expect(cleaned.fetch('clone')).to include('Follow us on Facebook', 'data-fetchutil-excerpt-source="page-authored"')
    expect(cleaned.fetch('sourceUnchanged')).to be(true)
  end

  it 'preserves uncertain, structured, linked, mixed, or similarly named notes' do
    furniture = <<~HTML
      <div class="disclaimer"><p>Editorial disclosure: reporting methods and source limitations remain material.</p></div>
      <div class="post-disclaimer-note"><p>Follow us on the evidence trail described in this report.</p></div>
      <div class="post-disclaimer"><p>Editorial correction: the source date was updated.</p></div>
      <div class="post-disclaimer"><p>Follow us on Facebook. Editorial correction remains material.</p></div>
      <div class="post-disclaimer"><p>Follow us on Facebook; editorial correction remains material.</p></div>
      <div class="post-disclaimer"><p>Follow us on Facebook for the correction to our earlier report.</p></div>
      <div class="post-disclaimer"><p>Become a member of the museum for access to the archive.</p></div>
      <div class="post-disclaimer"><p>Follow us on Facebook.</p><p>Source methodology remains material.</p></div>
      <div class="post-disclaimer"><p><a href="/investigation">Follow us through the full investigation</a>.</p></div>
      <div class="post-disclaimer"><p>Follow us on Instagram.</p><img src="/evidence.png" alt="Evidence chart"></div>
      <div class="post-disclaimer"><p>Follow us on Instagram.</p><svg><title>Evidence diagram</title></svg></div>
      <div class="post-disclaimer"><p>Follow us on Instagram.</p><evidence-chart>Verified data</evidence-chart></div>
      <div class="post-disclaimer" data-fetchutil-page-overview><p>Follow us on Facebook.</p></div>
      <div class="publisher-cta" role="note" aria-label="Editorial note"><p>Follow us on Facebook.</p></div>
      <div class="publisher-cta" itemprop="description"><p>Follow us on Facebook.</p></div>
      <div class="post-disclaimer"><p><span tabindex="0" onclick="openSubscribeDialog()">Subscribe today.</span></p></div>
      <div class="publisher-cta"><p>Follow us on Facebook. <cite>Editorial board</cite></p></div>
      <div class="post-disclaimer"><span><span class="publisher-cta">Follow us on Facebook.</span></span></div>
      <div class="publisher-cta" role="note"><div class="publisher-cta"><p>Follow us on Facebook.</p></div><p>Editorial disclosure remains material.</p></div>
    HTML

    result = clean_publisher_cta_root(furniture)
    clone = result.fetch('clone')
    expect(clone).to eq(result.fetch('before'))
    expect(clone).to include('Editorial disclosure', 'Follow us on the evidence trail')
    expect(clone).to include('Editorial correction', 'Source methodology')
    expect(clone).to include('correction to our earlier report', 'Become a member of the museum')
    expect(clone).to include('href="/investigation"', 'Follow us through the full investigation')
    expect(clone).to include('src="/evidence.png"', 'Evidence chart')
    expect(clone).to include('Evidence diagram', 'Verified data')
    expect(clone).to include('role="note"', 'itemprop="description"', 'Editorial board')
    expect(clone.scan('Follow us on Facebook.').length).to be >= 3
    expect(result.fetch('sourceUnchanged')).to be(true)
  end
end
