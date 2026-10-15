# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Authored inline control-word references' do
  include_context 'extractor integration helpers'

  def inline_control_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.inlineControlProbe = function() {
        return withComposedDomRead(function() {
          var root = document.createElement('div');
          root.innerHTML = document.body.innerHTML;
          cleanupAgentRoot(root);
          return {html: root.innerHTML, markdown: markdownFor(root.innerHTML),
            references: Array.prototype.map.call(root.querySelectorAll('a[href]'), function(node) {
              return {href: node.getAttribute('href'), text: node.textContent};
            }), controls: root.querySelectorAll('button, [role="button"]').length};
        })({});
      };
      })(window);
    JS
  end

  it 'retains every published inline label and destination in authored source order' do
    labels = ['resume', 'pause', 'play', 'learn more', 'close', 'share']
    references = (1..240).flat_map do |number|
      labels.map { |label| { 'href' => "/reference/#{number}##{label.tr(" ", "-")}", 'text' => label } }
    end
    paragraphs = references.map do |reference|
      <<~HTML
        <p>The documented operation <a href="#{reference.fetch("href")}"><span>#{reference.fetch("text")}</span></a>
        has a complete authored explanation and an independently published reference.</p>
      HTML
    end
    html = "<article><h1>Complete operation references</h1>#{paragraphs.join}</article>"
    with_url_page('https://reference.example.test/operation-notes', html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: inline_control_probe)
      result = page.evaluate('inlineControlProbe()')
      expect(result.fetch('references')).to eq(references)
      references.each do |reference|
        destination = "https://reference.example.test#{reference.fetch("href")}"
        expect(result.fetch('markdown')).to include("[#{reference.fetch("text")}](#{destination})")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains real controls and unsafe or unowned links as removable UI' do
    html = <<~HTML
      <article><h1>Authored control terminology</h1>
      <p>这个术语说明 <strong><a href="/reference/resume"><span>resume</span></a></strong> 后续操作的真实含义。</p>
      <p>A control <button>pause</button> remains an actual interface action.</p>
      <p>A control <a href="/play" role="button">play</a> remains an actual interface action.</p>
      <p>A command <a href="javascript:resume()">resume</a> remains an unsafe interface action.</p>
      <p><a href="/standalone">resume</a></p>
      <a href="/outside">pause</a>
      <nav><p>Navigation <a href="/navigation">resume</a> remains navigation.</p></nav>
      <form><p>Form action <a href="/form">resume</a> remains a form action.</p></form>
      <div role="dialog"><p>Dialog action <a href="/dialog">resume</a> remains an interface action.</p></div>
      <pre><code>resume; pause(); play();</code></pre>
      </article>
    HTML
    with_url_page('https://reference.example.test/control-notes', html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: inline_control_probe)
      result = page.evaluate('inlineControlProbe()')
      expect(result.fetch('references')).to eq([{ 'href' => '/reference/resume', 'text' => 'resume' }])
      expect(result.fetch('controls')).to eq(0)
      expect(result.fetch('markdown')).to include('[resume](https://reference.example.test/reference/resume)')
      expect(result.fetch('markdown')).to include('resume; pause(); play();')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
