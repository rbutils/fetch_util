# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil sectioned article fallbacks' do
  include_context 'extractor integration helpers'

  def extract_with_narrow_reader(url, html, selector)
    with_url_page(url, html) do |page|
      extractor_for(true).__send__(:inject_assets, page)
      payload = page.evaluate <<~JS
        (() => {
          const NarrowReadability = function() {};
          NarrowReadability.prototype.parse = function() {
            const root = document.querySelector(#{selector.to_json});
            return {title: document.title, content: root.outerHTML, textContent: root.textContent};
          };
          window.Readability = NarrowReadability;
          return window.FetchUtilExtract.extract({reader_mode: true});
        })()
      JS
      yield payload
    end
  end

  it 'retains every short source-owned campaign section when reader selects only the introduction' do
    sections = (1..12).map do |index|
      <<~HTML
        <section class="campaign-stop"><div class="content-card-text-block">
          <div class="mol-header-block-with-detached-cta"><h2>Campaign stop #{index}</h2>
            <p>Stop #{index}: September #{index}, 12–6pm.</p></div>
          <a href="/tour/stop-#{index}">Visit stop #{index}</a>
        </div></section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Community listening tour</title></head><body><main>
        <section id="intro"><h2>Live your story on tour</h2>
          <p>We are taking our community music program to a series of cities with local events.</p>
          <p>Each gathering has its own venue and calendar for visitors to plan their visit.</p></section>
        #{sections}
        <div class="detached-cta"><h2>Subscribe today</h2><button>Subscribe now</button></div>
      </main></body></html>
    HTML

    extract_with_narrow_reader('https://events.example/tour', html, '#intro') do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Each gathering has its own venue')
      expect(markdown).not_to include('Subscribe today')
      (1..12).each do |index|
        expect(markdown.scan(/^## Campaign stop #{index}$/).length).to eq(1)
        expect(markdown).to include("Stop #{index}: September #{index}", "https://events.example/tour/stop-#{index}")
      end
      expect((1..12).map { |index| markdown.index("Stop #{index}: September #{index}") }).to eq(
        (1..12).map { |index| markdown.index("Stop #{index}: September #{index}") }.sort
      )
    end
  end

  it 'retains link-rich product sections without discarding the reader introduction' do
    sections = (1..12).map do |index|
      <<~HTML
        <section><h2>Capability area #{index}</h2>
          <p>Capability #{index} helps customers analyze independent market signals and plan their next steps.</p>
          <p><a href="/capability/#{index}">Explore capability area #{index} in detail</a> with source-owned context.</p></section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Market capabilities</title></head><body><main>
        <div id="intro"><h1>Market capabilities</h1>
          <p>Our team connects organizations with market infrastructure and independent research.</p>
          <p>Customers use these resources to understand risks and act with confidence.</p></div>
        #{sections}
      </main></body></html>
    HTML

    extract_with_narrow_reader('https://markets.example/about', html, '#intro') do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Customers use these resources')
      (1..12).each do |index|
        expect(markdown).to include("Capability area #{index}", "Capability #{index} helps customers",
                                    "https://markets.example/capability/#{index}")
      end
    end
  end

  it 'keeps a focal article instead of merging unrelated sibling cards' do
    related = (1..12).map do |index|
      <<~HTML
        <section><h2>Other story #{index}</h2>
          <p>Other story #{index} explains a different subject for visitors to browse later.</p>
          <p><a href="/story/#{index}">Read other story #{index}</a> if interested.</p></section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Focal science report</title></head><body><main>
        <article id="focal"><h1>Focal science report</h1>
          <p>This independently verified report describes the focal experiment in substantive detail.</p>
          <p>Scientists repeated the experiment and compared its results with published research.</p></article>
      </main><aside aria-label="Related stories">#{related}</aside></body></html>
    HTML

    extract_with_narrow_reader('https://research.example/articles/focal-science-report', html, '#focal') do |payload|
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('markdown')).to include('Scientists repeated the experiment')
      expect(payload.fetch('markdown')).not_to include('Other story 12 explains')
    end
  end
end
