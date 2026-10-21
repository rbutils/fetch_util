require 'spec_helper'
require 'nokogiri'
require 'uri'

RSpec.describe 'Source-owned public access introductions' do
  include_context 'extractor integration helpers'

  def access_page(introduction, outside: '')
    <<~HTML
      <html><head><title>Login to the research workspace</title></head><body>
      <nav><a href='/navigation'>Account navigation</a></nav>#{outside}
      <div class='access-region'>#{introduction}
        <div class='form-panel'><form action='/login'>
          <label>E-mail<input type='email' autocomplete='username'></label>
          <label>Password<input type='password'></label><button>Sign in</button>
          <p>Form-only instructions <a href='/form-help'>Form help</a></p>
        </form></div>
      </div><footer><a href='/footer'>Footer account resources</a></footer></body></html>
    HTML
  end

  def authored_introduction
    <<~HTML
      <section class='public-explanation'><h1>Explore the research workspace</h1><div>Welcome, independent researchers.</div>
        <p>Please sign in to continue. Already registered? You can begin reviewing the public examples and complete research materials.</p>
        <p>For authoring rights contact <a href='mailto:support@example.test'>the support team</a>. #{"Every independently authored observation remains available in its original order. " * 5}</p>
        <p>Need an account? <a href='/registration'>Register for the workspace</a> and retain the confirmation instructions.</p>
        <p><a href='/reference'>Complete reference</a> is the first physical reference.</p>
        <p><a href='/reference'>Complete reference</a> is a separate physical occurrence.</p>
        <pre><code>  const marker = "&lt;login&gt;literal&lt;/login&gt;";\nretain_every_value();</code></pre>
      </section>
    HTML
  end

  it 'preserves the complete authored introduction, physical repetitions and programs with an access warning' do
    html = access_page(authored_introduction)
    with_url_page('https://access.publication.example.test/login', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      source = Nokogiri::HTML5(html).at_css('.public-explanation')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = payload.fetch('markdown')

      expect(payload).to include('contentType' => 'interstitial', 'readerMode' => false, 'title' => 'Login to the research workspace')
      expect(payload.fetch('warnings')).to include('auth_or_login_interstitial')
      expect(body.css('h1').map(&:text)).to eq(source.css('h1').map(&:text))
      expect(body.css('p').map(&:text)).to eq(source.css('p').map(&:text))
      expect(body.css('pre').map(&:text)).to eq(source.css('pre').map(&:text))
      expected_links = [
        ['the support team', 'mailto:support@example.test'],
        ['Register for the workspace', 'https://access.publication.example.test/registration'],
        ['Complete reference', 'https://access.publication.example.test/reference'],
        ['Complete reference', 'https://access.publication.example.test/reference']
      ]
      expect(body.css('a').map { |link| [link.text, link['href']] }).to eq(expected_links)
      expected_paragraphs = source.css('p').map do |paragraph|
        paragraph.children.map do |child|
          child.name == 'a' ? "[#{child.text}](#{URI.join("https://access.publication.example.test/login", child["href"])})" : child.text
        end.join.strip
      end
      expect(markdown.split("\n\n")[4, expected_paragraphs.length]).to eq(expected_paragraphs)
      expect(markdown).to include('Access notice: login or account required', 'Welcome, independent researchers.',
                                  '[the support team](mailto:support@example.test)',
                                  '[Register for the workspace](https://access.publication.example.test/registration)',
                                  source.at_css('pre').text)
      expect(markdown.scan('[Complete reference](https://access.publication.example.test/reference)').length).to eq(2)
      expect(markdown.index('first physical reference')).to be < markdown.index('separate physical occurrence')
      expect(markdown).not_to include('Account navigation', 'Form-only instructions', '/form-help', '/footer')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves visible instructions while excluding hidden programs, controls and closed answers' do
    extra = <<~HTML
      <p hidden>Hidden paragraph <a href='/hidden'>Hidden destination</a></p>
      <pre style='display:none'><code>hidden_program_value();</code></pre>
      <details><summary>Closed account instructions</summary><p>Closed answer <a href='/closed'>Closed destination</a></p><pre><code>closed_program_value();</code></pre></details>
    HTML
    introduction = authored_introduction.sub('</section>', "#{extra}</section>")
    outside = "<aside>#{authored_introduction.sub("public-explanation", "aside-explanation")}</aside>"
    html = access_page(introduction, outside: outside)
    with_url_page('https://access.publication.example.test/login', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload.fetch('markdown')).to include('Closed account instructions', 'retain_every_value();')
      expect(payload.fetch('markdown')).not_to include('Hidden paragraph', '/hidden', 'hidden_program_value', 'Closed answer', '/closed', 'closed_program_value')
      expect(payload.fetch('markdown').scan('[the support team](mailto:support@example.test)').length).to eq(1)
      expect(Nokogiri::HTML5.fragment(payload.fetch('html')).css('details[open]')).to be_empty
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps the existing synthetic notice when the only prose is unrelated to the access region' do
    outside = authored_introduction.sub('public-explanation', 'unrelated-explanation')
    html = access_page('', outside: outside)
    with_url_page('https://access.publication.example.test/login', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload).to include('contentType' => 'interstitial', 'readerMode' => false, 'html' => '')
      expect(payload.fetch('warnings')).to include('auth_or_login_interstitial')
      expect(payload.fetch('markdown')).to include('Access notice: login or account required')
      expect(payload.fetch('markdown')).not_to include('mailto:support@example.test', '/registration', 'retain_every_value')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not infer a public introduction from a form owned by navigation' do
    html = <<~HTML
      <html><head><title>Login to the research workspace</title></head><body>
      <div class='region'><section><h1>Public unrelated report</h1>
      <p>Please sign in to continue. <a href='/unrelated'>Independent unrelated resource</a></p></section>
      <nav><form><input type='email'><input type='password'><button>Sign in</button></form></nav>
      </div></body></html>
    HTML
    with_url_page('https://access.publication.example.test/login', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload).to include('contentType' => 'interstitial', 'readerMode' => false, 'html' => '')
      expect(payload.fetch('markdown')).to include('Access notice: login or account required')
      expect(payload.fetch('markdown')).not_to include('https://access.publication.example.test/unrelated')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
