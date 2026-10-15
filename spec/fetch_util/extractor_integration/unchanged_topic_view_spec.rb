# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil HTML-owned topic views' do
  include_context 'extractor integration helpers'

  def topic_view_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);', <<~JAVASCRIPT
        window.topicViewProbe = function(operations) {
          var original = markdownFor, calls = 0, content = {}, views = [];
          markdownFor = function() { calls++; return original.apply(this, arguments); };
          try {
            operations.forEach(function(operation) {
              if (Object.prototype.hasOwnProperty.call(operation, "html")) content.html = operation.html;
              var view = multiTopicExtractionView(content, operation.markdown);
              views.push({
                html: view.root && view.root.innerHTML,
                markdown: view.markdown,
                calls: calls,
                multiTopic: !!view.root && newsletterHasMultiTopicListStructure(
                  {html:content.html, contentType:"list"}, view.markdown, view.root
                )
              });
              if (operation.mutateRoot && view.root) view.root.textContent = "A caller changed its isolated view.";
            });
            return views;
          } finally { markdownFor = original; }
        };
        })(window);
      JAVASCRIPT
    )
  end

  def topic_views(page, operations)
    page.evaluate("topicViewProbe(#{operations.to_json})")
  end

  def install_topic_view_probe(page)
    FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
    page.add_script_tag(content: topic_view_source)
  end

  it 'classifies all source records rather than presentation Markdown and converts unchanged input only once' do
    html = (1..240).map do |index|
      "<section><h2><a href='https://publication.example.test/record/#{index}'>Unit #{index}</a></h2>" \
        "<p>Published words #{index} remain.</p>" \
        "<a href='https://publication.example.test/ref/#{index}'>Reference #{index}</a>" \
        "<pre>value_#{index} = 1;</pre><table><tr><td>Field #{index}</td></tr></table></section>"
    end.join
    presentation = (1..240).map { |index| "- Unit #{index}: a compact summary." }.join("\n")
    with_url_page('https://publication.example.test/reference', '<html><body></body></html>') do |page|
      install_topic_view_probe(page)
      results = topic_views(page, [{ html: html, markdown: presentation, mutateRoot: true },
                                   { markdown: 'A different caller summary.' }, { markdown: '' }])
      expect(results.map { |result| result['calls'] }).to eq([1, 1, 1])
      expect(results.map { |result| result['markdown'] }.uniq.length).to eq(1)
      expect(results.map { |result| result['html'] }.uniq.length).to eq(1)
      results.each do |result|
        expect(result['multiTopic']).to be(false)
        (1..240).each do |index|
          expect(result['html']).to include("Unit #{index}", "ref/#{index}", "value_#{index}", "Field #{index}")
          expect(result['markdown']).to include("## [Unit #{index}]", "Published words #{index} remain.",
                                                "https://publication.example.test/ref/#{index}",
                                                "value_#{index} = 1;", "Field #{index}")
        end
      end
    end
  end

  it 'retains source-owned multi-topic evidence when presentation Markdown flattens linked headings' do
    html = (1..240).map do |index|
      "<section><h2><a href='https://publication.example.test/report/#{index}'>Report #{index}</a></h2>" \
        "<p>The published summary of independent report #{index} remains.</p></section>"
    end.join
    presentation = (1..240).map { |index| "- Report #{index}: a compact summary." }.join("\n")
    with_url_page('https://publication.example.test/index', '<html><body></body></html>') do |page|
      install_topic_view_probe(page)
      results = topic_views(page, [{ html: html, markdown: presentation }, { markdown: 'An unrelated summary.' }])
      expect(results.map { |result| result['calls'] }).to eq([1, 1])
      results.each do |result|
        expect(result['multiTopic']).to be(true)
        (1..240).each do |index|
          expect(result['markdown']).to include("## [Report #{index}]", "independent report #{index} remains.",
                                                "https://publication.example.test/report/#{index}")
        end
      end
    end
  end

  it 'rebuilds the view after removing actual related or navigation material' do
    html = '<article><h1>Owned account</h1><p>The complete authored account remains.</p>' \
           '<a href="https://publication.example.test/source">Primary reference</a></article>' \
           '<aside><p>Foreign related account.</p></aside><nav>Foreign navigation.</nav>'
    with_url_page('https://publication.example.test/account', '<html><body></body></html>') do |page|
      install_topic_view_probe(page)
      results = topic_views(page, [{ html: html, markdown: 'Foreign related account. Foreign navigation.' },
                                   { markdown: 'Another supplied summary.', mutateRoot: true }, { markdown: '' }])
      expect(results.map { |result| result['calls'] }).to eq([1, 1, 1])
      results.each do |result|
        expect(result['markdown']).to include('The complete authored account remains.', 'publication.example.test/source')
        expect(result['markdown']).not_to include('Foreign related account', 'Foreign navigation')
        expect(result['html']).not_to include('<aside', '<nav', 'A caller changed')
      end
    end
  end

  it 'invalidates a changed HTML owner while rejecting stale caller Markdown' do
    with_url_page('https://publication.example.test/account', '<html><body></body></html>') do |page|
      install_topic_view_probe(page)
      results = topic_views(page, [{ html: '<h1>Original account</h1><p>Original source words.</p>', markdown: '' },
                                   { html: '<h1>Revised account</h1><p>Revised source words.</p>',
                                     markdown: 'Original source words.' }, { markdown: 'Unrelated caller words.' }])
      expect(results.map { |result| result['calls'] }).to eq([1, 2, 2])
      expect(results.first['markdown']).to include('Original source words.')
      results.drop(1).each do |result|
        expect(result['markdown']).to include('Revised source words.')
        expect(result['markdown']).not_to include('Original source words.', 'Unrelated caller words.')
      end
    end
  end

  it 'keeps the supplied fallback only when no source HTML exists' do
    with_url_page('https://publication.example.test/account', '<html><body></body></html>') do |page|
      install_topic_view_probe(page)
      results = topic_views(page, [{ html: '', markdown: 'First fallback.' },
                                   { html: '<p>Actual source words.</p>', markdown: 'Not the source.' },
                                   { html: '', markdown: 'Second fallback.' }])
      expect(results.first).to include('html' => nil, 'markdown' => 'First fallback.', 'calls' => 0)
      expect(results[1]).to include('markdown' => 'Actual source words.', 'calls' => 1)
      expect(results.last).to include('html' => nil, 'markdown' => 'Second fallback.', 'calls' => 1)
    end
  end
end
