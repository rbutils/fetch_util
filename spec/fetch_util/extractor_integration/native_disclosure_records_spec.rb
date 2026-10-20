# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Complete native disclosure record catalogues' do
  include_context 'extractor integration helpers'

  def catalogue_record(number)
    <<~HTML
      <article><p>Research observation #{number}</p>
      <p>Recorded: <time datetime='2026-02-#{format("%02d", number)}'>2026-02-#{format("%02d", number)}</time></p>
      <p>The complete description of observation #{number} retains its measurements, assumptions and independently documented practical implications.</p>
      <p>The specific caveat for observation #{number} is that the physical measurement remains distinct from every other record.</p>
      <p><a href='/evidence/#{number}'>Evidence for observation #{number}</a> and
      <a href='/shared-method'>Shared research method</a></p></article>
    HTML
  end

  def catalogue_group(label, numbers, open: true)
    "<details#{open ? " open" : ""}><summary>#{label}</summary><div>#{numbers.map { |number| catalogue_record(number) }.join}</div></details>"
  end

  def catalogue_page(groups, extra: '')
    <<~HTML
      <html><head><title>Public research catalogue | Publication</title>
      <link rel='canonical' href='https://records.publication.example.test/catalogue/'>
      <meta property='og:type' content='website'>
      <meta property='og:url' content='https://records.publication.example.test/catalogue/'>
      <meta property='og:title' content='Public research catalogue | Publication'>
      <meta name='description' content='Complete independently documented research records and their evidence.'></head>
      <body><header><nav><a href='/'>Publication home</a></nav></header><main><main>
      <h1>Public research catalogue</h1>
      <p>These complete research records retain their original observations, caveats and independent supporting resources.</p>
      #{groups}#{extra}
      <section><h2>Contribute another observation</h2><p>Contact the catalogue editors to document another independently observed result.</p>
      <a href='/contribute'>Submit an independently observed result</a></section>
      </main></main><footer>Publication footer</footer></body></html>
    HTML
  end

  def expect_complete_catalogue(payload)
    html = Nokogiri::HTML5(payload.fetch('html'))
    expect(html.css('article').map { |article| article.at_css('p').text }).to eq((1..4).map { |number| "Research observation #{number}" })
    (1..4).each do |number|
      expect(payload.fetch('markdown')).to include(
        "Research observation #{number}",
        "The complete description of observation #{number} retains its measurements, assumptions and independently documented practical implications.",
        "The specific caveat for observation #{number} is that the physical measurement remains distinct from every other record.",
        "https://records.publication.example.test/evidence/#{number}"
      )
    end
    expect(payload.fetch('markdown').scan('https://records.publication.example.test/shared-method').length).to eq(4)
    expect(payload.fetch('markdown')).to include(
      'Public research catalogue', 'Published observations', 'Revised observations',
      'Contact the catalogue editors to document another independently observed result.',
      'https://records.publication.example.test/contribute'
    )
    expect(payload.fetch('byline')).to be_nil
    expect(payload.fetch('publishedTime')).to be_nil
  end

  it 'retains every record, repeated resource and peer section in a nested main catalogue' do
    groups = catalogue_group('Published observations', [1, 2]) + catalogue_group('Revised observations', [3, 4])
    with_url_page('https://records.publication.example.test/catalogue/', catalogue_page(groups)) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect_complete_catalogue(extract(page))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains visible literal programs and closed summaries without exposing hidden alternate views' do
    groups = catalogue_group('Published observations', [1, 2]) + catalogue_group('Revised observations', [3, 4])
    groups += catalogue_group('Archived observations', [5], open: false)
    program = "<details open>\n  <article>Literal catalogue syntax</article>\n</details>"
    extra = "<pre><code>#{CGI.escapeHTML(program)}</code></pre>" \
            "<div style='display:none'><table><tr><td>Hidden alternate table value</td></tr></table>#{catalogue_record(6)}</div>"
    with_url_page('https://records.publication.example.test/catalogue/', catalogue_page(groups, extra: extra)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect_complete_catalogue(payload)
      expect(Nokogiri::HTML5(payload.fetch('html')).css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include(program, 'Archived observations')
      expect(payload.fetch('markdown')).not_to include('Research observation 5', 'Research observation 6', 'Hidden alternate table value')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps an independently declared article instead of promoting navigation disclosure records' do
    groups = catalogue_group('Navigation archive', [1, 2]) + catalogue_group('Navigation revisions', [3, 4])
    paragraph = 'This independently authored report explains the research methodology and preserves the complete evidence supporting its conclusions.'
    html = <<~HTML
      <html><head><title>An independently authored report</title><meta property='og:type' content='article'>
      <meta property='article:published_time' content='2026-01-02T12:00:00Z'><meta name='author' content='Independent Author'></head>
      <body><nav>#{groups}</nav><main><article><h1>An independently authored report</h1><p>#{paragraph}</p>
      <p>The complete second paragraph records the limitations, concrete observations and independently reproducible procedure for this particular report.</p></article></main></body></html>
    HTML
    with_url_page('https://records.publication.example.test/reports/one', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('markdown')).to include('An independently authored report', paragraph)
      expect(payload.fetch('markdown')).not_to include('Research observation 1', 'Research observation 4')
      expect(payload.fetch('byline')).to eq('Independent Author')
      expect(payload.fetch('publishedTime')).to eq('2026-01-02T12:00:00Z')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains independent trailing reference containers and their physical repeated destinations' do
    groups = catalogue_group('Published observations', [1, 2]) + catalogue_group('Revised observations', [3, 4])
    trailing = <<~HTML
      <div class='floating-reference'><a href='/supporting-evidence'><span><i></i></span><span>Follow-up evidence</span></a><div title='Close'><i></i></div></div>
      <div><a href='/supporting-evidence'>Independently repeated evidence</a></div>
    HTML
    html = catalogue_page(groups).sub('</body>', "#{trailing}</body>")
    with_url_page('https://records.publication.example.test/catalogue/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect_complete_catalogue(payload)
      links = Nokogiri::HTML5(payload.fetch('html')).css('a[href="https://records.publication.example.test/supporting-evidence"]')
      expect(links.map { |link| link.text.strip }).to eq(['Follow-up evidence', 'Independently repeated evidence'])
      expect(payload.fetch('markdown').scan('https://records.publication.example.test/supporting-evidence').length).to eq(2)
      expect(payload.fetch('markdown')).to include('Follow-up evidence', 'Independently repeated evidence')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
