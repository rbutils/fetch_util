# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'fetch_util ordered-list continuation ownership' do
  include_context 'extractor integration helpers'

  [[1, 12, 10], [98, 4, 2]].each do |start, count, nested_index|
    it "retains complete nested requirements beneath ordered marker #{start + nested_index}" do
      requirements = ['Publish the complete source', 'Describe every local change', 'Retain the original attribution']
      labels = Array.new(count) { |index| "Publication requirement #{index + 1}" }
      items = labels.each_with_index.map do |label, index|
        nested = index == nested_index ? "<ul>#{requirements.map { |text| "<li>#{text}</li>" }.join}</ul>" : ''
        "<li>#{label}#{nested}</li>"
      end.join
      program = "count = 3\nprint(count)"
      html = <<~HTML
        <!doctype html><html><head><title>Publication requirements</title></head>
        <body class="md-typeset"><main><article class="md-content__inner md-typeset">
          <h1>Publication requirements</h1>
          <p>These independently authored requirements remain in their complete publication order.</p>
          <ol start="#{start}">#{items}</ol>
          <pre><code class="language-python">#{program}</code></pre>
          <p>Read the complete <a href="guide">publication guide</a> before preparing a revision.</p>
        </article></main></body></html>
      HTML

      with_url_page('https://docs.publication.example.test/requirements/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        result = extract(page)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        public_body = Nokogiri::HTML5.fragment(result.fetch('html'))
        outer = public_body.at_css('ol')
        expect(outer['start']).to eq(start.to_s)
        expect(outer.xpath('./li').size).to eq(count)
        expect(outer.xpath('./li').map { |item| item.children.reject(&:element?).map(&:text).join.strip }).to eq(labels)
        expect(outer.xpath('./li')[nested_index].css('ul > li').map(&:text)).to eq(requirements)
        expect(public_body.css('pre code').map(&:text)).to eq([program])
        markdown = result.fetch('markdown')
        prefix_width = "#{start + nested_index}.  ".size
        expected = requirements.map { |text| "#{" " * prefix_width}-   #{text}" }
        expect(markdown.lines.grep(/Publish the complete|Describe every|Retain the original/).map(&:chomp)).to eq(expected)
        expect(markdown).to include("```python\n#{program}\n```")
        expect(markdown).to include('[publication guide](https://docs.publication.example.test/requirements/guide)')
        labels.each { |label| expect(markdown.scan(/#{Regexp.escape(label)}(?!\d)/).size).to eq(1) }
      end
    end
  end
end
