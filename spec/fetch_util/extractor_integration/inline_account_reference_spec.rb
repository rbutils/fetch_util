# frozen_string_literal: true

RSpec.describe 'FetchUtil authored inline account references' do
  include_context 'extractor integration helpers'

  def account_reference_article(body)
    <<~HTML
      <html><head><title>Community archive reporting</title><meta property="og:type" content="article"></head>
      <body><main><article><h1>Community archive reporting</h1>
      <p>The published archive documents the resources, journeys and records maintained by the community.</p>
      #{body}</article></main></body></html>
    HTML
  end

  def account_cleanup_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.cleanAccountFixture = function() {
        var before = document.body.innerHTML;
        var root = cleanClone(document.querySelector('article'));
        cleanupAgentRoot(root);
        return {html: root.innerHTML, sourceUnchanged: before === document.body.innerHTML};
      };
      })(window);
    JAVASCRIPT
  end

  it 'retains every authored inline reference and its destination without stripping its words' do
    paragraphs = (1..120).map do |number|
      <<~HTML
        <p>Published record #{number} explains how readers can <span><a href="/members/#{number}"><strong>become a member</strong></a></span>
        while maintaining the source archive and its independently published resources.</p>
      HTML
    end.join
    quote = '<blockquote><p>The author explained why readers should <a href="/account-notes">sign in</a> before consulting the archived account notes.</p></blockquote>'
    code = "<pre><code>account = 'become a member'\nreference = '/archive/document'</code></pre>"
    html = account_reference_article(paragraphs + quote + code)

    with_url_page('https://publication.example.test/reports/community', html) do |page|
      page.add_script_tag(content: account_cleanup_source)
      payload = page.evaluate('cleanAccountFixture()')
      (1..120).each do |number|
        expect(payload['html']).to include("Published record #{number}", "/members/#{number}")
      end
      expect(payload['html']).to include('/account-notes', "account = 'become a member'")
      expect(payload['sourceUnchanged']).to be true
    end
  end

  it 'retains an authored membership link in complete public HTML and Markdown' do
    body = '<p>Published reporting explains why readers can <span><a href="/membership-reference">become a member</a></span> while ' \
           'maintaining the complete community archive and its independently published resources.</p>'
    extract_from_url('https://publication.example.test/reports/community', account_reference_article(body)) do |payload|
      expect(payload['html']).to include('/membership-reference', 'become a member')
      expect(payload['markdown']).to include('[become a member](https://publication.example.test/membership-reference)')
    end
  end

  it 'keeps standalone, interactive, unsafe and interface-owned account controls excluded' do
    body = <<~HTML
      <p>Independent reporting supplies a complete public account of the maintained source records and references.</p>
      <p><a href="/standalone-control">become a member</a></p>
      <span><p><a href="/outside-prose-control">become a member</a></p></span>
      <p>Account access requires <a role="button" href="/button-control">sign in</a> before using this control.</p>
      <form><p>Account access requires <a href="/form-control">sign in</a> before submitting the recipient control.</p><input type="email"></form>
      <p>The interface requests <a href="javascript:account()">sign in</a> before continuing this unsafe action.</p>
      <nav><p>Account access requires <a href="/navigation-control">sign in</a> before navigating this interface.</p></nav>
      <p>Independent reporting concludes with the source-proved history and the complete authored account.</p>
    HTML
    extract_from_url('https://publication.example.test/reports/community', account_reference_article(body)) do |payload|
      %w[/standalone-control /outside-prose-control /button-control /form-control /navigation-control javascript:account()].each do |destination|
        expect(payload['html']).not_to include(destination)
        expect(payload['markdown']).not_to include(destination)
      end
      expect(payload['markdown']).to include('Independent reporting supplies', 'Independent reporting concludes')
    end
  end
end
