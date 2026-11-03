# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'

RSpec.describe 'Physically owned short section leads' do
  include_context 'extractor integration helpers'

  def section_lead_document(content)
    features = ['Private Notes', 'Complete Archive', 'Published Reports', 'Source Records', 'Independent Copies'].map do |name|
      <<~HTML
        <article class="feature-card"><h3><a href="https://manual.example.test/library/#{name.downcase.tr(" ", "-")}?edition=full&amp;view=text#record">#{name}</a></h3>
          <p>#{name} keeps complete independent material and original observations on the reader's own server.</p>
        </article>
      HTML
    end.join
    <<~HTML
      <html><head><title>Independent Notebook</title></head><body><main>
        <section><h1>Keep an independent notebook</h1>
          <p>Keep complete notes, publish original observations and retain every source-owned detail on your own server.</p>
          <a href="/install?edition=full&amp;view=text#instructions">Installation instructions</a>
        </section>
        #{content}
        <section class="features"><div class="feature-grid">#{features}</div></section>
      </main></body></html>
    HTML
  end

  def section_with_lead(lead, heading: 'Working principles', attributes: '')
    <<~HTML
      <section #{attributes}><h2>#{heading}</h2>#{lead}
        <div><p>Keep complete independent observations and every authored detail on a server that remains under the reader's control.</p>
          <p>Preserve the complete archive and make every original observation available in its authored order.</p></div>
      </section>
    HTML
  end

  def observe_section_leads(html)
    with_url_page('https://notebook.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(payload.fetch('contentType')).to eq('list')
      expect(native.css('h3').map(&:text)).to eq(
        ['Private Notes', 'Complete Archive', 'Published Reports', 'Source Records', 'Independent Copies']
      )
      expect(payload.fetch('markdown')).to include(
        'Private Notes', 'Complete Archive', 'Published Reports', 'Source Records', 'Independent Copies'
      )
      yield native, payload
    end
  end

  it 'retains the complete short paragraph owned by its heading and following prose' do
    reading = 'One timeline, entirely yours.'
    content = section_with_lead("<p>#{reading}</p>")
    observe_section_leads(section_lead_document(content)) do |native, payload|
      expect(native.css('section > p').map(&:text)).to include(reading)
      markdown = payload.fetch('markdown')
      expect(markdown).to include(reading)
      expect(markdown.index('Working principles')).to be < markdown.index(reading)
      expect(markdown.index(reading)).to be < markdown.index('Keep complete independent observations')
    end
  end

  it 'preserves complete inline emphasis and a full destination in a short owned lead' do
    lead = '<p><em>Entirely yours.</em> <a href="/guide?edition=full&amp;view=text#lead"><strong>Keep it.</strong></a></p>'
    observe_section_leads(section_lead_document(section_with_lead(lead))) do |native, payload|
      expect(native.css('section > p').map(&:text)).to include('Entirely yours. Keep it.')
      expect(payload.fetch('markdown')).to include(
        '_Entirely yours._', '**Keep it.**', 'https://notebook.example.test/guide?edition=full&view=text#lead'
      )
    end
  end

  it 'keeps independently authored equal short leads in both physical sections' do
    reading = 'An independent observation.'
    first = section_with_lead("<p>#{reading}</p>", heading: 'Original observations')
    second = section_with_lead("<p>#{reading}</p>", heading: 'Independent observations')
    observe_section_leads(section_lead_document(first + second)) do |native, payload|
      expect(native.css('section > p').map(&:text).count(reading)).to eq(2)
      expect(payload.fetch('markdown').scan(reading).size).to eq(2)
    end
  end

  it 'keeps actual navigation and forms outside owned short-lead admission' do
    navigation = "<nav>#{section_with_lead("<p>Navigation-only lead.</p>")}</nav>"
    form = "<form>#{section_with_lead("<p>Form-only lead.</p>")}</form>"
    dialog = section_with_lead('<p>Dialog-only lead.</p>', attributes: 'role="dialog"')
    observe_section_leads(section_lead_document(navigation + form + dialog)) do |_native, payload|
      expect(payload.fetch('markdown')).not_to include('Navigation-only lead.', 'Form-only lead.', 'Dialog-only lead.')
    end
  end

  it 'excludes positively hidden and closed-body leads while preserving visible content' do
    hidden = section_with_lead('<p style="display:none">Hidden-only lead.</p>')
    closed = "<details><summary>Ordinary summary</summary>#{section_with_lead("<p>Closed-only lead.</p>")}</details>"
    observe_section_leads(section_lead_document(hidden + closed)) do |_native, payload|
      expect(payload.fetch('markdown')).not_to include('Hidden-only lead.', 'Closed-only lead.')
      expect(payload.fetch('markdown')).to include('Keep complete independent observations')
    end
  end

  it 'does not independently duplicate a short paragraph already owned by a selected record' do
    reading = 'A feature-owned observation.'
    html = section_lead_document('').sub('<article class="feature-card">', "<article class=\"feature-card\"><p>#{reading}</p>")
    observe_section_leads(html) do |native, payload|
      expect(native.css('article.feature-card > p').map(&:text)).to include(reading)
      expect(payload.fetch('markdown').scan(reading).size).to be <= 1
    end
  end
end
