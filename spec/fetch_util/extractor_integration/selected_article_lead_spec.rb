# frozen_string_literal: true

RSpec.describe 'Selected article lead ownership' do
  include_context 'extractor integration helpers'

  let(:url) { 'https://publisher.example/learn/automated-market-maker' }
  let(:title) { 'What Is an Automated Market Maker (AMM)? How AMMs Work in DeFi' }
  let(:lead) do
    'An automated market maker (AMM) is a smart contract-based protocol that enables decentralized exchanges (DEXs) ' \
      'to facilitate crypto trading using liquidity pools and mathematical pricing formulas instead of traditional ' \
      'order books. Liquidity providers deposit token pairs into pools, and the AMM algorithmically sets prices based ' \
      'on the ratio of assets in each pool — most commonly using the constant product formula (x × y = k).'
  end

  def article_page(opening:, extra: '', body: true, before_lead: '')
    paragraphs = if body
                   "#{before_lead}<p>#{opening}</p>" + (1..8).map do |index|
                     "<p>Chapter #{index} explains how liquidity pools establish a market price and why traders " \
                       'use the resulting exchange mechanism for their transactions.</p>'
                   end.join
                 else
                   ''
                 end
    <<~HTML
      <html><head><title>#{title} | Publisher</title><meta property="og:site_name" content="Publisher">
        <meta property="og:type" content="article"><meta property="og:title" content="#{title}">
        <link rel="canonical" href="#{url}"></head><body>
        <div class="gecko-sidebar-page layout-compact"><main><article>
          <a href="/learn/category/guides">Guides</a><h1>#{title}</h1>
          <div class="byline"><a href="/author/editor">Editor</a></div>
          <a href="https://www.google.com/preferences/source?q=publisher.example">Make us preferred on Google</a>
          <div class="post-body buzz-body"><div class="raw-post-body"><h2>What Is an Automated Market Maker (AMM)?</h2>
            #{paragraphs}<table><tr><th>Model</th><td>Liquidity pool</td></tr></table>
            <figure><img src="/images/pool.png" alt="Liquidity pool diagram"></figure>
          </div></div></article></main>
          <nav><a href="/learn/more">More + Guides</a></nav>#{extra}
        </div>
      </body></html>
    HTML
  end

  def lead_probe_source
    root = File.expand_path('../../..', __dir__)
    File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).filter_map do |path|
      next if path.empty? || path.start_with?('#')

      content = File.read(File.join(root, 'websieve', path))
      next content unless path == '99_outro.js'

      "globalThis.__selectedLeadProbe = { fallbackSelectedArticleLead, fallbackFocalHeadlineOwnership, " \
        "visibilityPrunedClone, collectMetadata };#{content}"
    end.join("\n")
  end

  it 'takes the complete authored opening from the mapped article while retaining its body and source DOM' do
    with_url_page(url, article_page(opening: lead)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload.fetch('excerpt')).to eq(lead)
      expect(payload.fetch('excerpt').length).to be > 280
      expect(payload.fetch('html')).to include(lead, 'Chapter 8', 'Liquidity pool diagram', '<table')
      expect(payload.fetch('markdown')).to include(lead, 'Chapter 8', 'Liquidity pool')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps a complete short authored lead without requiring an eighty-character minimum' do
    short = 'A liquidity pool sets the exchange price.'
    with_url_page(url, article_page(opening: short)) do |page|
      expect(extract_payload(page).fetch('excerpt')).to eq(short)
    end
  end

  it 'does not blacklist authored prose merely for mentioning navigation and Google' do
    opening = 'Google and Read More navigation are discussed as part of the AMM user experience.'
    with_url_page(url, article_page(opening: opening)) do |page|
      expect(extract_payload(page).fetch('excerpt')).to eq(opening)
    end
  end

  it 'chooses the owning article lead after a nested headed record without deleting that record' do
    opening = 'The owning AMM article begins with this short authored explanation.'
    nested_text = 'A different report describes its own liquidity exchange with a separate authored introduction.'
    nested = %(<article><h2>Independent liquidity report</h2><p>#{nested_text}</p></article>)
    with_url_page(url, article_page(opening: opening, before_lead: nested)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload.fetch('excerpt')).to eq(opening)
      expect(payload.fetch('html')).to include(opening, nested_text, 'Chapter 8')
      expect(payload.fetch('markdown')).to include(opening, nested_text, 'Chapter 8')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      page.add_script_tag(content: lead_probe_source)
      proof = page.evaluate(<<~JS)
        (function() {
          var probe = window.__selectedLeadProbe;
          var article = document.querySelector('main article');
          var owner = probe.fallbackFocalHeadlineOwnership();
          var map = new WeakMap();
          var root = probe.visibilityPrunedClone(document.body, document, map);
          return {
            owner: !!owner && owner.node === article && owner.proof === 'same-owner-source-headline',
            nestedMapped: map.get(article.querySelector('article p')) === root.querySelector('article article p'),
            lead: probe.fallbackSelectedArticleLead(root, root.textContent, owner, map, probe.collectMetadata())
          };
        })()
      JS
      expect(proof).to eq('owner' => true, 'nestedMapped' => true, 'lead' => opening)
    end
  end

  it 'does not borrow a matching paragraph from a separate record when the focal body is absent' do
    other = %(<aside><h2>Independent record</h2><p>#{lead}</p><p>#{lead}</p></aside>)
    with_url_page(url, article_page(opening: lead, body: false, extra: other)) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: lead_probe_source)
      excerpt = page.evaluate(<<~JS)
        (function() {
          var probe = window.__selectedLeadProbe;
          var article = document.querySelector('main article');
          var map = new WeakMap();
          var root = probe.visibilityPrunedClone(document.body, document, map);
          return probe.fallbackSelectedArticleLead(root, root.textContent, {
            proof: 'same-owner-source-headline', node: article, heading: article.querySelector('h1'),
            title: #{title.to_json}
          }, map, probe.collectMetadata());
        })()
      JS
      expect(excerpt).to be_nil
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not promote a paragraph outside the selected article into its lead' do
    foreign = %(<section><p>#{lead}</p></section>)
    with_url_page(url, article_page(opening: 'A liquidity pool sets the exchange price.', extra: foreign)) do |page|
      expect(extract_payload(page).fetch('excerpt')).not_to eq(lead)
    end
  end

  it 'does not take hidden, header-CTA, or navigation paragraphs as the authored lead' do
    opening = 'The short public introduction explains the exchange rate.'
    furniture = %(<header><p>#{lead}</p></header><nav><p>#{lead}</p></nav><p hidden>#{lead}</p>)
    with_url_page(url, article_page(opening: opening, extra: furniture)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload.fetch('excerpt')).not_to eq(lead)
      expect(payload.fetch('html')).to include(opening)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
