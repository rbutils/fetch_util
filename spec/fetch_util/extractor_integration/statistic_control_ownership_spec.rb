# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'support/extractor_integration_helpers'

RSpec.describe 'Numeric statistics and playback-control ownership' do
  include_context 'extractor integration helpers'

  def statistic_reference(content)
    <<~HTML
      <html><head><title>Timing Reference</title></head><body><main><article>
      <h1>Timing Reference</h1>
      <p>This published report retains the complete numerical results of an independent measurement.
      Every labelled value belongs to the report, including repeated values that happen to resemble
      a playback timestamp. The associated source reference and literal program are independent
      authored material. Neither occurrence can replace a different result in the report.</p>
      <section><h2>Published measurements</h2>#{content}</section>
      <pre><code>22:18\n40:23\nPlay\nSettings</code></pre>
      <p>The closing explanation remains after every independent result and media resource.
      <a href="https://publication.example.test/reports/?view=complete#measurements">Complete measurement reference</a></p>
      </article></main></body></html>
    HTML
  end

  def with_statistic_reference(content)
    with_url_page('https://publication.example.test/reports/timing/', statistic_reference(content)) do |page|
      before_html = page.evaluate('document.body.innerHTML')
      before_text = page.evaluate('document.body.innerText')
      payload = extract(page)
      retained = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(payload.fetch('title')).to eq('Timing Reference')
      expect(retained.css('h1, h2').map(&:text)).to eq(['Timing Reference', 'Published measurements'])
      expect(retained.css('pre code').map(&:text)).to eq(["22:18\n40:23\nPlay\nSettings"])
      expect(payload.fetch('markdown')).to include(
        "```\n22:18\n40:23\nPlay\nSettings\n```",
        'The closing explanation remains after every independent result'
      )
      references = retained.css('a').select { |node| node.text == 'Complete measurement reference' }
      expect(references.map { |node| node['href'] }).to eq(['https://publication.example.test/reports/?view=complete#measurements'])
      expect(payload.fetch('byline')).to be_nil
      expect(payload.fetch('publishedTime')).to be_nil
      expect(page.evaluate('document.body.innerHTML')).to eq(before_html)
      expect(page.evaluate('document.body.innerText')).to eq(before_text)
      yield payload, retained
      expect(page.evaluate('document.body.innerHTML')).to eq(before_html)
      expect(page.evaluate('document.body.innerText')).to eq(before_text)
    end
  end

  it 'retains every independently labelled short and long duration in source order' do
    content = <<~HTML
      <div><span>Elapsed interval</span><div><span id="datum-one">22:18</span></div></div>
      <div><span>Measured ratio</span><div><span id="datum-two">40:23</span></div></div>
      <div><span>Complete interval</span><div><span id="datum-three">1:15:50</span></div></div>
    HTML
    with_statistic_reference(content) do |payload, retained|
      expect(retained.css('#datum-one, #datum-two, #datum-three').map(&:text)).to eq(['22:18', '40:23', '1:15:50'])
      expect(payload.fetch('markdown')).to include('Elapsed interval', 'Measured ratio', 'Complete interval', '1:15:50')
    end
  end

  it 'retains independent equal numeric values in otherwise unmarked containers' do
    content = '<div id="first-result">22:18</div><p>The second value is an independent measurement.</p>' \
              '<div id="second-result"><span>22:18</span></div>'
    with_statistic_reference(content) do |payload, retained|
      paragraphs = retained.css('p').map(&:text).select do |text|
        ['22:18', 'The second value is an independent measurement.'].include?(text)
      end
      expect(paragraphs).to eq(['22:18', 'The second value is an independent measurement.', '22:18'])
      expect(payload.fetch('markdown')).to include("22:18\n\nThe second value is an independent measurement.\n\n22:18")
    end
  end

  it 'keeps an authored numeric HTTP reference with its complete query and fragment' do
    destination = 'https://publication.example.test/reports/?ratio=22:18#value'
    with_statistic_reference("<p>The declared result is <a href=\"#{destination}\">22:18</a> in the published report.</p>") do |payload, retained|
      reference = retained.css('a').select { |node| node.text == '22:18' }
      expect(reference.map { |node| node['href'] }).to eq([destination])
      expect(payload.fetch('markdown')).to include("[22:18](#{destination})")
    end
  end

  it 'removes actual playback timestamps whose controls explicitly target one media element' do
    content = <<~HTML
      <video id="reference-media" src="/lesson.mp4" poster="/lesson.jpg" controls></video>
      <div role="group" aria-controls="reference-media"><button>Play</button><button>Pause</button>
      <span id="current-playback">22:18</span><span id="total-playback">40:23</span>
      <span>Settings</span><span>Volume 37%</span></div>
    HTML
    with_statistic_reference(content) do |_payload, retained|
      expect(retained.css('#current-playback, #total-playback, button')).to be_empty
      expect(retained.css('pre code').map(&:text)).to eq(["22:18\n40:23\nPlay\nSettings"])
    end
  end

  it 'preserves labelled measurements beside an actual media resource without borrowing its controls' do
    content = <<~HTML
      <div class="video-js"><video id="adjacent-media" src="/lesson.mp4" controls></video>
      <div><span>Independent measured interval</span><div><span id="adjacent-result">22:18</span></div></div></div>
    HTML
    with_statistic_reference(content) do |_payload, retained|
      expect(retained.css('#adjacent-result').map(&:text)).to eq(['22:18'])
      expect(retained.text).to include('Independent measured interval')
    end
  end

  it 'keeps hidden and closed numeric data hidden while retaining the visible long value' do
    content = <<~HTML
      <div hidden><span>Hidden interval</span><span>99:31</span></div>
      <div style="display:none"><span>Unpublished ratio</span><span>88:21</span></div>
      <details><summary>Optional unpublished measurements</summary><span>77:19</span></details>
      <div id="visible-result">1:15:50</div>
    HTML
    with_statistic_reference(content) do |payload, retained|
      expect(retained.css('p').map(&:text).select { |text| text == '1:15:50' }).to eq(['1:15:50'])
      expect(payload.fetch('html')).to include('Optional unpublished measurements')
      expect(payload.fetch('markdown')).to include('Optional unpublished measurements')
      closed = retained.css('details:not([open])')
      expect(closed.css('summary').map(&:text)).to eq(['Optional unpublished measurements'])
      closed_values = retained.xpath('.//text()').select { |node| node.text == '77:19' }
      expect(closed_values.map { |node| node.ancestors('details').first }).to eq([closed.first])
      expect(payload.fetch('html')).not_to include('99:31', '88:21')
      expect(payload.fetch('markdown')).not_to include('99:31', '88:21', '77:19')
    end
  end

  it 'does not infer media ownership from ambiguous duplicate media IDs' do
    content = <<~HTML
      <video id="ambiguous-media" src="/first.mp4" controls></video>
      <audio id="ambiguous-media" src="/second.ogg" controls></audio>
      <div role="group" aria-controls="ambiguous-media"><span id="ambiguous-result">22:18</span></div>
    HTML
    with_statistic_reference(content) do |_payload, retained|
      expect(retained.css('#ambiguous-result').map(&:text)).to eq(['22:18'])
    end
  end

  it 'does not treat a control relationship to a non-media panel as playback ownership' do
    content = <<~HTML
      <div id="data-panel"><p>The panel contains an independent published explanation.</p></div>
      <div role="group" aria-controls="data-panel"><span id="panel-result">22:18</span></div>
    HTML
    with_statistic_reference(content) do |_payload, retained|
      expect(retained.css('#panel-result').map(&:text)).to eq(['22:18'])
      expect(retained.css('p').map(&:text)).to include('The panel contains an independent published explanation.')
    end
  end
end
