# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Subscription component ownership' do
  include_context 'extractor integration helpers'

  def subscription_component(extra = '')
    <<~HTML
      <section id="publication-signup">
        <h4>Subscribe to the independent briefing</h4>
        <div>A weekly editorial digest.</div>
        <form><input type="email" name="email"><button type="submit">Subscribe</button></form>
        <p>By subscribing, you agree to our <a href="/terms">Terms</a> and <a href="/privacy">Privacy Policy</a>.</p>
        #{extra}
      </section>
    HTML
  end

  def reporting_html(component)
    paragraphs = (1..12).map do |index|
      "<p>Reporting paragraph #{index} describes the published findings, records their limitations, and preserves independent evidence.</p>"
    end.join
    <<~HTML
      <html><head><title>Independent reporting</title></head><body>
        <article><h1>Independent reporting</h1><div itemprop="articleBody">#{paragraphs}
          #{component}</div>
        </article>
      </body></html>
    HTML
  end

  it 'removes an owned signup component while retaining reporting and original source' do
    html = reporting_html(subscription_component)
    with_url_page('https://publication.example.test/report', html) do |page|
      result = extract(page)

      (1..12).each { |index| expect(result['markdown']).to include("Reporting paragraph #{index}") }
      expect(result['markdown']).not_to include('Subscribe to the independent briefing', 'By subscribing')
      expect(page.evaluate("document.querySelector('#publication-signup form') !== null")).to be(true)
    end
  end

  it 'preserves quoted reporting and code even inside a similarly structured component' do
    material = '<blockquote><p>The investigation quotes the privacy policy and subscription terms as primary evidence.</p></blockquote>' \
               '<pre><code>subscribe_to_stream()</code></pre>'
    with_url_page('https://publication.example.test/report', reporting_html(subscription_component(material))) do |page|
      result = extract(page)

      expect(result['markdown']).to include('The investigation quotes the privacy policy', 'subscribe_to_stream()')
    end
  end

  it 'preserves an authored paragraph rather than deleting a mixed subscription section' do
    material = '<p>This authored section documents the pricing analysis and links the argument to its original evidence.</p>'
    with_url_page('https://publication.example.test/report', reporting_html(subscription_component(material))) do |page|
      result = extract(page)

      expect(result['markdown']).to include('This authored section documents the pricing analysis')
    end
  end

  it 'uses unique original controls when visibility pruning has removed a hidden form' do
    component = subscription_component.sub('<form>', '<form style="display:none">')
    with_url_page('https://publication.example.test/report', reporting_html(component)) do |page|
      result = extract(page)

      expect(result['markdown']).to include('Reporting paragraph 12')
      expect(result['markdown']).not_to include('Subscribe to the independent briefing', 'By subscribing')
      expect(page.evaluate("document.querySelector('#publication-signup input').type")).to eq('email')
    end
  end

  it 'preserves an invitation with legal links when no source recipient controls exist' do
    component = subscription_component.sub(%r{<form>.*?</form>}m, '')
    with_url_page('https://publication.example.test/report', reporting_html(component)) do |page|
      result = extract(page)

      expect(result['markdown']).to include('Subscribe to the independent briefing')
    end
  end

  it 'recognizes the exclusive checkbox consent label after recipient controls are pruned' do
    component = subscription_component.sub('<form>', '<div><input type="checkbox"><p>We may send offers and promotions.</p></div><form>')
    with_url_page('https://publication.example.test/report', reporting_html(component)) do |page|
      result = extract(page)

      expect(result['markdown']).to include('Reporting paragraph 12')
      expect(result['markdown']).not_to include('By subscribing', 'We may send offers and promotions')
    end
  end
end
