# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Authored reciprocal reference links' do
  include_context 'extractor integration helpers'

  def annotated_html(duplicate: false, foreign: false)
    prose = (1..13).map do |index|
      "<p>Observation #{index} explains the published argument and its supporting evidence in detail. " \
        'The reader can inspect its annotation ' \
        "<a class='footnote-reference' id='reference-#{index}' href='#annotation-#{index}'>#{index}</a>.</p>"
    end.join
    annotations = (1..13).map do |index|
      target = foreign && index == 1 ? 'https://other.example.test/argument#reference-1' : "#reference-#{index}"
      "<div role='doc-footnote'><a class='footnote-return' id='annotation-#{index}' href='#{target}'>#{index}</a>" \
        "<p>Annotation #{index} supplies the authored explanation and the evidence behind the corresponding observation.</p></div>"
    end.join
    repeated = duplicate ? "<span id='annotation-1'>An ambiguous second target</span>" : ''
    <<~HTML
      <!doctype html><html><head><title>Annotated argument</title><meta name='generator' content='Sphinx'></head><body>
      <main class='document'><h1>Annotated argument</h1>#{prose}<section>#{annotations}#{repeated}</section>
      <div><a id='utility-link' href='#missing-target'>¶</a></div></main></body></html>
    HTML
  end

  it 'preserves all in-text and return relationships with their identifiers and source order' do
    with_url_page('https://publication.example.test/argument', annotated_html) do |page|
      result = extract(page)
      document = Nokogiri::HTML5.fragment(result.fetch('html'))

      (1..13).each do |index|
        expect(document.at_css("#reference-#{index}")['href']).to eq("https://publication.example.test/argument#annotation-#{index}")
        expect(document.at_css("#annotation-#{index}")['href']).to eq("https://publication.example.test/argument#reference-#{index}")
      end
      expect(document.css('[role="doc-footnote"] p').map(&:text)).to eq((1..13).map do |index|
        "Annotation #{index} supplies the authored explanation and the evidence behind the corresponding observation."
      end)
      expect(result.fetch('markdown')).to include('[13](https://publication.example.test/argument#reference-13)')
      expect(document.at_css('#utility-link')).to be_nil
    end
  end

  it 'does not use an ambiguous target identifier to exempt a short return control' do
    with_url_page('https://publication.example.test/argument', annotated_html(duplicate: true)) do |page|
      document = Nokogiri::HTML5.fragment(extract(page).fetch('html'))

      expect(document.css('a#annotation-1')).to be_empty
      expect(document.text).to include('Annotation 1 supplies the authored explanation')
      expect(document.at_css('#annotation-13')['href']).to eq('https://publication.example.test/argument#reference-13')
    end
  end

  it 'does not treat a foreign destination as the reciprocal target on the current document' do
    with_url_page('https://publication.example.test/argument', annotated_html(foreign: true)) do |page|
      document = Nokogiri::HTML5.fragment(extract(page).fetch('html'))

      expect(document.at_css('a#annotation-1')['href']).to eq('https://other.example.test/argument#reference-1')
      expect(document.text).to include('Annotation 1 supplies the authored explanation')
      expect(document.at_css('#annotation-13')['href']).to eq('https://publication.example.test/argument#reference-13')
    end
  end
end
