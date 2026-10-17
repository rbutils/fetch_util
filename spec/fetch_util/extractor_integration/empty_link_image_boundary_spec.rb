# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Empty link and physical image boundaries' do
  include_context 'extractor integration helpers'

  it 'keeps literal punctuation separate from empty links while retaining real resources and programs' do
    program = "const example = '![](https://literal.example.test/program)';"
    html = <<~HTML
      <html><head><title>Publication resources</title><meta name="generator" content="MkDocs 1.6"></head><body>
      <main class="md-main"><article class="md-content__inner md-typeset"><h1>Publication resources</h1>
      <h2 id="control">Give every reader control!<a href="#control"></a></h2>
      <p>Independent sponsors make this publication possible!<a href="https://support.example.test/empty"></a>
      A subsequent sentence retains its own words.</p>
      <p>Inspect the complete diagram!<a href="https://resources.example.test/diagram"><img src="https://images.example.test/diagram.png" alt=""></a></p>
      <p>Read the accompanying overview!<a href="https://resources.example.test/overview" aria-label="Resource overview"></a></p>
      <p><img src="https://images.example.test/standalone.png" alt=""></p>
      <pre><code>#{program}</code></pre>
      <p>The complete resource descriptions and literal program belong to this published article.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://docs.publication.example.test/resources/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')

      expect(markdown).to include('Give every reader control!',
                                  'A subsequent sentence retains its own words.', program,
                                  '![](https://images.example.test/diagram.png)',
                                  '![](https://images.example.test/standalone.png)',
                                  '[Resource overview](https://resources.example.test/overview)')
      expect(markdown).to match(/Independent sponsors make this publication possible\\?!/)
      expect(markdown).not_to include('![](https://support.example.test/empty)', '![](https://docs.publication.example.test/resources/#control)')
      expect(markdown).not_to match(%r{(?<!\\)!\[Resource overview\]\(https://resources\.example\.test/overview\)})
      expect(payload.fetch('html')).to include('https://images.example.test/diagram.png', 'https://images.example.test/standalone.png', program)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not invent image destinations in authored collection descriptions' do
    records = (1..6).map do |number|
      <<~HTML
        <article><h3><a href="/reports/#{number}">Independent publication report #{number}</a></h3>
        <p>Complete context for report #{number} remains available!<a href="https://support.example.test/resource-#{number}"><img src="https://images.example.test/logo-#{number}.png" alt="Publication resource #{number}"></a><a href="https://support.example.test/empty-#{number}"></a>
        Its final sentence still belongs to this report.</p></article>
      HTML
    end
    html = <<~HTML
      <html><head><title>Publication reports</title></head><body><main><h1>Publication reports</h1>
      <section><h2>Research reports</h2>#{records.take(3).join}</section>
      <section><h2>Community reports</h2>#{records.drop(3).join}</section>
      </main></body></html>
    HTML

    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')

      (1..6).each do |number|
        expect(markdown).to include("Independent publication report #{number}")
        expect(markdown).to match(/Complete context for report #{number} remains available\\?!/)
        expect(markdown).to include("[Publication resource #{number}](https://support.example.test/resource-#{number})")
        expect(markdown).not_to match(/(?<!\\)!\[Publication resource #{number}\]\(/)
        expect(payload.fetch('html')).to include("https://images.example.test/logo-#{number}.png")
      end
      expect(markdown).to include('Its final sentence still belongs to this report.')
      expect(markdown).not_to include('![](https://support.example.test/')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'represents a primary image label once while retaining a distinct image-owned reference' do
    records = (1..6).map do |number|
      <<~HTML
        <article><section class="inner"><figure><a href="/reports/#{number}"><img src="https://images.example.test/report-#{number}.png" alt="Authored report diagram #{number}"></a></figure>
        <span>Current report</span><h3><a href="/reports/#{number}">Independent publication report #{number}</a></h3></section>
        <p>The complete context describes the independent research and its published evidence.
        <a href="https://resources.example.test/related-#{number}"><img src="https://images.example.test/related-#{number}.png" alt="Supplemental resource #{number}"></a>
        The final sentence remains part of the report.</p></article>
      HTML
    end
    html = <<~HTML
      <html><head><title>Publication reports</title></head><body><main><h1>Publication reports</h1>
      <section><h2>Research reports</h2>#{records.take(3).join}</section>
      <section><h2>Community reports</h2>#{records.drop(3).join}</section>
      </main></body></html>
    HTML

    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')

      (1..6).each do |number|
        expect(markdown.scan("Authored report diagram #{number}").length).to eq(1)
        expect(markdown).to include("[Independent publication report #{number}](https://publication.example.test/reports/#{number})",
                                    "[Supplemental resource #{number}](https://resources.example.test/related-#{number})")
      end
      expect(markdown).to include('The final sentence remains part of the report.')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
