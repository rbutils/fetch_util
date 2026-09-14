# frozen_string_literal: true

RSpec.describe FetchUtil::Extractor, 'visible list metadata references' do
  include_context 'extractor integration helpers'

  it 'keeps short topic destinations with their visible context instead of promoting them to news records' do
    cards = (1..6).map do |number|
      "<div class='Panel_root'><div class='Layout_tags'><ul class='CardTagList_tags'><li>" \
        "<span class='CardTag_container'><a class='CardTag_tag' href='/topic/#{number}'>Region #{number}</a></span>" \
        "</li></ul></div><div><h3><a href='/story/#{number}'>Independent regional investigation #{number}</a></h3></div>" \
        "<p>Reporters explain the evidence behind this regional story number #{number}.</p></div>"
    end.join
    html = "<html><body><main><h1>Regional news</h1>#{cards}</main>" \
           '<nav><a rel="tag" href="/menu-topic">Navigation topic</a></nav>' \
           '<div hidden><a rel="tag" href="/hidden-topic">Hidden topic</a></div></body></html>'
    with_url_page('https://publisher.example/', html) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      (1..6).each do |number|
        expect(markdown).to include("[Region #{number}](https://publisher.example/topic/#{number})",
                                    "https://publisher.example/story/#{number}")
      end
      expect(markdown.lines.grep(/^- \[Region \d+\]/)).to be_empty
      expect(markdown).not_to include('/menu-topic', '/hidden-topic')
    end
  end

  it 'does not duplicate a reference already rendered in its own description' do
    cards = (1..6).map do |number|
      "<article><h3><a href='/story/#{number}'>Independent regional investigation #{number}</a></h3>" \
        "<p>Reporting for <a rel='tag' href='/category/#{number}'>Region #{number}</a> includes detailed local evidence.</p></article>"
    end.join
    html = "<html><body><main><h1>Regional news</h1>#{cards}</main></body></html>"
    with_url_page('https://publisher.example/', html) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      (1..6).each { |number| expect(markdown.scan("https://publisher.example/category/#{number})").length).to eq(1) }
    end
  end

  it 'adds unrepresented references without replacing a selected multi-section layout' do
    sections = (1..2).map do |section|
      cards = (1..4).map do |number|
        key = "#{section}-#{number}"
        "<article><h3><a href='/story/#{key}'>Regional investigation #{key}</a></h3>" \
          "<p>Independent reporting explains this district's current situation in detail.</p>" \
          "<ul class='CardTagList_tags'><li><a class='CardTag_tag' href='/topic/#{key}'>R#{number}</a></li></ul></article>"
      end.join
      "<section><h2>Regional section #{section}</h2>#{cards}</section>"
    end.join
    with_url_page('https://publisher.example/', "<html><body><main><h1>Regional news</h1>#{sections}</main></body></html>") do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      expect(markdown).to include('## Regional section 1', '## Regional section 2')
      (1..2).each do |section|
        (1..4).each { |number| expect(markdown).to include("https://publisher.example/topic/#{section}-#{number}") }
      end
      expect(markdown.lines.grep(/^- \[Regional investigation/).length).to eq(8)
    end
  end

  it 'recognizes a named metadata label wrapped in a typography paragraph' do
    cards = (1..6).map do |number|
      "<article><h3><a href='/story/#{number}'>Independent regional investigation #{number}</a></h3>" \
        '<p>Local reporters explain the evidence and its significance for the community.</p></article>'
    end.join
    html = '<html><body><main><h1>Regional news</h1><div class="Layout_tags"><ul class="CardTagList_tags"><li>' \
           '<a class="CardTag_tag" href="/topic/insurance"><p><span hidden>Topic:</span>Insurance</p></a>' \
           "</li></ul></div>#{cards}</main></body></html>"
    with_url_page('https://publisher.example/', html) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      expect(markdown).to include('[Insurance](https://publisher.example/topic/insurance)')
      expect(markdown.scan('https://publisher.example/topic/insurance)').length).to eq(1)
    end
  end
end
