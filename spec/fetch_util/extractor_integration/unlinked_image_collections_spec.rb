# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Physically owned unlinked image collections' do
  include_context 'extractor integration helpers'

  def collection_people
    ['Alpha Composer', 'Beta Composer', 'Gamma Composer', 'Delta Composer']
  end

  def people_collection(outer_class: 'followed-composers-box', hidden_index: nil)
    cards = collection_people.map.with_index do |name, index|
      hidden = index == hidden_index ? ' style="display:none"' : ''
      <<~HTML
        <div class="person-card"#{hidden}>
          <img src="/people/person-#{index}.webp?edition=full&amp;view=text#portrait" alt="Portrait #{index}">
          <span class="person-name">#{name}</span>
        </div>
      HTML
    end.join
    <<~HTML
      <div class="#{outer_class}">
        <div class="module-header"><div class="module-title">Selected Composers</div></div>
        <div class="person-list">#{cards}</div>
      </div>
    HTML
  end

  def unlinked_collection_document(people:, program: nil)
    recordings = collection_people.map.with_index do |name, index|
      <<~HTML
        <div class="recording-item">
          <div class="recording-image"><img src="/recordings/session-#{index}.webp" alt="Session #{index}"></div>
          <div class="recording-info"><p class="recording-title">Complete Session #{index}</p><p class="recording-person">#{name}</p></div>
        </div>
      HTML
    end.join
    features = ['Private Library', 'Automatic Catalogue', 'Release Reports', 'Complete Discography', 'Independent Archives'].map do |name|
      "<div class=\"feature-card\"><h3 class=\"feature-card-title\"><a " \
        "href=\"https://manual.example.test/library/#{name.downcase.tr(" ", "-")}?edition=full&amp;view=text#record\">#{name}</a></h3>" \
        "<p>#{name} retains complete source records and independent observations on the reader's own server.</p></div>"
    end.join
    literal = program ? "<pre><code class=\"language-html\">#{CGI.escapeHTML(program)}</code></pre>" : ''
    <<~HTML
      <html><head><title>Independent Music Catalogue</title></head><body><div id="root"><div class="landing-page"><main class="landing-main">
        <section class="hero">
          <div class="hero-content"><h1>Your Personal Music Catalogue</h1>
            <p>Open source, self-hosted, and private. Keep a complete catalogue of recordings and follow independent published resources.</p>
            <a class="install-button" href="/install?edition=full&amp;view=text#instructions">How to Install</a>
          </div>
          <div class="hero-image"><div class="hero-example">#{people}
            <div class="published-recordings-box">
              <div class="module-header"><div class="module-title">Recorded Sessions</div></div>
              <div class="recording-list">#{recordings}</div>
            </div>
          </div></div>
        </section>
        <section class="features"><div class="features-grid">#{features}</div></section>
        #{literal}
      </main></div></div></body></html>
    HTML
  end

  def observe_image_collections(html)
    with_url_page('https://catalogue.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(payload.fetch('contentType')).to eq('list')
      expect(native.css('h3').map(&:text)).to eq(
        ['Private Library', 'Automatic Catalogue', 'Release Reports', 'Complete Discography', 'Independent Archives']
      )
      expect(payload.fetch('markdown')).to include('Complete Session 0', 'Complete Session 1', 'Complete Session 2', 'Complete Session 3')
      yield native, payload
    end
  end

  it 'retains every image and independent label in a physically owned followed collection' do
    observe_image_collections(unlinked_collection_document(people: people_collection)) do |native, payload|
      expect(native.css('.person-card').length).to eq(4)
      collection_people.each.with_index do |name, index|
        url = "https://catalogue.example.test/people/person-#{index}.webp?edition=full&view=text#portrait"
        expect(native.css('.person-card img').map { |node| node['src'] }).to include(url)
        expect(native.text.scan(name).length).to eq(2)
        expect(payload.fetch('markdown')).to include(url)
        expect(payload.fetch('markdown').scan(name).length).to eq(2)
      end
      expect(payload.fetch('markdown')).to include('Selected Composers', 'Recorded Sessions')
    end
  end

  it 'keeps complete local labels when only their neutral header class resembles page chrome' do
    observe_image_collections(unlinked_collection_document(people: people_collection(outer_class: 'catalogue-box'))) do |native, payload|
      expect(native.text.scan('Selected Composers').length).to eq(1)
      expect(native.text.scan('Recorded Sessions').length).to eq(1)
      expect(payload.fetch('markdown').scan('Selected Composers').length).to eq(1)
      expect(payload.fetch('markdown').scan('Recorded Sessions').length).to eq(1)
    end
  end

  it 'preserves all visible records without admitting a positively hidden peer' do
    observe_image_collections(unlinked_collection_document(people: people_collection(hidden_index: 1))) do |native, payload|
      expect(native.css('.person-card').length).to eq(3)
      expect(native.css('.person-card img').map { |node| node['src'] }).to eq(
        [0, 2, 3].map { |index| "https://catalogue.example.test/people/person-#{index}.webp?edition=full&view=text#portrait" }
      )
      expect(payload.fetch('markdown')).not_to include('/people/person-1.webp')
      [0, 2, 3].each { |index| expect(payload.fetch('markdown')).to include("/people/person-#{index}.webp") }
    end
  end

  it 'does not admit the same resource shape from actual navigation or toolbar owners' do
    people = "<nav>#{people_collection}</nav>" \
      "<div role=\"toolbar\">#{people_collection(outer_class: "social-composers-box")}</div>"
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      expect(native.css('.person-card')).to be_empty
      expect(payload.fetch('markdown')).not_to include('Selected Composers', '/people/person-0.webp')
    end
  end

  it 'keeps the complete literal collection program outside physical-record admission' do
    program = '<div class="followed-composers-box"><div class="module-header">Literal People</div>' \
      '<div><img src="https://literal.example.test/portrait.webp"><span>Literal Person</span></div></div>'
    observe_image_collections(unlinked_collection_document(people: '', program: program)) do |native, payload|
      expect(native.css('pre').map(&:text)).to include(program)
      expect(native.css('.person-card')).to be_empty
      expect(payload.fetch('markdown')).to include("```\n#{program}\n```")
    end
  end

  it 'does not promote an actual semantic listbox as an informational image collection' do
    people = people_collection.sub('class="person-list"', 'class="person-list" role="listbox"')
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      expect(native.css('.person-card')).to be_empty
      expect(payload.fetch('markdown')).not_to include('Selected Composers', '/people/person-0.webp')
    end
  end

  it 'does not promote semantic option records as ordinary unlinked image records' do
    people = people_collection.gsub('class="person-card"', 'class="person-card" role="option"')
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      expect(native.css('.person-card')).to be_empty
      expect(payload.fetch('markdown')).not_to include('Selected Composers', '/people/person-0.webp')
    end
  end

  it 'preserves independent records that share one complete image destination' do
    people = people_collection.gsub(%r{/people/person-\d+\.webp}, '/people/shared.webp')
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      url = 'https://catalogue.example.test/people/shared.webp?edition=full&view=text#portrait'
      expect(native.css('.person-card').length).to eq(4)
      expect(native.css('.person-card img').map { |node| node['src'] }).to eq([url, url, url, url])
      expect(payload.fetch('markdown').scan(url).length).to eq(4)
      collection_people.each { |name| expect(payload.fetch('markdown').scan(name).length).to eq(2) }
    end
  end

  it 'does not use a partial record proof across an unsafe image peer' do
    people = people_collection.sub('/people/person-0.webp?edition=full&amp;view=text#portrait', 'javascript:collection_control()')
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      expect(native.css('.person-card')).to be_empty
      expect(payload.fetch('markdown')).not_to include('Selected Composers', '/people/person-1.webp', 'collection_control')
    end
  end

  it 'keeps complete programs and adjacent images without promoting incomplete image records' do
    program = 'complete_record_program()'
    people = people_collection.sub('</span>', "</span><pre><code>#{program}</code></pre>")
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      expect(native.css('.person-card')).to be_empty
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include("```\n#{program}\n```")
      expect(payload.fetch('markdown')).not_to include('Selected Composers')
      collection_people.each.with_index do |_, index|
        url = "https://catalogue.example.test/people/person-#{index}.webp?edition=full&view=text#portrait"
        expect(native.css('img').map { |image| image['src'] }).to include(url)
        expect(payload.fetch('markdown')).to include(url)
      end
    end
  end

  it 'keeps focus and event controls outside informational image-record ownership' do
    people = people_collection.gsub('class="person-card"', 'class="person-card" tabindex="0"') +
             people_collection.gsub('class="person-card"', 'class="person-card" onclick="collection_control()"')
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      expect(native.css('.person-card')).to be_empty
      expect(payload.fetch('markdown')).not_to include('Selected Composers', '/people/person-0.webp', 'collection_control')
    end
  end

  it 'rejects a partial collection proof when only one source record handles an event' do
    people = people_collection.sub('class="person-card"', 'class="person-card" onclick="collection_control()"')
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      expect(native.css('.person-card')).to be_empty
      expect(payload.fetch('markdown')).not_to include('Selected Composers', '/people/person-0.webp', 'collection_control')
    end
  end

  it 'retains original event boundaries on record descendants and local labels through sanitization' do
    people = people_collection.gsub('class="person-name"', 'class="person-name" onclick="collection_control()"') +
             people_collection.gsub('class="module-title"', 'class="module-title" onfocus="collection_control()"')
    observe_image_collections(unlinked_collection_document(people: people)) do |native, payload|
      expect(native.css('.person-card')).to be_empty
      expect(payload.fetch('markdown')).not_to include('Selected Composers', '/people/person-0.webp', 'collection_control')
    end
  end
end
