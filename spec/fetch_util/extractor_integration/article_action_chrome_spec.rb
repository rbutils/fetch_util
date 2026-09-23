# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Source-owned article action chrome' do
  include_context 'extractor integration helpers'

  def article_with_actions(actions)
    <<~HTML
      <html><head><title>How keyboard controllers preserve state</title></head><body>
        <main><div class="story-tile">
          <h1>How keyboard controllers preserve state</h1>
          <div class="byline"><a href="/authors/ada">Ada Researcher</a>#{actions.fetch(:toolbar)}</div>
          <div class="lead"><p>A source-owned introduction explains how keyboard controllers preserve state across each scan cycle.</p>
            #{actions.fetch(:promotion)}</div>
          <div class="article-body">
            <p>The first report paragraph describes the controller registers, the sequence of scan operations, and the observation that their values change after each poll.</p>
            <p>The second report paragraph documents the interrupt handler, the observable timing boundary, and the reason the modifier keys require separate processing.</p>
            <h2>Interpreting the recorded input</h2>
            <p>The third report paragraph preserves the original findings about source events and their relation to the final application output.</p>
          </div>
          #{actions.fetch(:comments)}
          #{actions.fetch(:reaction, "")}
        </div></main>
      </body></html>
    HTML
  end

  def article_action_probe(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__articleActionProbe = function() {
        var owner = document.querySelector('.story-tile');
        var before = owner.outerHTML;
        var clone = owner.cloneNode(true);
        stripSourceOwnedArticleActions(clone);
        stripEmptyCommentUi(clone);
        return {html: clone.outerHTML, unchanged: before === owner.outerHTML};
      };
    JS
    page.add_script_tag(content: source)
    page.evaluate('window.__articleActionProbe()')
  end

  it 'removes a proved comment/support cluster and a standalone external follow control without losing article prose' do
    html = article_with_actions(
      toolbar: <<~HTML,
        <div class="additional-actions"><span class="comments-count">3 new comments</span>
          <a class="comments-action">Add a comment</a><div class="support-box">Support the newsroom</div>
          <ul class="social-share"><li>Share</li></ul></div>
      HTML
      promotion: '<a href="https://news.example.org/follow">Add us to your favorite news sources</a>',
      comments: '<div class="comments"><a>Add a comment</a></div>',
      reaction: '<div class="article-thumbs-rating">Was this article helpful? 2 likes 1 dislike</div>'
    )

    with_url_page('https://journal.example/stories/keyboards', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      ['source-owned introduction', 'first report paragraph', 'second report paragraph',
       'third report paragraph', 'Interpreting the recorded input'].each do |part|
        expect(payload.fetch('markdown')).to include(part)
      end
      expect(payload.fetch('markdown')).to include('Ada Researcher')
      expect(payload.fetch('markdown')).not_to include('3 new comments', 'Add a comment', 'Support the newsroom',
                                                       'favorite news sources', 'Was this article helpful?')
      expect(payload.fetch('html')).not_to include('additional-actions', 'favorite news sources', 'article-thumbs-rating')
      expect(payload.fetch('textContent')).not_to include('3 new comments', 'favorite news sources', 'Was this article helpful?')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains published replies and editorial links when the controls have material descendants or no structural proof' do
    replies = (1..12).map do |index|
      "<article itemprop='comment'><p>Published correction #{index}: the verified timing detail remains part of the public discussion.</p></article>"
    end.join
    html = article_with_actions(
      toolbar: '<div class="additional-actions"><span class="comments-count">3 new comments</span>' \
               '<div class="support-box"><p>A substantive newsroom funding analysis remains editorial content.</p></div></div>',
      promotion: '<p>A published guide explains <a href="https://news.example.org/follow">how to follow a news source</a> without hiding the reference.</p>',
      comments: "<div class='comments'><a href='/comments'>Add a comment</a>#{replies}</div>",
      reaction: '<div class="article-thumbs-rating"><p>Readers found this analysis of voting systems helpful because it explains the archived sources.</p></div>'
    )

    with_url_page('https://journal.example/stories/keyboards', html) do |page|
      result = article_action_probe(page)
      expect(result.fetch('unchanged')).to be(true)
      expect(result.fetch('html')).to include('A substantive newsroom funding analysis',
                                              'how to follow a news source', 'href="/comments"',
                                              'Readers found this analysis of voting systems helpful')
      positions = (1..12).map do |index|
        phrase = "Published correction #{index}: the verified timing detail remains part of the public discussion."
        expect(result.fetch('html').scan(phrase).length).to eq(1)
        result.fetch('html').index(phrase)
      end
      expect(positions).to eq(positions.sort)
    end
  end
end
