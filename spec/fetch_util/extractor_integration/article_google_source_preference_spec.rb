# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Google source-preference article controls' do
  include_context 'extractor integration helpers'

  def article_with_preference_control(anchor)
    <<~HTML
      <html><head><title>Regional transport inspection</title></head><body>
        <main><article class="preference-control-test">
          <h1>Regional transport inspection</h1>
          <div class="standalone-control">#{anchor}
            <div class="article-content">
              <p>The report describes the regional timetable and links to its <a href="/references/primary">primary source record</a>.</p>
              <blockquote><p>The archived notice remains a quoted source statement.</p><a href="/references/notice">Archived notice</a></blockquote>
              <figure><img src="/media/route-map.png" alt="Route map"><figcaption>The published route map and caption remain part of the article.</figcaption></figure>
            </div>
          </div>
        </article></main>
      </body></html>
    HTML
  end

  def preference_control_probe(page)
    root = File.expand_path('../../..', __dir__)
    source_paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
    source_paths.reject! { |path| path.empty? || path.start_with?('#') }
    source = source_paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__googlePreferenceProbe = function() {
        var owner = document.querySelector('article.preference-control-test');
        var before = document.body.innerHTML;
        var clone = owner.cloneNode(true);
        stripGoogleSourcePreferenceControl(owner, clone);
        return {html: clone.outerHTML, unchanged: before === document.body.innerHTML};
      };
    JS
    page.add_script_tag(content: source)
    page.evaluate('window.__googlePreferenceProbe()')
  end

  def reader_paragraph_provenance_probe(page)
    inject_standalone_extractor(page)
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
    paths.reject! { |path| path.empty? || path.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    source = source.delete_suffix(outro) + <<~JS + outro
      var stripGoogleSourcePreferenceControlBeforeProbe = stripGoogleSourcePreferenceControl;
      stripGoogleSourcePreferenceControl = function(sourceRoot, cloneRoot, sourceClones) {
        var result = stripGoogleSourcePreferenceControlBeforeProbe(sourceRoot, cloneRoot, sourceClones);
        var sourceBody = document.querySelector('.reader-source-body');
        var sourceParagraphs = Array.from(sourceBody.children).filter(function(node) {
          return node.matches('p') && !elementSubtreeHidden(node);
        });
        var action = sourceRoot.querySelector('a[href*="/preferences/source"]');
        var hiddenSources = Array.from(sourceRoot.querySelectorAll('.reader-hidden-adjacent, .reader-hidden-paragraph'));
        window.__googleSourceCloneMapProof = {
          actionRemovedFromMap: !sourceClones.has(action),
          bodyPairsExact: sourceParagraphs.length === 3 && sourceParagraphs.every(function(source, index) {
            var clone = sourceClones.get(source);
            return !!clone && clone.localName === 'p' && clone.textContent === source.textContent &&
              sourceParagraphs.indexOf(source) === index;
          }),
          hiddenNodesUnmapped: hiddenSources.every(function(source) { return !sourceClones.has(source); })
        };
        return result;
      };
      window.__googleReaderParagraphProof = function() {
        var before = document.body.innerHTML;
        var sourceBody = document.querySelector('.reader-source-body');
        var sourceParagraphs = Array.from(sourceBody.children).filter(function(node) {
          return node.matches('p') && !elementSubtreeHidden(node);
        });
        var content = readabilityContent({});
        var bodySources = content && content.sourceOwnedReaderBodyParagraphSources || [];
        return {
          readerMode: content && content.readerMode,
          actionExcluded: content && !content.html.includes('Προσθήκη του regional-news.example'),
          bodySourcesExact: bodySources.length === 3 && bodySources.every(function(source, index) {
            return source === sourceParagraphs[index];
          }),
          bodySources: bodySources.map(function(source) { return source.textContent; }),
          bodySourcesNonEnumerable: !!content && !Object.prototype.propertyIsEnumerable.call(content, 'sourceOwnedReaderBodyParagraphSources'),
          cloneMap: window.__googleSourceCloneMapProof,
          sourceUnchanged: before === document.body.innerHTML
        };
      };
    JS
    page.add_script_tag(content: source)
    page.evaluate('window.__googleReaderParagraphProof()')
  end

  def reader_article_with_hidden_adjacents
    publisher = 'regional-news.example'
    label = "Προσθήκη του #{publisher} ως προτεινόμενη πηγή στην Google"
    href = "https://www.google.com/preferences/source?q=#{publisher}"
    <<~HTML
      <!doctype html><html><head><title>Regional timetable report</title></head><body>
        <main><article><h1>Regional timetable report</h1>
          <div class="inside-article">
            <div class="reader-hidden-adjacent" style="display:none"><p>Hidden sibling before the action.</p></div>
            <a href="#{href}">#{label}</a>
            <div class="reader-source-body">
              <p>First body paragraph reports the verified weekday timetable and the station sequence.</p>
              <div class="reader-hidden-paragraph" style="display:none"><p>Hidden paragraph between source records.</p></div>
              <p>Second body paragraph documents the connection times and the published service changes.</p>
              <p>Third body paragraph records the timetable's effective date and the cited regional notice.</p>
            </div>
            <div class="reader-hidden-adjacent" style="display:none"><p>Hidden sibling after the article body.</p></div>
          </div>
        </article></main>
      </body></html>
    HTML
  end

  it 'removes a typed full-intent action for an unrelated publisher without pruning article material' do
    publisher = 'regional-news.example'
    label = "Προσθήκη του #{publisher} ως προτεινόμενη πηγή στην Google"
    href = "https://www.google.com/preferences/source?q=#{publisher}"
    html = article_with_preference_control("<a href=\"#{href}\">#{label}</a>")

    with_url_page('https://independent-journal.example/reports/transport', html) do |page|
      result = preference_control_probe(page)

      expect(result.fetch('unchanged')).to be(true)
      expect(result.fetch('html')).not_to include(label, href)
      expect(result.fetch('html')).to include(
        'primary source record', '/references/primary',
        'archived notice remains a quoted source statement', '/references/notice',
        '/media/route-map.png', 'published route map and caption'
      )
    end
  end

  it 'preserves quoted, cited, incomplete, and incorrectly typed Google links' do
    publisher = 'regional-news.example'
    label = "Προσθήκη του #{publisher} ως προτεινόμενη πηγή στην Google"
    valid_href = "https://www.google.com/preferences/source?q=#{publisher}"
    cases = {
      quoted: "<blockquote><a href=\"#{valid_href}\">#{label}</a></blockquote>",
      cited: "<p>Published source reference: <a href=\"#{valid_href}\">#{label}</a></p>",
      wrong_path: "<a href=\"https://www.google.com/preferences/search?q=#{publisher}\">#{label}</a>",
      wrong_query: "<a href=\"https://www.google.com/preferences/source?q=other.example\">#{label}</a>",
      wrong_google_host: "<a href=\"https://google.com.example/preferences/source?q=#{publisher}\">#{label}</a>",
      incomplete_intent: "<a href=\"#{valid_href}\">Προσθήκη του #{publisher} στην Google</a>"
    }

    cases.each do |name, anchor|
      with_url_page("https://independent-journal.example/reports/#{name}", article_with_preference_control(anchor)) do |page|
        result = preference_control_probe(page)

        expect(result.fetch('unchanged')).to be(true)
        expect(result.fetch('html')).to include(anchor)
        expect(result.fetch('html')).to include('primary source record', 'published route map and caption')
      end
    end
  end

  it 'keeps exact Reader source-paragraph relations after pruning hidden nodes around the action' do
    with_url_page('https://independent-journal.example/reports/timetable', reader_article_with_hidden_adjacents) do |page|
      result = reader_paragraph_provenance_probe(page)

      expect(result.fetch('readerMode')).to be(true)
      expect(result.fetch('actionExcluded')).to be(true)
      expect(result.fetch('bodySourcesExact')).to be(true)
      expect(result.fetch('bodySources')).to eq(
        [
          'First body paragraph reports the verified weekday timetable and the station sequence.',
          'Second body paragraph documents the connection times and the published service changes.',
          "Third body paragraph records the timetable's effective date and the cited regional notice."
        ]
      )
      expect(result.fetch('bodySourcesNonEnumerable')).to be(true)
      expect(result.fetch('cloneMap')).to include(
        'actionRemovedFromMap' => true,
        'bodyPairsExact' => true,
        'hiddenNodesUnmapped' => true
      )
      expect(result.fetch('sourceUnchanged')).to be(true)
    end
  end
end
