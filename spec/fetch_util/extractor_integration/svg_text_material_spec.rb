# frozen_string_literal: true

require 'cgi'
require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Authored SVG text material' do
  include_context 'complete block reference expectations'

  def svg_native_material(page, html)
    page.evaluate(<<~JS)
      (function() {
        var root = document.createElement('div');
        root.innerHTML = #{html.to_json};
        return {
          labels: Array.from(root.querySelectorAll('svg')).map(function(svg) {
            return Array.from(svg.querySelectorAll('text')).map(function(node) { return node.textContent; });
          }),
          paths: Array.from(root.querySelectorAll('svg path')).map(function(node) { return node.getAttribute('d'); }),
          paint: Array.from(root.querySelectorAll('svg path')).map(function(node) {
            return ['fill', 'stroke', 'clip-path', 'filter'].map(function(attribute) { return String(node.getAttribute(attribute)); });
          }),
          programs: Array.from(root.querySelectorAll('pre code')).map(function(node) { return node.textContent; }),
          controls: root.querySelectorAll('details[open], button, svg[aria-hidden="true"]').length
        };
      })()
    JS
  end

  it 'retains complete independent chart labels, geometry and references without changing literal programs' do
    program = "const sample = '<svg><text>Literal graph program</text></svg>';\nconsole.log(sample);"
    first_labels = ['Consultation', 'Support', 'Repeated value', '30', '30', 'All observations']
    second_labels = ['Training', 'Trial', '30', 'Mean duration']
    html = <<~HTML
      <html><head><title>Published measurements</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Published measurements</h1><p>Keep the complete published explanation before both independent charts.</p>
      <h2>Sessions per week</h2><figure><svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
      <defs><clipPath id="observation-clip"><rect width="200" height="100"></rect></clipPath></defs>
      <path d="M 0 80 L 50 40 L 100 60" fill="none" stroke="#4277aa" clip-path="url(#observation-clip)"></path><text>Consultation</text><text>Support</text>
      <text><tspan>Repeated</tspan><tspan> value</tspan></text><text>30</text><text>30</text>
      <a href="../observations/"><text>All observations</text></a></svg>
      <figcaption>Every source label belongs to this independently published chart.</figcaption></figure>
      <h2>Average session duration</h2><svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
      <path d="M 0 60 L 50 20 L 100 40" fill="rgb(2, 4, 8)" stroke="currentColor"></path><text>Training</text><text>Trial</text><text>30</text>
      <a href="../duration/"><text>Mean duration</text></a></svg>
      <p>Keep the complete explanation after the charts and the <a href="../method/">published method</a>.</p>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
      </article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/guide/charts/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = svg_native_material(page, payload.fetch('html'))
      expect(native.fetch('labels')).to eq([first_labels, second_labels])
      expect(native.fetch('paths')).to eq(['M 0 80 L 50 40 L 100 60', 'M 0 60 L 50 20 L 100 40'])
      expect(native.fetch('paint')).to eq([['none', '#4277aa', 'url(#observation-clip)', 'null'],
                                           ['rgb(2, 4, 8)', 'currentColor', 'null', 'null']])
      expect(native.fetch('programs')).to eq([program])
      markdown = payload.fetch('markdown')
      labels = markdown.lines.map(&:strip)
      expect(labels.count('30')).to eq(3)
      expect(labels.grep(/Consultation|Support|Repeated value|Training|Trial/)).to eq(
        ['Consultation', 'Support', 'Repeated value', 'Training', 'Trial']
      )
      {
        'observations' => 'All observations',
        'duration' => 'Mean duration'
      }.each do |destination, label|
        href = "https://docs.publication.example.test/guide/#{destination}/"
        expect_complete_raw_references(markdown, href, "<a href='#{href}'><p>#{label}</p></a>")
      end
      expect(markdown).to include('[published method](https://docs.publication.example.test/guide/method/)',
                                  "```js\n#{program}\n```", 'Every source label belongs to this independently published chart.',
                                  'Keep the complete published explanation before both independent charts.',
                                  'Keep the complete explanation after the charts')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains visible SVG text while leaving hidden text, closed diagrams and decorative controls unexposed' do
    html = <<~HTML
      <html><head><title>Measurement visibility</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset"><h1>Measurement visibility</h1>
      <p>Published measurements retain every visible observation and keep private panels closed.</p>
      <svg xmlns="http://www.w3.org/2000/svg"><path d="M 0 0 L 10 10" fill="var(--unbound-color)" clip-path="url(#missing-resource)" filter="url(javascript:bad)"></path>
      <text>Visible observation</text><g style="display:none"><text>Private observation</text></g>
      <text style="visibility:hidden">Hidden tick</text><text hidden>Unpublished tick</text></svg>
      <svg style="display:none" xmlns="http://www.w3.org/2000/svg"><text>Private entire diagram</text></svg>
      <svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><path d="M 1 1 L 2 2"></path></svg>
      <details><summary>Closed observations</summary><svg xmlns="http://www.w3.org/2000/svg"><text>Closed chart value</text></svg></details>
      <button type="button"><svg xmlns="http://www.w3.org/2000/svg"><path d="M 2 2 L 3 3"></path></svg></button>
      <p>The public explanation remains complete after the charts.</p></article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/guide/visibility/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = svg_native_material(page, payload.fetch('html'))
      expect(native.fetch('labels').flatten).to include('Visible observation')
      expect(native.fetch('paint').first).to eq(%w[null null null null])
      expect(native.fetch('controls')).to eq(0)
      expect(payload.fetch('markdown')).to include('Visible observation', 'Closed observations',
                                                   'The public explanation remains complete after the charts.')
      expect(payload.fetch('markdown')).not_to include('Private observation', 'Hidden tick', 'Unpublished tick',
                                                       'Private entire diagram', 'Closed chart value')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
