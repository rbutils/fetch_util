# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil unchanged topic views' do
  include_context 'extractor integration helpers'

  def topic_view_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);', <<~JAVASCRIPT
        window.topicViewProbe = function(html, markdown) {
          var original = markdownFor, calls = 0;
          markdownFor = function() { calls++; return original.apply(this, arguments); };
          try {
            var view = multiTopicExtractionView({html:html}, markdown);
            return {html:view.root && view.root.innerHTML, markdown:view.markdown, calls:calls};
          } finally { markdownFor = original; }
        };
        })(window);
      JAVASCRIPT
    )
  end

  def topic_view(page, html, markdown)
    page.evaluate("topicViewProbe(#{html.to_json}, #{markdown.to_json})")
  end

  it 'keeps every supplied material unit and reference without converting an unchanged HTML view again' do
    html = (1..240).map do |index|
      "<section><h2>Unit #{index}</h2><p>Published words #{index} remain.</p>" \
        "<a href='https://publication.example.test/ref/#{index}'>Reference #{index}</a>" \
        "<pre>value_#{index} = 1;</pre><table><tr><td>Field #{index}</td></tr></table></section>"
    end.join
    markdown = (1..240).map do |index|
      "## Unit #{index}\n\nPublished words #{index} remain.\n\n" \
        "[Reference #{index}](https://publication.example.test/ref/#{index})\n\n" \
        "```\nvalue_#{index} = 1;\n```\n\n| Field #{index} |\n| --- |\n"
    end.join("\n")
    with_url_page('https://publication.example.test/reference', '<html><body></body></html>') do |page|
      page.add_script_tag(content: topic_view_source)
      result = topic_view(page, html, markdown)
      expect(result['markdown']).to eq(markdown)
      expect(result['calls']).to eq(0)
      (1..240).each do |index|
        expect(result['html']).to include("Unit #{index}", "ref/#{index}", "value_#{index}", "Field #{index}")
      end
    end
  end

  it 'rebuilds the view after removing actual related or navigation material' do
    html = '<article><h1>Owned account</h1><p>The complete authored account remains.</p>' \
           '<a href="https://publication.example.test/source">Primary reference</a></article>' \
           '<aside><p>Foreign related account.</p></aside><nav>Foreign navigation.</nav>'
    with_url_page('https://publication.example.test/account', '<html><body></body></html>') do |page|
      page.add_script_tag(content: topic_view_source)
      result = topic_view(page, html, 'Owned account. Foreign related account. Foreign navigation.')
      expect(result['calls']).to eq(1)
      expect(result['markdown']).to include('The complete authored account remains.', 'publication.example.test/source')
      expect(result['markdown']).not_to include('Foreign related account', 'Foreign navigation')
      expect(result['html']).not_to include('<aside', '<nav')
    end
  end

  it 'derives missing Markdown from the complete source and does not retain conversion state between calls' do
    with_url_page('https://publication.example.test/account', '<html><body></body></html>') do |page|
      page.add_script_tag(content: topic_view_source)
      html = '<h1>Published account</h1><p>A source paragraph remains.</p>'
      missing = topic_view(page, html, '')
      expect(missing['calls']).to eq(1)
      expect(missing['markdown']).to include('A source paragraph remains.')
      supplied = topic_view(page, html, 'An already rendered complete account.')
      expect(supplied).to include('calls' => 0, 'markdown' => 'An already rendered complete account.')
    end
  end
end
