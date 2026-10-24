# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'

RSpec.describe 'Source-declared Devsite video resources' do
  include_context 'extractor integration helpers'

  def devsite_recording_page(recordings)
    program = "const recording = '<iframe src=\"/literal-frame\"></iframe>';\n\nkeep(recording);"
    [<<~HTML, program]
      <!doctype html><html><head><title>Recording reference</title>
      <link rel="canonical" href="https://docs.publication.example.test/course/">
      <style>.hidden-recording { display: none; }</style></head><body>
      <main><devsite-content><article class="devsite-article"><h1>Recording reference</h1>
      <div class="devsite-article-body"><p>The complete introduction explains the recording before
      the first named section. Every independent resource and authored paragraph stays in source order.</p>
      #{recordings}
      <h2>Written reference</h2><p>Keep the independent <a href="/written-reference?version=2#example">written example</a>.</p>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
      <h2>Conclusion</h2><p>The final explanation follows every recording and the complete program.</p>
      </div></article></devsite-content></main></body></html>
    HTML
  end

  def devsite_recording_url
    'https://media.publication.example.test/embed/lesson-7?mode=full&origin=https%3A%2F%2Fdocs.publication.example.test%2F#chapter'
  end

  def expect_complete_devsite_material(page, result, original, program)
    native = Nokogiri::HTML5.fragment(result.fetch('html'))
    expect(native.css('pre').map(&:text)).to eq([program])
    expect(native.css('h1,h2').map { |node| [node.name, node.text] }).to eq(
      [['h1', 'Recording reference'], ['h2', 'Written reference'], ['h2', 'Conclusion']]
    )
    expect(result.fetch('markdown')).to include(
      'Every independent resource and authored paragraph stays in source order.',
      '[written example](https://docs.publication.example.test/written-reference?version=2#example)',
      program, 'The final explanation follows every recording and the complete program.'
    )
    expect(result.values_at('byline', 'publishedTime')).to eq([nil, nil])
    expect(page.evaluate('document.body.innerHTML')).to eq(original)
    native
  end

  it 'retains the complete source URL and title of a component before the first section heading' do
    recordings = <<~HTML
      <devsite-video video-id="lesson-7"><iframe src="#{CGI.escapeHTML(devsite_recording_url)}"
      title="Complete recording &amp; examples" width="640" height="360"></iframe></devsite-video>
    HTML
    html, program = devsite_recording_page(recordings)
    with_url_page('https://docs.publication.example.test/course/', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = extract(page)
      native = expect_complete_devsite_material(page, result, original, program)
      link = native.css('a[href]').find { |node| node['href'] == devsite_recording_url }
      expect(link&.text).to eq('Complete recording & examples')
      expect(result.fetch('markdown')).to include("[Complete recording & examples](#{devsite_recording_url})")
      expect(
        result.fetch('markdown').index('[Complete recording & examples]')
      ).to be < result.fetch('markdown').index('## Written reference')
    end
  end

  it 'keeps independent identical video destinations and their source labels in order' do
    recordings = <<~HTML
      <devsite-video video-id="lesson-7"><iframe src="#{CGI.escapeHTML(devsite_recording_url)}"
      title="First recording"></iframe></devsite-video>
      <p>This independently authored explanation separates the recordings.</p>
      <devsite-video video-id="lesson-7"><iframe src="#{CGI.escapeHTML(devsite_recording_url)}"
      title="Second recording"></iframe></devsite-video>
    HTML
    html, program = devsite_recording_page(recordings)
    with_url_page('https://docs.publication.example.test/course/', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = extract(page)
      native = expect_complete_devsite_material(page, result, original, program)
      expect(native.css('a[href]').select { |node| node['href'] == devsite_recording_url }.map(&:text)).to eq(
        ['First recording', 'Second recording']
      )
      markdown = result.fetch('markdown')
      expect(markdown.scan(devsite_recording_url).length).to eq(2)
      expect(markdown.index('[First recording]')).to be < markdown.index('This independently authored explanation')
      expect(markdown.index('This independently authored explanation')).to be < markdown.index('[Second recording]')
    end
  end

  it 'uses an explicit accessible source label without inventing a video URL' do
    recordings = <<~HTML
      <devsite-video video-id="lesson-7"><iframe src="#{CGI.escapeHTML(devsite_recording_url)}"
      aria-label="Accessible recording"></iframe></devsite-video>
    HTML
    html, program = devsite_recording_page(recordings)
    with_url_page('https://docs.publication.example.test/course/', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = extract(page)
      native = expect_complete_devsite_material(page, result, original, program)
      expect(native.css('a[href]').map { |node| [node.text, node['href']] }).to include(
        ['Accessible recording', devsite_recording_url]
      )
      expect(result.fetch('markdown')).to include("[Accessible recording](#{devsite_recording_url})")
    end
  end

  it 'keeps hidden, closed, interface, inactive and literal resources out of materialized links' do
    frame = '<iframe src="/embed/excluded" title="Excluded recording"></iframe>'
    component = "<devsite-video video-id=\"excluded\">#{frame}</devsite-video>"
    recordings = <<~HTML
      <div class="hidden-recording">#{component}</div><div style="opacity:0">#{component}</div>
      <details><summary>Closed recording</summary>#{component}</details>
      <nav>#{component}</nav><aside>#{component}</aside><form>#{component}</form>
      <div inert>#{component}</div><div aria-hidden="true">#{component}</div>
      <devsite-video video-id="excluded"><iframe src="/embed/excluded" title="Excluded recording"
      srcdoc="&lt;p&gt;An independent document&lt;/p&gt;"></iframe></devsite-video>
    HTML
    html, program = devsite_recording_page(recordings)
    with_url_page('https://docs.publication.example.test/course/', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = extract(page)
      native = expect_complete_devsite_material(page, result, original, program)
      expect(native.css('a[href]').map { |node| node['href'] }).not_to include(
        'https://docs.publication.example.test/embed/excluded',
        'https://docs.publication.example.test/literal-frame'
      )
      expect(result.fetch('markdown')).not_to include('Excluded recording', '/embed/excluded')
    end
  end

  it 'does not infer ownership from an unrelated element, mismatched identifier, unsafe URL or existing link' do
    recordings = <<~HTML
      <div video-id="excluded"><iframe src="/embed/excluded" title="Excluded recording"></iframe></div>
      <devsite-video video-id="different"><iframe src="/embed/excluded" title="Excluded recording"></iframe></devsite-video>
      <devsite-video video-id="excluded"><iframe src="javascript:void(0)" title="Excluded recording"></iframe></devsite-video>
      <devsite-video video-id="excluded"><iframe src="/embed/excluded"></iframe></devsite-video>
      <a href="/independent-link"><devsite-video video-id="excluded">
      <iframe src="/embed/excluded" title="Excluded recording"></iframe></devsite-video></a>
    HTML
    html, program = devsite_recording_page(recordings)
    with_url_page('https://docs.publication.example.test/course/', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = extract(page)
      native = expect_complete_devsite_material(page, result, original, program)
      expect(native.css('a[href]').map { |node| node['href'] }).not_to include(
        'https://docs.publication.example.test/embed/excluded', 'javascript:void(0)'
      )
      expect(result.fetch('markdown')).not_to include('Excluded recording', '/embed/excluded')
    end
  end
end
