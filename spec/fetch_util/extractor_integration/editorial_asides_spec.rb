# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor, "homepage editorial columns" do
  include_context "extractor integration helpers"

  def editorial_main_cards(prefix)
    (1..4).map do |number|
      <<~HTML
        <article class="story">
          <h3><a href="/reports/#{prefix}-#{number}">#{prefix} reporting team publishes update #{number}</a></h3>
          <p>The local reporting team explains the evidence and the next steps for residents.</p>
        </article>
      HTML
    end.join
  end

  def editorial_side_cards(count)
    (1..count).map do |number|
      title = "Independent correspondents report development #{number}"
      content = number == 1 ? "<h3>#{title}</h3><p>The first report includes a locally owned explanation.</p>" : title
      "<a class='sidebar-item' href='/reports/side-#{number}'>#{content}</a>"
    end.join
  end

  def editorial_homepage(sidebar)
    <<~HTML
      <html><head><title>City bulletin</title></head><body>
        <h1>City bulletin</h1>
        <main><section><h2>Morning reports</h2>#{editorial_main_cards("Morning")}</section></main>
        #{sidebar}
        <section><h2>Evening reports</h2>#{editorial_main_cards("Evening")}</section>
      </body></html>
    HTML
  end

  it 'retains a proved editorial sidebar with its local context between the surrounding reports' do
    sidebar = <<~HTML
      <aside class="sidebar popular" role="complementary" aria-label="Editorial sidebar">
        <h2>Latest updates</h2>
        <div class="sidebar-content">#{editorial_side_cards(5)}</div>
        <div class="advertisement"><a href="/advertisement"><h3>Paid promotion for an unrelated service</h3></a></div>
        <nav><a href="/account">Account navigation inside the column</a></nav>
      </aside>
    HTML

    with_url_page('https://bulletin.example/', editorial_homepage(sidebar)) do |page|
      original = page.evaluate('document.body.outerHTML')
      payload = described_class.new.extract(page)
      markdown = payload.fetch('markdown')

      expect(payload.fetch('contentType')).to eq('list')
      expect(markdown).to include('Latest updates', 'The first report includes a locally owned explanation.')
      expect(markdown.scan(/Independent correspondents report development \d+/)).to eq(
        (1..5).map { |number| "Independent correspondents report development #{number}" }
      )
      (1..5).each do |number|
        expect(markdown).to include("https://bulletin.example/reports/side-#{number}")
      end
      expect(markdown.index('/reports/Morning-4')).to be < markdown.index('/reports/side-1')
      expect(markdown.index('/reports/side-5')).to be < markdown.index('/reports/Evening-1')
      expect(markdown).not_to include('Paid promotion', 'Account navigation inside the column')
      expect(page.evaluate('document.body.outerHTML')).to eq(original)
    end
  end

  it 'keeps explicit navigation and hidden asides out of homepage records' do
    sidebar = <<~HTML
      <aside role="navigation"><h2>Site navigation</h2>#{editorial_side_cards(4)}</aside>
      <aside hidden><h2>Inactive column</h2>#{editorial_side_cards(4)}</aside>
      <aside><a href="/reference">A lone supplementary reference without a collection</a></aside>
    HTML

    with_url_page('https://bulletin.example/', editorial_homepage(sidebar)) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')

      expect(markdown).to include('Morning reporting team publishes update 1')
      expect(markdown).not_to include('Independent correspondents', 'Inactive column', 'A lone supplementary reference')
    end
  end

  it 'does not promote an article sidebar into the article body' do
    paragraphs = Array.new(6) do
      '<p>The investigation follows the council debate and explains how the evidence was verified. ' \
        'Residents described the decisions that will affect their neighbourhood over the coming months.</p>'
    end.join
    html = <<~HTML
      <html><head><title>Council investigation</title></head><body>
        <main><article><h1>Council investigation</h1>#{paragraphs}</article></main>
        <aside><h2>Related reports</h2>#{editorial_side_cards(5)}</aside>
      </body></html>
    HTML

    with_url_page('https://bulletin.example/reports/council-investigation', html) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')

      expect(markdown).to include('The investigation follows the council debate')
      expect(markdown).not_to include('Independent correspondents', 'Related reports')
    end
  end

  it 'retains every materialized record in a large editorial column in DOM order' do
    sidebar = "<aside class='sidebar'><h2>Latest updates</h2>#{editorial_side_cards(125)}</aside>"

    with_url_page('https://bulletin.example/', editorial_homepage(sidebar)) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      destinations = markdown.scan(%r{https://bulletin\.example/reports/side-\d+})

      expect(destinations).to eq((1..125).map { |number| "https://bulletin.example/reports/side-#{number}" })
    end
  end

  it 'recognizes an editorial column split into sibling one-story asides' do
    panels = (1..4).map do |number|
      "<aside><article><h3><a href='/broadcast/#{number}'>Regional news broadcast number #{number}</a></h3>" \
        "<p>Verified reporting from the local newsroom number #{number}.</p></article></aside>"
    end.join
    sidebar = "<div class='column'>#{panels}<aside hidden><h3><a href='/inactive'>Inactive broadcast headline</a></h3></aside></div>"

    with_url_page('https://bulletin.example/', editorial_homepage(sidebar)) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      expect(markdown.scan(%r{https://bulletin\.example/broadcast/\d+})).to eq(
        (1..4).map { |number| "https://bulletin.example/broadcast/#{number}" }
      )
      expect(markdown).not_to include('Inactive broadcast headline')
    end
  end
end
