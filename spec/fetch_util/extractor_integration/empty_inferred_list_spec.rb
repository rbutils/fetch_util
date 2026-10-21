require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Empty inferred lists preserve existing material' do
  include_context 'extractor integration helpers'

  def with_empty_list_guard(page, force_empty_candidate: false)
    inject_standalone_extractor(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, 'websieve', entry))
    end.join("\n")
    if force_empty_candidate
      source.sub!(
        "    var candidate = null;\n\n    if (indexListAllowed",
        "    var candidate = {contentType: 'list', html: '<main></main>', markdown: '', textContent: '', readerMode: false};\n" \
          "    indexListAllowed = false;\n\n    if (indexListAllowed"
      ) || raise('index candidate boundary missing')
      source.sub!(
        '    if (candidate && !emptyListCandidateLosesContent(content, candidate) &&',
        '    if (candidate && !(window.__emptyIndexCandidateChecked = true, emptyListCandidateLosesContent(content, candidate)) &&'
      ) || raise('empty index guard boundary missing')
    end
    marker = '"fetch-util:standalone-api:v1"'
    raise 'private delivery boundary changed' unless source.scan(marker).length == 1

    source = source.sub(marker, '(function(api) { global.FetchUtilExtract = api; global.__emptyListGuard = emptyListCandidateLosesContent; })')
    page.add_script_tag(content: source)
    yield
  end

  it 'retains the visible authentication explanation instead of an empty index candidate' do
    html = <<~HTML
      <html><head><title>Sign in to research workspace</title></head><body>
      <div class='login-screen'>
        <h1>Sign in to research workspace</h1>
        <p>Please sign in to continue. This public workspace requires an account before you can continue to its research collections.</p>
        <form action='/login'><label>Email<input type='email' name='email'></label>
          <label>Password<input type='password' name='password'></label><button>Sign in</button></form>
      </div></body></html>
    HTML

    with_url_page('https://access.publication.example.test/login', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = with_empty_list_guard(page, force_empty_candidate: true) do
        page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      end

      expect(page.evaluate('window.__emptyIndexCandidateChecked')).to eq(true)
      expect(payload.fetch('contentType')).to eq('interstitial')
      expect(payload.fetch('readerMode')).to eq(false)
      expect(payload.fetch('warnings')).to include('auth_or_login_interstitial')
      expect(payload.fetch('markdown')).to include('This public workspace requires an account before you can continue to its research collections.')
      expect(payload.fetch('markdown')).to include('Access notice: login or account required')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'protects complete non-reader prose without changing its type or program text' do
    with_url_page('https://access.publication.example.test/examples', '<main><h1>Guard examples</h1></main>') do |page|
      with_empty_list_guard(page) do
        decisions = page.evaluate(<<~'JS')
          (function() {
            var empty = { contentType: 'list', markdown: '', textContent: '', html: '<main></main>' };
            return ['article', 'interstitial', 'list'].map(function(type) {
              var content = { contentType: type, readerMode: false, markdown: 'Complete visible prose.\n\n```\nconst marker = "<login>unchanged</login>";\n```' };
              var before = JSON.stringify(content);
              return { blocked: window.__emptyListGuard(content, empty), unchanged: before === JSON.stringify(content) };
            });
          })()
        JS
        expect(decisions).to eq(Array.new(3) { { 'blocked' => true, 'unchanged' => true } })
      end
    end
  end

  it 'keeps nonempty candidates and real item evidence eligible, and does not invent current material' do
    with_url_page('https://access.publication.example.test/controls', '<main><h1>Candidate controls</h1></main>') do |page|
      with_empty_list_guard(page) do
        decisions = page.evaluate(<<~'JS')
          (function() {
            var guard = window.__emptyListGuard;
            var current = { readerMode: false, markdown: 'Existing complete material' };
            var candidates = [
              { contentType: 'list', markdown: 'A real visible record' },
              { contentType: 'list', markdown: '', itemCount: 1 },
              { contentType: 'list', markdown: '', listExtraction: { items: [{ title: 'Physical record' }] } },
              { contentType: 'list', markdown: '', listSourceItems: [{ title: 'Source record' }] },
              { contentType: 'list', markdown: '', html: '<table><tr><td><a href="https://records.example.test/one">Physical record</a></td></tr></table>' },
              { contentType: 'article', markdown: '' }
            ];
            return { permitted: candidates.map(function(candidate) { return !guard(current, candidate); }),
              emptyCurrent: guard({ readerMode: false, markdown: '' }, { contentType: 'list', markdown: '' }),
              absentCurrent: guard(null, { contentType: 'list', markdown: '' }) };
          })()
        JS
        expect(decisions).to eq('permitted' => Array.new(6, true), 'emptyCurrent' => false, 'absentCurrent' => false)
      end
    end
  end
end
