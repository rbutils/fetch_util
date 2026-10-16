# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil format classification work' do
  include_context 'extractor integration helpers'

  def format_demand_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);', <<~JAVASCRIPT
        window.formatDemandProbe = function(html, fields) {
          var root = document.createElement("div"); root.innerHTML = html;
          var content = Object.assign({html:html, title:"Reference manual", contentType:"article",
            textContent:root.textContent}, fields || {});
          var markdown = markdownFor(html), before = JSON.stringify(content), source = document.body.innerHTML;
          var converter = markdownFor, evidence = newsletterStructuralEvidence, calls = 0, statistics = 0;
          markdownFor = function() { calls++; return converter.apply(this, arguments); };
          newsletterStructuralEvidence = function() { statistics++; return evidence.apply(this, arguments); };
          try {
            var format = detectContentFormat({title:content.title}, content, markdown);
            return {format:format, calls:calls, statistics:statistics, markdown:markdown,
              html:content.html, contentUnchanged:before === JSON.stringify(content),
              sourceUnchanged:source === document.body.innerHTML};
          } finally { markdownFor = converter; newsletterStructuralEvidence = evidence; }
        };
        window.formatViewFreshnessProbe = function() {
          var converter = markdownFor, originalUrl = location.href, base = document.createElement("base");
          var content = {html:"<p>Owned text <a href='detail'>Reference</a></p><nav>Foreign links</nav>"};
          var calls = 0, values = [], roots = [];
          function convert() { calls++; return converter.apply(this, arguments); }
          function read() {
            var view = multiTopicExtractionView(content, "Unrelated caller summary");
            roots.push(view.root); values.push({calls:calls, html:view.root.innerHTML, markdown:view.markdown});
          }
          markdownFor = convert;
          try {
            read(); roots[0].textContent = "Mutated isolated view"; read();
            base.href = "https://publication.example.test/changed/"; document.head.prepend(base); read();
            history.replaceState(null, "", "/reference/revised"); read();
            markdownFor = function() { return convert.apply(this, arguments); }; read();
            content.html = "<p>Revised owned text</p>"; read();
            return {values:values, distinctRoots:new Set(roots).size};
          } finally { markdownFor = converter; base.remove(); history.replaceState(null, "", originalUrl); }
        };
        })(window);
      JAVASCRIPT
    )
  end

  def format_demand(html, fields = {})
    document = "<html><head><title>Reference manual</title></head><body>#{html}</body></html>"
    with_url_page('https://publication.example.test/reference/manual', document) do |page|
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: format_demand_source)
      yield page.evaluate("formatDemandProbe(#{html.to_json}, #{fields.to_json})")
    end
  end

  it 'retains every guide unit without converting format text when no editorial owner is proved' do
    paragraphs = (1..603).map do |index|
      "<section><h2>Unit #{index}</h2><p>Complete authored explanation #{index} remains in source order. " \
        "This section describes the full reference and its stable behavior without shortening any published material. " \
        "Readers can use the accompanying program and reference as an independent worked example.</p>" \
        "<pre><code>value_#{index} = #{index};</code></pre>" \
        "<a href='https://publication.example.test/ref/#{index}'>Reference #{index}</a></section>"
    end.join
    html = "<article><h1>Command forms</h1>#{paragraphs}</article>"
    format_demand(html) do |result|
      expect(result).to include('format' => nil, 'calls' => 0, 'statistics' => 0,
                                'contentUnchanged' => true, 'sourceUnchanged' => true, 'html' => html)
      (1..603).each do |index|
        expect(result['markdown']).to include("## Unit #{index}", "value_#{index} = #{index};",
                                              "https://publication.example.test/ref/#{index}")
      end
    end
  end

  it 'honors DOM liveblog evidence before any format conversion or newsletter statistics' do
    html = '<article><h1>Reference manual</h1><div data-liveblog><p>Published update remains.</p></div></article>'
    format_demand(html) do |result|
      expect(result).to include('format' => 'liveblog', 'calls' => 0, 'statistics' => 0,
                                'contentUnchanged' => true, 'sourceUnchanged' => true, 'html' => html)
    end
  end

  it 'still converts a genuine editorial collection even when it also contains complete programs' do
    records = (1..6).map do |index|
      "<section><h2><a href='https://publication.example.test/report/#{index}'>Report #{index}</a></h2>" \
        "<p>Independent published reporting about record #{index} remains.</p>" \
        "<pre><code>record_#{index} = #{index};</code></pre></section>"
    end.join
    html = '<article><h1>Selected reports</h1><p>Editors selected these independent published reports for readers.</p>' \
           "#{records}<p>The complete editorial selection ends here.</p></article>"
    format_demand(html, 'title' => 'Selected reports') do |result|
      expect(result).to include('format' => 'newsletter', 'calls' => 1, 'statistics' => 1,
                                'contentUnchanged' => true, 'sourceUnchanged' => true, 'html' => html)
      (1..6).each do |index|
        expect(result['markdown']).to include("record_#{index} = #{index};",
                                              "https://publication.example.test/report/#{index}")
      end
    end
  end

  it 'keeps eager isolated views and invalidates conversion on every existing input boundary' do
    with_url_page('https://publication.example.test/reference/manual', '<html><body></body></html>') do |page|
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: format_demand_source)
      result = page.evaluate('formatViewFreshnessProbe()')
      expect(result['distinctRoots']).to eq(6)
      expect(result['values'].map { |view| view['calls'] }).to eq([1, 1, 2, 3, 4, 5])
      result['values'].each do |view|
        expect(view['html']).not_to include('Foreign links', 'Mutated isolated view')
        expect(view['markdown']).not_to include('Unrelated caller summary', 'Foreign links')
      end
      expect(result['values'].first['markdown']).to include('https://publication.example.test/reference/detail')
      expect(result['values'][2]['markdown']).to include('https://publication.example.test/changed/detail')
      expect(result['values'].last['markdown']).to eq('Revised owned text')
    end
  end
end
