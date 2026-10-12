# frozen_string_literal: true

RSpec.describe 'FetchUtil custom-thread candidate work' do
  include_context 'extractor integration helpers'

  def thread_candidate_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.customThreadEvidence = socialCustomThreadEvidence;
      })(window);
    JAVASCRIPT
  end

  it 'retains every ordinary record without thread visibility work' do
    records = (1..200).map { |number| "<p><a href='/records/#{number}'>Published record #{number}</a></p>" }.join
    html = "<main>#{records}</main>"
    with_url_page('https://publication.example.test/reports', html) do |page|
      page.add_script_tag(content: thread_candidate_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          var original = window.getComputedStyle;
          var descriptor = Object.getOwnPropertyDescriptor(window, 'getComputedStyle');
          var before = document.body.innerHTML;
          var calls = 0;
          window.getComputedStyle = function() { calls += 1; return original.apply(this, arguments); };
          try {
            return {evidence: customThreadEvidence(), calls: calls, unchanged: before === document.body.innerHTML,
              records: Array.from(document.querySelectorAll('main a')).map(function(node) { return node.textContent; })};
          } finally {
            if (descriptor) Object.defineProperty(window, 'getComputedStyle', descriptor);
            else delete window.getComputedStyle;
          }
        })()
      JAVASCRIPT
      expect(result).to include('evidence' => nil, 'calls' => 0, 'unchanged' => true)
      expect(result.fetch('records')).to eq((1..200).map { |number| "Published record #{number}" })
    end
  end

  it 'keeps complete visible replies with their post owner and source order' do
    html = <<~HTML
      <main>
        <record-comment id="preceding">This preceding record is not a reply to the following post.</record-comment>
        <record-post id="post"><h1>Shared garden report</h1><p>Neighbors publish the complete garden report together.</p></record-post>
        <record-comment id="first"><p>I can bring the seeds and tools.</p><a href="/resources/seeds">Seed resource</a></record-comment>
        <record-comment id="hidden" hidden>This material is hidden in the physical source.</record-comment>
        <aside><record-comment id="aside">This belongs to another source region.</record-comment></aside>
        <form><record-comment id="form">This belongs to an interface form.</record-comment></form>
        <other-comment id="other">This belongs to a different custom element family.</other-comment>
        <record-comment id="second"><blockquote>Quoted published reply.</blockquote><p>I will organize delivery.</p></record-comment>
      </main>
      <main><record-comment id="outside">This belongs to a different main owner.</record-comment></main>
    HTML
    with_url_page('https://publication.example.test/discussions/garden', html) do |page|
      page.add_script_tag(content: thread_candidate_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          var before = document.body.innerHTML;
          var evidence = customThreadEvidence();
          return {post: evidence.post.id, replies: evidence.comments.map(function(node) { return node.id; }),
            texts: evidence.comments.map(function(node) { return node.textContent; }),
            resource: evidence.comments[0].querySelector('a').getAttribute('href'),
            unchanged: before === document.body.innerHTML};
        })()
      JAVASCRIPT
      expect(result).to include(
        'post' => 'post', 'replies' => %w[first second],
        'resource' => '/resources/seeds', 'unchanged' => true
      )
      expect(result.fetch('texts').join(' ')).to include(
        'I can bring the seeds and tools.', 'Quoted published reply.', 'I will organize delivery.'
      )
    end
  end
end
