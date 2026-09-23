# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil implicit liveblog clocks' do
  include_context 'extractor integration helpers'

  def format_for(url, html)
    with_url_page(url, html) do |page|
      extractor_for(true).__send__(:inject_assets, page)
      source_root = File.expand_path('../../../websieve', __dir__)
      source = File.readlines(File.join(source_root, 'manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(source_root, entry))
      end.join("\n")
      page.add_script_tag(content: source.sub('})(window);', 'global.formatProbe = { detect: detectContentFormat, markdown: markdownFor }; })(window);'))
      page.evaluate(<<~JS)
        (() => {
          const owner = document.querySelector('main');
          const markdown = formatProbe.markdown(owner.innerHTML);
          return formatProbe.detect({ title: document.title },
            { contentType: 'article', title: document.title, html: owner.innerHTML, textContent: owner.textContent },
            markdown);
        })()
      JS
    end
  end

  it 'does not treat many decimal market prices as live update times' do
    sections = (1..12).map do |number|
      <<~HTML
        <section><h2>Market measure #{number}</h2>
          <p>Market prices $0.01, $56.30, and $85.19 are decimal amounts, not clocks.
          The data for measure #{number} belongs to this asset's historical performance.</p></section>
      HTML
    end.join
    html = "<html><head><title>Asset market overview</title></head><body><main>#{sections}</main></body></html>"

    expect(format_for('https://markets.example/coins/asset', html)).to be_nil
  end

  it 'still recognizes six or more real clock-stamped updates' do
    sections = (1..8).map do |number|
      <<~HTML
        <section><h2>Development #{number}</h2>
          <p>#{format("%02d", number + 9)}:30 UTC — independent report #{number} adds new details to the incident.</p></section>
      HTML
    end.join
    html = "<html><head><title>Incident timeline</title></head><body><main>#{sections}</main></body></html>"

    expect(format_for('https://reports.example/coverage', html)).to eq('liveblog')
  end
end
