# frozen_string_literal: true

RSpec.describe 'FetchUtil StackOverflow extraction' do
  include_context 'extractor integration helpers'

  it 'extracts question pages as social threads with question body and top answers' do
    fixture_path = File.expand_path('../../../fixtures/community/q_and_a/stackoverflow_question.html', __dir__)

    extract_from_url('https://stackoverflow.com/questions/11828270/how-do-i-exit-the-vim-editor', fixture_contents(fixture_path)) do |payload|
      markdown = payload['markdown']

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Overflow',
                                 'replyCount' => nil, 'community' => 'Stack Overflow', 'score' => 2800)
      expect(payload['hostAware']).to eq(true)
      expect(payload['warnings']).not_to include('multi_topic_page')
      expect(markdown).to include('# How do I open a fixture panel?')
      expect(markdown).to include('press SAMPLE<Enter> to continue')
      expect(markdown).to include('## Top Answers')
      expect(markdown).to include('### Answer 1 (accepted) - score 4500')
      expect(markdown).to include('type `run` and press Enter')
      expect(markdown).to include('### Answer 2 - score 3200')
      expect(markdown).to include('Use `save` to keep the sample')
      expect(markdown).not_to include('example user')
    end
  end

  it "extracts Stack Exchange questions together with top answers" do
    html = <<~HTML
      <html>
        <head>
          <title>How likely is it that any non-Celtic language was spoken in the British Isles when the Romans invaded? - History Stack Exchange</title>
        </head>
        <body>
          <main>
            <div class="question" id="question">
              <div class="question-header">
                <h1>How likely is it that any non-Celtic language was spoken in the British Isles when the Romans invaded?</h1>
              </div>
              <div class="user-details"><a href="/users/1/timothy">Timothy</a></div>
              <div class="js-post-body">We know from Roman writers the names of many ancient British tribes, but not much about their language boundaries.</div>
            </div>
            <div id="answers">
              <div class="answer accepted-answer">
                <span class="js-vote-count">33</span>
                <div class="user-details"><a href="/users/2/example">Example User</a></div>
                <div class="js-post-body">The answer appears to be that we do not know with certainty. Earlier languages likely existed before Celtic spread, but the evidence is fragmentary.</div>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://history.stackexchange.com/questions/68200/example", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("## Top Answers")
      expect(payload["markdown"]).to include("### Example User (accepted) - score 33")
      expect(payload["markdown"]).to include("Earlier languages likely existed before Celtic spread")
    end
  end

  it 'keeps short Stack Exchange answers in source order' do
    html = <<~HTML
      <html>
        <head><title>How should this be fetched? - History Stack Exchange</title></head>
        <body>
          <main>
            <div class="question" id="question" data-answercount="2">
              <div class="question-header"><h1>How should this be fetched?</h1></div>
              <div class="user-details"><a href="/users/1/ada">Ada</a></div>
              <div class="js-post-body">I need to preserve every visible answer in the order presented by the source.</div>
            </div>
            <div class="answer" data-answerid="10">
              <span class="js-vote-count">100</span>
              <div class="user-details"><a href="/users/2/first">First User</a></div>
              <div class="js-post-body">This longer answer appears first in the document.</div>
            </div>
            <div class="answer accepted-answer" data-answerid="11">
              <span class="js-vote-count">1</span>
              <div class="user-details"><a href="/users/3/second">Second User</a></div>
              <div class="js-post-body">Use fetch.</div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://history.stackexchange.com/questions/68201/fetch-order', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['markdown']).to include('This longer answer appears first', 'Use fetch.')
      expect(payload['markdown'].index('First User')).to be < payload['markdown'].index('Second User')
      expect(payload['html']).to include('data-answerid="10"', 'data-answerid="11"')
    end
  end
end
