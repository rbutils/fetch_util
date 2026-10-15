require 'spec_helper'

RSpec.describe 'FetchUtil physical manual construction lifecycle' do
  include_context 'extractor integration helpers'

  def lifecycle_source
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.manualLifecycleProbe = withComposedDomRead(function(options) {
        var events = [];
        var originalMetadata = collectMetadata;
        var originalMaterial = physicalManualRenderedSections;
        collectMetadata = function() {
          events.push('metadata');
          if (options.mutate) {
            document.querySelector('#revision').textContent = 'Newly published source revision.';
            document.querySelector('#private').hidden = true;
          }
          return originalMetadata();
        };
        physicalManualRenderedSections = function(metadata, context) {
          events.push('material');
          return originalMaterial(metadata, context);
        };
        try {
          var page = metadataWithPreparedStandaloneManual();
          var content = sourceOwnedPrimaryContent(page.metadata, page.manual);
          return { events: events, content: content };
        } finally {
          collectMetadata = originalMetadata;
          physicalManualRenderedSections = originalMaterial;
        }
      });
      })(window);
    JS
    source.sub('})(window);', export)
  end

  def lifecycle_html(extra_head: '', role: true)
    sections = (1..160).map do |number|
      "<section><h2>Published section #{number}</h2><p>Complete instruction #{number}.</p>" \
        "<div class=\"highlight\"><pre>source#{number}(value);</pre></div>" \
        "<a href=\"/references/#{number}\">Published reference #{number}</a></section>"
    end.join
    <<~HTML
      <html lang="en"><head><title>Language reference manual</title>#{extra_head}</head><body>
      <article #{role ? 'role="main"' : ""}><h1>Language reference manual</h1>
      <p id="revision">Original published revision.</p><p id="private">Private source revision.</p>
      #{sections}</article></body></html>
    HTML
  end

  def lifecycle_probe(html, mutate: false)
    with_url_page('https://publication.example.test/reference/manual', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: lifecycle_source)
      result = page.evaluate("window.manualLifecycleProbe({mutate: #{mutate}})")
      expect(page.evaluate('document.body.innerHTML')).to eq(before) unless mutate
      yield result
    end
  end

  it 'finishes metadata reads before materializing the whole proved manual once' do
    lifecycle_probe(lifecycle_html) do |result|
      expect(result.fetch('events')).to eq(%w[metadata material])
      (1..160).each do |number|
        %w[html markdown].each do |format|
          expect(result.fetch('content').fetch(format)).to include("Published section #{number}", "source#{number}(value);", "/references/#{number}")
        end
      end
    end
  end

  it 'materializes only the current text and visibility after metadata-side changes' do
    lifecycle_probe(lifecycle_html, mutate: true) do |result|
      expect(result.fetch('events')).to eq(%w[metadata material])
      %w[html markdown].each do |format|
        expect(result.fetch('content').fetch(format)).to include('Newly published source revision.')
        expect(result.fetch('content').fetch(format)).not_to include('Original published revision.', 'Private source revision.')
      end
    end
  end

  it 'retains ordinary declared-article priority and its actual attribution' do
    declaration = {
      '@context' => 'https://schema.org', '@type' => 'NewsArticle',
      'url' => 'https://publication.example.test/reference/manual',
      'headline' => 'Language reference manual',
      'articleBody' => 'Original published revision. Private source revision.',
      'author' => { '@type' => 'Person', 'name' => 'Published Reporter' },
      'datePublished' => '2026-09-01'
    }
    html = lifecycle_html(extra_head: "<script type=\"application/ld+json\">#{declaration.to_json}</script>")
    lifecycle_probe(html) do |result|
      expect(result.fetch('events').first).to eq('metadata')
      expect(result.fetch('content').fetch('sourceOwnedDeclaredSemanticArticle')).to be(true)
      expect(result.fetch('content').fetch('byline')).to eq('Published Reporter')
    end
  end
end
