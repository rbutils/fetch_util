# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Promoted complementary article siblings' do
  include_context 'extractor integration helpers'

  def clean_selected_article(page, html)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).filter_map do |path|
      File.read(File.join(root, 'websieve', path)) unless path.empty? || path.start_with?('#')
    end.join("\n")
    source.sub!('})(window);', 'window.__cleanSelectedArticle = contentWithoutTerminalArticleFurniture; })(window);')
    page.add_script_tag(content: source)
    page.evaluate(<<~JS)
      JSON.stringify(window.__cleanSelectedArticle({contentType: 'article', html: #{html.to_json},
        textContent: 'The complete article body remains material.'}))
    JS
  end

  it 'removes only a short transformed profile-and-recents aside outside the article' do
    html = <<~HTML
      <main><article><h1>Public travel report</h1><p>The original report has substantive prose and evidence for readers.</p></article></main>
      <aside id="sidebar"><div>Profile: the author</div><div>Recent posts: unrelated report</div></aside>
    HTML
    selected = <<~HTML
      <div><article><h1>Public travel report</h1><p>The original report has substantive prose and evidence for readers.</p></article>
      <div id="sidebar"><p>Profile: the author</p><p>Recent posts: unrelated report</p></div></div>
    HTML
    with_url_page('https://reports.example/travel/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = JSON.parse(clean_selected_article(page, selected))

      expect(result.fetch('html')).to include('The original report has substantive prose')
      expect(result.fetch('html')).not_to include('Profile: the author', 'Recent posts: unrelated report')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains editorial and linked complementary sections with the same visible words' do
    html = <<~HTML
      <main><article><h1>Public travel report</h1><p>The complete article remains visible.</p></article></main>
      <aside id="sidebar"><p>Profile: an independent interview with the artist and their work.</p>
        <a href="/interview">Recent posts: read the interview</a></aside>
    HTML
    selected = <<~HTML
      <div><article><h1>Public travel report</h1><p>The complete article remains visible.</p></article>
      <div id="sidebar"><p>Profile: an independent interview with the artist and their work.</p>
        <a href="/interview">Recent posts: read the interview</a></div></div>
    HTML
    with_url_page('https://reports.example/travel/report', html) do |page|
      result = JSON.parse(clean_selected_article(page, selected))

      expect(result.fetch('html')).to include('Profile: an independent interview', '/interview')
    end
  end
end
