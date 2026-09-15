# frozen_string_literal: true

RSpec.describe 'Article-owned interface widgets' do
  include_context 'extractor integration helpers'

  it 'removes empty discussion and recommendation loaders without deleting loaded content' do
    html = <<~HTML
      <html><head><title>Independent local report</title></head><body><article>
      <h1>Independent local report</h1><p>The investigation describes the original records and the evidence supporting its conclusions. Readers can consult the complete public record and evaluate the qualifications explained throughout this detailed article.</p>
      <p>Contact information in the <a href="/evidence">original evidence</a> is part of the account and remains relevant to independent verification.</p>
      <div class="article-call-to-action"><div>Send your story to the newsroom.</div><a href="/submit">Send a story</a><a href="/careers">Work with us</a></div>
      <div class="article-read-more-container"><div class="main-loader"><div>Preparing recommended entries</div></div></div>
      <div class="comments-container"><div class="main-loader"><div>Preparing the discussion</div></div>
        <div class="comment-body"><p>A reader supplied an additional source that qualifies the report and explains the practical context.</p>
          <div class="reply-body"><p>The author replied with the original measurement and a useful clarification.</p></div></div>
      </div>
      <div class="article-read-more-container"><div class="main-loader"><p>A fully loaded explanation with a <a href="/source">supporting source</a> is substantive content despite its presentation class.</p></div></div>
      <div class="comments-container"><div class="main-loader"><div class="author">Independent observer</div><span>A first-hand observation is material even when this wrapper retains its loader class.</span></div></div>
      <div class="loader"><div>An independently described operational state remains part of this account.</div></div>
      </article></body></html>
    HTML
    with_url_page('https://journal.example/report', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = result.fetch('markdown')
      expect(markdown).not_to include('Preparing recommended entries', 'Preparing the discussion', 'Send a story', 'Work with us')
      expect(markdown).to include('A reader supplied', 'The author replied', 'A fully loaded explanation')
      expect(markdown).to include('[original evidence](https://journal.example/evidence)', '[supporting source](https://journal.example/source)')
      expect(markdown).to include('An independently described operational state')
      expect(markdown).to include('Independent observer', 'A first-hand observation')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'preserves substantive explanations within call-to-action presentation wrappers' do
    html = <<~HTML
      <html><head><title>Public evidence and support</title></head><body><article>
      <h1>Public evidence and support</h1><p>This detailed account explains the evidence and the methods used to collect it. The independently published observations provide important context for readers who want to understand the conclusions and reproduce the original investigation.</p>
      <div class="article-call-to-action"><h2>How the evidence was funded</h2><p>The public support programme funded independent measurements, and the authors disclose the exact relationship here. This explanation is material to the account rather than a short request for donations.</p><a href="/funding">Funding record</a></div>
      </article></body></html>
    HTML
    extract_from_url('https://journal.example/evidence', html) do |result|
      expect(result.fetch('markdown')).to include('How the evidence was funded', 'independent measurements', 'Funding record')
    end
  end
end
