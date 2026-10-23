# frozen_string_literal: true

RSpec.describe 'Closed disclosure plain-text material' do
  include_context 'extractor integration helpers'

  def disclosure_article(body)
    <<~HTML
      <html><head><title>Observed disclosure material</title>
      <link rel="canonical" href="https://disclosures.publication.example.test/guide">
      <meta property="og:type" content="article"></head><body><main><article>
      <h1>Observed disclosure material</h1>
      <p>This publication explains independently authored command examples and their physical disclosure state.</p>
      <p>Each visible example is part of the reporting and retains its complete program, reading order and resource destination.</p>
      #{body}
      <p>The final reporting paragraph remains visible after every example and is not a disclosure control.</p>
      <p><a href="/reference">Complete reference</a></p>
      </article></main></body></html>
    HTML
  end

  def extract_disclosure(body)
    html = disclosure_article(body)
    with_url_page('https://disclosures.publication.example.test/guide', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      value = FetchUtil::Extractor.new.extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(value.fetch('title')).to eq('Observed disclosure material')
      expect(value.fetch('byline')).to be_nil
      expect(value.fetch('publishedTime')).to be_nil
      expect(value.fetch('markdown')).to include(
        'The final reporting paragraph remains visible',
        '[Complete reference](https://disclosures.publication.example.test/reference)'
      )
      yield value
    end
  end

  it 'keeps closed summaries and visible programs without emitting closed body text' do
    extract_disclosure(<<~HTML) do |value|
      <pre>visible_command();
        next_step();</pre>
      <details><summary>Closed example summary</summary>
      <p>Closed reporting sentence.</p><pre>closed_command();</pre></details>
    HTML
      expect(value.fetch('textContent')).not_to include('Closed reporting sentence.', 'closed_command();')
      expect(value.fetch('textContent')).to include('Closed example summary', 'visible_command();', 'next_step();')
      expect(value.fetch('markdown')).to include("visible_command();\n  next_step();", 'Closed example summary')
      expect(value.fetch('markdown')).not_to include('Closed reporting sentence.', 'closed_command();')
    end
  end

  it 'preserves an open body and only the summary of its nested closed disclosure' do
    extract_disclosure(<<~HTML) do |value|
      <details open><summary>Open example summary</summary><p>Open reporting sentence.</p>
      <pre>open_command();</pre><details><summary>Nested closed summary</summary>
      <pre>nested_closed_command();</pre></details></details>
    HTML
      expect(value.fetch('textContent')).not_to include('nested_closed_command();')
      expect(value.fetch('textContent')).to include('Open example summary', 'Open reporting sentence.', 'open_command();', 'Nested closed summary')
      expect(value.fetch('markdown')).to include('Open reporting sentence.', 'open_command();', 'Nested closed summary')
      expect(value.fetch('markdown')).not_to include('nested_closed_command();')
    end
  end

  it 'preserves the independent visible occurrence of an identical closed program value' do
    extract_disclosure(<<~HTML) do |value|
      <pre>shared_command();</pre><details><summary>Independent closed copy</summary>
      <pre>shared_command();</pre><p>Closed copy context.</p></details>
    HTML
      expect(value.fetch('textContent').scan('shared_command();').length).to eq(1)
      expect(value.fetch('markdown').scan('shared_command();').length).to eq(1)
      expect(value.fetch('textContent')).to include('Independent closed copy')
      expect(value.fetch('textContent')).not_to include('Closed copy context.')
    end
  end

  it 'does not invent a label or emit a closed body that has no physical summary' do
    extract_disclosure('<pre>outside_command();</pre><details><p>Unlabelled closed sentence.</p><pre>unlabelled_closed_command();</pre></details>') do |value|
      expect(value.fetch('textContent')).not_to include('Unlabelled closed sentence.', 'unlabelled_closed_command();')
      expect(value.fetch('markdown')).not_to include('Unlabelled closed sentence.', 'unlabelled_closed_command();')
      expect(value.fetch('textContent')).to include('outside_command();')
    end
  end

  it 'preserves all open disclosure material including the boolean open attribute' do
    extract_disclosure(<<~HTML) do |value|
      <details open="false"><summary>Boolean open state</summary><p>Boolean attribute body remains open.</p>
      <pre>boolean_open_command();</pre></details><details open><summary>Second open summary</summary>
      <pre>second_open_command();</pre></details>
    HTML
      %w[boolean_open_command(); second_open_command();].each do |program|
        expect(value.fetch('textContent')).to include(program)
        expect(value.fetch('markdown')).to include(program)
      end
      expect(value.fetch('textContent')).to include('Boolean attribute body remains open.')
    end
  end

  it 'preserves literal disclosure markup inside a complete visible program' do
    extract_disclosure(<<~HTML) do |value|
      <pre>const markup = "&lt;details&gt;&lt;summary&gt;Literal label&lt;/summary&gt;literal_command();&lt;/details&gt;";
        use(markup);</pre>
    HTML
      literal = 'const markup = "<details><summary>Literal label</summary>literal_command();</details>";'
      expect(value.fetch('textContent')).to include(literal, 'use(markup);')
      expect(value.fetch('markdown')).to include("#{literal}\n  use(markup);")
    end
  end

  def with_plain_disclosure_probe
    repository = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(repository, 'websieve/manifest.txt'), chomp: true)
    paths.reject! { |path| path.empty? || path.start_with?('#') }
    source = paths.map { |path| File.read(File.join(repository, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(repository, 'websieve/99_outro.js'))
    raise 'ambiguous extractor closure' unless source.scan(outro).length == 1

    with_url_page('https://disclosures.publication.example.test/guide', disclosure_article('<p>Probe owner.</p>')) do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: source.sub(outro, "window.__plainDisclosureProbe = plainTextWithoutClosedDisclosures;\n#{outro}"))
      yield page
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'preserves exact raw program whitespace while removing only its separately owned closed copy' do
    with_plain_disclosure_probe do |page|
      result = page.evaluate(<<~JS)
        (() => {
          const program = `\tshared();\n  retain_spacing();`;
          const html = '<article><pre>' + program + '</pre><details><summary>Visible summary</summary><pre>' +
            program + '</pre></details></article>';
          const template = document.createElement('template');
          template.innerHTML = html;
          return window.__plainDisclosureProbe(html, template.content.textContent);
        })()
      JS
      expect(result).to eq("\tshared();\n  retain_spacing();Visible summary")
    end
  end

  it 'retains independent plain material that cannot be wholly bound to the provided HTML' do
    with_plain_disclosure_probe do |page|
      result = page.evaluate(<<~JS)
        (() => {
          const html = '<article><details><summary>Visible summary</summary><p>Closed body.</p></details></article>';
          return window.__plainDisclosureProbe(html, 'Independent editorial plain text with its own complete program value.');
        })()
      JS
      expect(result).to eq('Independent editorial plain text with its own complete program value.')
    end
  end
end
