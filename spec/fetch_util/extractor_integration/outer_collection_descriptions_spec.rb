# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Outer authored collection descriptions' do
  include_context 'extractor integration helpers'

  it 'retains complete card-owned paragraphs outside an inner linked title wrapper' do
    records = (1..6).map do |number|
      <<~HTML
        <article><section class="inner"><figure><a href="/reports/#{number}"><img src="https://images.example.test/report-#{number}.png" alt="Authored report diagram #{number}"></a></figure>
        <h3><a href="/reports/#{number}">Independent publication report #{number}</a></h3></section>
        <p>Complete evidence for report #{number} remains available!<a href="https://resources.example.test/record-#{number}"><i class="icon-record"></i></a>
        Its final sentence remains part of this report.</p></article>
      HTML
    end
    html = <<~HTML
      <html><head><title>Publication reports</title></head><body><main><h1>Publication reports</h1>
      <section><h2>Research reports</h2>#{records.take(3).join}</section>
      <section><h2>Community reports</h2>#{records.drop(3).join}</section></main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      (1..6).each do |number|
        expect(markdown).to match(/Complete evidence for report #{number} remains available\\?!/)
        expect(markdown).to include("https://resources.example.test/record-#{number}")
        expect(markdown.scan("Authored report diagram #{number}").size).to eq(1)
      end
      expect(markdown.scan('Its final sentence remains part of this report.').size).to eq(6)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves short outer prose and its authored record references without exposing hidden details' do
    records = (1..6).map do |number|
      <<~HTML
        <article><section class="inner"><figure><a href="/reports/#{number}"><img src="https://images.example.test/report-#{number}.png" alt="Distinct report diagram #{number}"></a></figure>
        <h3><a href="/reports/#{number}">Documented community report #{number}</a></h3></section>
        <p>Read <a href="/reports/#{number}">the report #{number}</a>.</p>
        <p>See <a href="/reports/#{number == 6 ? 1 : number + 1}">the next record #{number}</a>.</p>
        <p hidden>Unpublished outer prose #{number} must remain hidden.</p>
        <details><summary>Archived evidence #{number}</summary><p>Closed evidence #{number} must remain closed.</p></details>
        </article>
      HTML
    end
    html = <<~HTML
      <html><head><title>Documented community reports</title></head><body><main><h1>Documented community reports</h1>
      <section><h2>Current research</h2>#{records.take(3).join}</section>
      <section><h2>Community records</h2>#{records.drop(3).join}</section></main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      (1..6).each do |number|
        next_number = number == 6 ? 1 : number + 1
        expect(markdown).to include("Read [the report #{number}](https://publication.example.test/reports/#{number}).")
        expect(markdown).to include("See [the next record #{number}](https://publication.example.test/reports/#{next_number}).")
        expect(markdown.scan("Distinct report diagram #{number}").size).to eq(1)
        expect(markdown).to include("Archived evidence #{number}")
        expect(markdown).not_to include("Unpublished outer prose #{number}", "Closed evidence #{number}")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
