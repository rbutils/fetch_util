# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'support/extractor_integration_helpers'

RSpec.describe 'Authored resources and playback controls' do
  include_context 'extractor integration helpers'

  it 'retains two independent Learn more resources in source order with complete prose and programs' do
    url = 'https://publication.example.test/research/resources/'
    destination = 'https://publication.example.test/solutions/'
    program = "Learn more\nPlay\nSettings\nVolume 37%"
    html = <<~HTML
      <html><head><title>Published research resources</title></head><body>
      <main><article class="entry-content"><h1>Published research resources</h1>
      <p>This published guide explains how independent teams can choose a complete research workflow.
      Each section contains its own authored explanation and resource destination. Readers need both
      references, including their repeated labels, because the sections describe different practical
      decisions. The complete program is published separately and every line remains literal text.</p>
      <section><h2>Research solutions</h2><p>Choose the resource for the first independent workflow.</p>
      <div><a href="/solutions/">Learn more</a></div></section>
      <section><h2>Project support</h2><p>Use the independently authored resource after reading the support guidance.</p>
      <div><a href="/solutions/"><span>Learn more</span></a></div></section>
      <pre><code>#{program}</code></pre>
      <div hidden><a href="/unpublished/">Learn more</a></div>
      <p>The closing explanation belongs to this guide and follows both complete resource sections.</p>
      </article></main></body></html>
    HTML
    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      document = Nokogiri::HTML5(payload.fetch('html'))
      references = document.css('a').select { |node| node['href'] == destination }
      expect(references.map { |node| node.text.strip }).to eq(['Learn more', 'Learn more'])
      expect(payload.fetch('markdown').scan("[Learn more](#{destination})").length).to eq(2)
      expect(document.css('pre code').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include("```\n#{program}\n```",
                                                   'Choose the resource for the first independent workflow.',
                                                   'Use the independently authored resource after reading the support guidance.',
                                                   'The closing explanation belongs to this guide')
      expect(payload.fetch('html')).not_to include('/unpublished/')
      expect(payload.fetch('markdown')).not_to include('/unpublished/')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'removes genuine playback controls while preserving identical literal program values' do
    program = "Play\nPause\nSettings\nVolume 37%\nLearn more"
    html = <<~HTML
      <html><head><title>Published media guide</title></head><body><main><article>
      <h1>Published media guide</h1><p>This complete guide explains the declared media resource and
      publishes the control words as a literal program. The program remains authored content even
      when its lines happen to match user-interface labels. The media controls themselves are
      separate interface elements and do not belong to the guide's readable prose.</p>
      <div class="video-js"><video src="/lesson.mp4" poster="/lesson.jpg" controls></video>
      <div class="vjs-control-bar"><button>Play</button><button>Pause</button>
      <span>Settings</span><span>Volume 37%</span></div></div>
      <pre><code>#{program}</code></pre>
      <p>The complete closing paragraph remains after the media and its literal program.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://publication.example.test/research/media/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      document = Nokogiri::HTML5(payload.fetch('html'))
      expect(document.css('.vjs-control-bar, button')).to be_empty
      expect(document.css('pre code').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include("```\n#{program}\n```",
                                                   'The complete closing paragraph remains')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
