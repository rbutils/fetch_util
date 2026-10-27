# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'digest'

RSpec.describe 'Completed ordinary browser work retirement' do
  include_context 'extractor integration helpers'

  it 'retains the complete compiled result and source before opting in after group release' do
    program = "first_value('<kept>')\n\nlast_value('&complete')"
    html = <<~HTML
      <title>Completed ordinary reference</title>
      <link rel='canonical' href='https://publication.example.test/reference.html'>
      <script type='application/ld+json'>{"@context":"https://schema.org","@type":"WebPage",
        "@id":"https://publication.example.test/reference.html","name":"Completed ordinary reference"}</script>
      <article><h1>Completed ordinary reference</h1>
      <p>Complete published prose retains every authored word and the
      <a href='/reference?group=all&amp;variant=2#complete'>complete declared reference</a>.</p>
      <pre><code>first_value('&lt;kept&gt;')

      last_value('&amp;complete')</code></pre>
      <p>Independent closing prose retains <strong>its complete emphasis</strong>.</p>
      <p style='display:none'>Unpublished reference text.</p>
      </article>
    HTML
    with_url_page('https://publication.example.test/reference.html', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      calls = []
      properties = nil
      allow(page).to receive(:command).and_wrap_original do |original, method, **parameters|
        calls << [method, parameters]
        response = original.call(method, **parameters)
        if method == 'Runtime.getProperties' && response.fetch('result').any? { |row| row['name'] == 'owned' }
          properties = response.fetch('result')
        end
        response
      end
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      parser = 'import sys; from markdown_it import MarkdownIt; print(MarkdownIt("commonmark").render(sys.stdin.read()))'
      rendered, error, status = Open3.capture3('python3', '-c', parser, stdin_data: payload.fetch('markdown'))
      expect(status.success?).to be(true), error
      expected_paragraphs = [
        'Complete published prose retains every authored word and the complete declared reference.',
        'Independent closing prose retains its complete emphasis.'
      ]
      [[Nokogiri::HTML.fragment(payload.fetch('html')), program],
       [Nokogiri::HTML.fragment(rendered), "#{program}\n"]].each do |root, literal|
        expect(root.css('pre').map(&:text)).to eq([literal])
        expect(root.css('a').map { |node| [node.text, node['href']] }).to eq(
          [['complete declared reference', 'https://publication.example.test/reference?group=all&variant=2#complete']]
        )
        expect(root.css('strong').map(&:text)).to eq(['its complete emphasis'])
        expect(root.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to eq(expected_paragraphs)
        expect(root.text).not_to include('Unpublished reference text.')
      end
      source = FetchUtil::Extractor::OwnedEvaluation.instance_method(:call).source_location.first
      expected_source = File.join(ENV.fetch('FETCH_UTIL_BOUND_SOURCE_ROOT', File.expand_path('../../..', __dir__)),
                                  'lib/fetch_util/extractor/owned_evaluation.rb')
      expect(Digest::SHA256.file(source).hexdigest).to eq(Digest::SHA256.file(expected_source).hexdigest)
      expect(properties).to include(hash_including('name' => 'owned', 'value' => hash_including('value' => false)))
      # All complete-material and immutability assertions precede the new protocol guard.
      expected_collection = {
        'name' => 'collectAfterFinish',
        'value' => hash_including('type' => 'boolean', 'value' => true)
      }
      expect(properties).to include(hash_including(expected_collection))
      completion = calls.each_index.select do |index|
        calls[index].last[:functionDeclaration].to_s.include?('return this.finish()')
      end
      expect(completion.length).to eq(1)
      release = calls.index { |method, _parameters| method == 'Runtime.releaseObjectGroup' }
      collections = calls.each_index.select { |index| calls[index].first == 'HeapProfiler.collectGarbage' }
      expect(collections.length).to eq(1)
      expect(collections.first).to be > release
      expect(release).to be > completion.first
    end
  end

  it 'keeps actual legacy descriptors free of any new collector command' do
    with_url_page('https://publication.example.test/legacy.html', '<h1>Original source</h1><p>Complete original body.</p>') do |page|
      before = page.evaluate('document.body.outerHTML')
      commands = []
      allow(page).to receive(:command).and_wrap_original do |original, method, **parameters|
        commands << method
        original.call(method, **parameters)
      end
      script = '({owned:false,finish:function(){return {markdown:"Complete original result"};},dispose:function(){}})'
      result = FetchUtil::Extractor::OwnedEvaluation.new(page, script, budget: 120).call
      expect(result).to eq('markdown' => 'Complete original result')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(commands).not_to include('HeapProfiler.collectGarbage')
      expect(commands.count('Runtime.releaseObjectGroup')).to eq(1)
    end
  end
end
