# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Editorial article heading identifiers' do
  include_context 'extractor integration helpers'

  def heading_id_article(extra = '')
    <<~HTML
      <html><head><title>Publishing a local report</title></head><body><main><article>
        <h1>Publishing a local report</h1>
        <p>The newsroom published a detailed guide to preparing a local report, with practical examples from its reporting team.</p>
        <h2 id="publishing-and-newsletters-the-easy-way">Publishing and newsletters the easy way</h2>
        <p>Editors can publish a completed report on the website and deliver the same reporting to their existing readers by email.</p>
        <h2 id="understanding-advertising-prices">Understanding advertising prices</h2>
        <p>The guide explains how different pricing arrangements affect the finances of a publication and the experience of readers.</p>
        #{extra}
      </article></main></body></html>
    HTML
  end

  it 'retains prose-supported editorial headings whose generated anchors contain noise words' do
    extract_from_url('https://reports.example/publishing', heading_id_article) do |payload|
      expect(payload['hostAware']).to be(false)
      expect(payload['html']).to include('id="publishing-and-newsletters-the-easy-way"', 'id="understanding-advertising-prices"')
      expect(payload['markdown']).to include('## Publishing and newsletters the easy way', '## Understanding advertising prices')
      expect(payload['markdown'].index('Publishing and newsletters')).to be < payload['markdown'].index('Editors can publish')
    end
  end

  it 'still removes promotional containers, class-marked widgets and non-editorial identifiers' do
    extra = <<~HTML
      <section class="newsletter"><h2 id="newsletter-offers">Newsletter offers</h2><p>Get our promotional messages.</p></section>
      <div class="newsletter"><h2 class="newsletter" id="newsletter-bonus">Newsletter bonus</h2><form><input type="email"><button>Subscribe for the bonus</button></form></div>
      <p>Use the ordinary reporting methods described above.</p>
      <h2 id="newsletter-signup">Join our mailing list</h2><form><input type="email"><button>Subscribe</button></form>
      <aside><h2 id="newsletter-discount">Newsletter discount</h2><p>Unlock a subscription offer.</p></aside>
    HTML
    extract_from_url('https://reports.example/publishing', heading_id_article(extra)) do |payload|
      expect(payload['markdown']).not_to include('Newsletter offers', 'Newsletter bonus', 'Join our mailing list', 'Newsletter discount')
      expect(payload['markdown']).to include('Editors can publish a completed report', 'Understanding advertising prices')
    end
  end

  it 'retains an ordinary prose-supported heading when its CSS class names the editorial topic' do
    paragraph = 'Use the ordinary reporting methods described above.'
    extra = <<~HTML
      <h2 class="newsletter" id="newsletter-bonus">Newsletter bonus</h2>
      <p>#{paragraph}</p>
    HTML
    with_url_page('https://reports.example/publishing', heading_id_article(extra)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      headings = Nokogiri::HTML5.fragment(payload.fetch('html')).css('h2#newsletter-bonus')

      expect(headings.map(&:text)).to eq(['Newsletter bonus'])
      expect(payload.fetch('markdown')).to include('## Newsletter bonus', paragraph)
      expect(payload.fetch('markdown')).to include('## Publishing and newsletters the easy way', '## Understanding advertising prices')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
