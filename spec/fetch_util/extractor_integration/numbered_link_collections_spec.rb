# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - numbered link collections' do
  include_context 'extractor integration helpers'

  it 'retains every chapter and short notice in a coherent visible index' do
    chapters = (1..127).map do |index|
      %(<li><a href="/chapters/#{index}">第#{index}章</a></li>)
    end
    chapters.insert(59, '<li><a href="/notices/first">公告</a></li>')
    chapters.insert(84, '<li><a href="/notices/second">後記</a></li>')
    html = "<main><h1>Complete serial index</h1><ul>#{chapters.join}</ul></main>"

    with_url_page('https://books.example/series/one', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')
      urls = (1..127).map { |index| "https://books.example/chapters/#{index}" }
      urls.insert(59, 'https://books.example/notices/first')
      urls.insert(84, 'https://books.example/notices/second')

      expect(payload['contentType']).to eq('list')
      positions = urls.map do |url|
        expect(markdown.scan("](#{url})").length).to eq(1)
        markdown.index("](#{url})")
      end
      expect(positions).to eq(positions.sort)
    end
  end

  it 'keeps paired book and chapter destinations inside their own repeated rows' do
    rows = (1..12).map do |index|
      <<~HTML
        <li><a href="/books/#{index}">Starlight story #{index}</a>
        <a href="/books/#{index}/chapter">第#{index}章</a><time>2026-09-23</time></li>
      HTML
    end.join

    with_url_page('https://books.example/', "<main><h1>Recently updated books</h1><ul>#{rows}</ul></main>") do |page|
      markdown = FetchUtil::Extractor.new.extract(page).fetch('markdown')
      (1..12).each do |index|
        expect(markdown.scan("](https://books.example/books/#{index})").length).to eq(1)
        expect(markdown.scan("](https://books.example/books/#{index}/chapter)").length).to eq(1)
      end
      expect(markdown.index('books/1)')).to be < markdown.index('books/12/chapter)')
    end
  end

  it 'does not use pagination, navigation or an unsafe peer as collection evidence' do
    paging = (1..8).map { |index| %(<li><a href="/page/#{index}">#{index}</a></li>) }.join
    chapters = (1..8).map { |index| %(<li><a href="/chapters/#{index}">第#{index}章</a></li>) }.join
    unsafe = chapters.sub('/chapters/8', 'javascript:void(0)')
    html = <<~HTML
      <main><h1>Full article</h1><p>Substantial public narrative about the study and its sources.</p>
      <ul id="pagination">#{paging}</ul><nav><ul id="navigation">#{chapters}</ul></nav>
      <ul id="unsafe">#{unsafe}</ul></main>
    HTML

    with_url_page('https://books.example/guide', html) do |page|
      root = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, 'websieve', entry))
      end.join("\n")
      source = source.sub('})(window);', 'global.NumberedCollectionTest = genericListNumberedCollectionLink; })(window);')
      page.add_script_tag(content: source)

      admitted = page.evaluate(<<~JAVASCRIPT)
        (() => ['#pagination', '#navigation', '#unsafe'].map(selector =>
          NumberedCollectionTest(document.querySelector(selector + ' a'), new WeakMap())))()
      JAVASCRIPT
      expect(admitted).to eq([false, false, false])
    end
  end
end
