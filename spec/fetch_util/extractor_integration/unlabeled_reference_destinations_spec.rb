# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Unlabeled authored reference destinations' do
  include_context 'extractor integration helpers'

  it 'retains overlay and icon destinations without inventing images or exposing closed content' do
    program = "const literal = '![](https://literal.example.test/program)';"
    html = <<~HTML
      <html><head><title>Publication resources</title><meta name="generator" content="MkDocs 1.6"></head><body>
      <main class="md-main"><article class="md-content__inner md-typeset"><h1>Publication resources</h1>
      <h2 id="overview">Complete overview!<a href="#overview"></a></h2>
      <section><a href="/categories/research"><span class="column-background"></span></a>
      <h2>Research resources</h2><p>The complete research description belongs to this publication.</p></section>
      <p>Independent institutions support this publication!<a href="https://institutions.example.test/support"><i class="icon-support"></i></a></p>
      <p><a href="https://resources.example.test/guide#notes"><span></span></a>
      <a href="#references"></a><a href="https://resources.example.test/accessible" aria-label="Accessible resources"></a></p>
      <h2 id="references">Reference destinations</h2><p>Every declared destination remains available to readers.</p>
      <p><img src="https://images.example.test/diagram.png" alt=""></p>
      <details><summary>Closed supporting details</summary><p><a href="https://hidden.example.test/closed"></a>Closed answer remains closed.</p></details>
      <p hidden><a href="https://hidden.example.test/program"></a>Hidden material remains hidden.</p>
      <pre><code>#{program}</code></pre></article></main></body></html>
    HTML

    with_url_page('https://docs.publication.example.test/resources/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')

      %w[https://docs.publication.example.test/categories/research https://institutions.example.test/support
         https://resources.example.test/guide#notes https://docs.publication.example.test/resources/#references].each do |url|
        expect(markdown).to include("[#{url}](#{url})")
        expect(markdown).not_to include("![](#{url})")
      end
      expect(markdown).to include('[Accessible resources](https://resources.example.test/accessible)',
                                  '![](https://images.example.test/diagram.png)', program,
                                  'The complete research description belongs to this publication.',
                                  'Every declared destination remains available to readers.')
      expect(markdown).not_to include('https://docs.publication.example.test/resources/#overview',
                                      'https://hidden.example.test/', 'Closed answer remains closed.')
      expect(markdown).not_to match(%r{(?<!\\)!\[https://institutions\.example\.test/support\]})
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains an unlabeled secondary collection destination without repeating the primary image alias' do
    records = (1..6).map do |number|
      <<~HTML
        <article><section class="inner"><figure><a href="/reports/#{number}"><img src="https://images.example.test/report-#{number}.png" alt="Authored report diagram #{number}"></a></figure>
        <h3><a href="/reports/#{number}">Independent publication report #{number}</a></h3>
        <p>Complete evidence for report #{number} remains available!<a href="https://resources.example.test/record-#{number}"><i class="icon-record"></i></a>
        Its final sentence remains part of this report.</p></section></article>
      HTML
    end
    html = <<~HTML
      <html><head><title>Publication reports</title></head><body><main><h1>Publication reports</h1>
      <section><h2>Research reports</h2>#{records.take(3).join}</section>
      <section><h2>Community reports</h2>#{records.drop(3).join}</section></main></body></html>
    HTML

    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')

      (1..6).each do |number|
        url = "https://resources.example.test/record-#{number}"
        expect(markdown).to include("[#{url}](#{url})", "Independent publication report #{number}"), payload.to_json
        expect(markdown.scan("Authored report diagram #{number}").size).to eq(1)
        expect(markdown).not_to match(%r{(?<!\\)!\[https://resources\.example\.test/record-#{number}\]})
      end
      expect(markdown).to include('Its final sentence remains part of this report.')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
