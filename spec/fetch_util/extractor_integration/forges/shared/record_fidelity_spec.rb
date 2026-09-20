# frozen_string_literal: true

RSpec.describe 'FetchUtil forge record fidelity' do
  include_context 'extractor integration helpers'

  it 'preserves every GitHub comment in order' do
    comments = (1..14).map do |index|
      <<~HTML
        <div class="timeline-comment"><a class="author">user#{index}</a>
          <div class="comment-body">GitHub comment #{index} contains useful detail.</div>
        </div>
      HTML
    end.join
    html = <<~HTML
      <main><h1>Issue title</h1><div class="discussion-timeline">
        <div class="timeline-comment"><a class="author">opener</a>
          <div class="comment-body">Opening issue body with enough detail.</div>
        </div>
        #{comments}
      </div></main>
    HTML

    extract_from_url('https://github.com/acme/project/issues/42', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'GitHub')
      expect(payload['markdown']).to include('GitHub comment 1', 'GitHub comment 14')
      expect(payload['markdown'].index('GitHub comment 1')).to be < payload['markdown'].index('GitHub comment 14')
    end
  end
end
