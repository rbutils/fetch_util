# frozen_string_literal: true

RSpec.describe 'FetchUtil community record fidelity' do
  include_context 'extractor integration helpers'

  def repeated_nodes(wrapper, count)
    (1..count).map { |index| format(wrapper, index: index) }.join
  end

  it 'preserves every Reddit comment, including comments after the former cap' do
    comments = repeated_nodes(<<~HTML, 10)
      <shreddit-comment depth="0" author="user%<index>d" score="%<index>d">
        <div slot="comment">Reddit comment %<index>d is visible.</div>
      </shreddit-comment>
    HTML
    html = <<~HTML
      <shreddit-post author="alice" comment-count="10" score="17">
        <h1 slot="title">Ruby thread</h1><div slot="text-body">A public Reddit post.</div>
      </shreddit-post>
      #{comments}
    HTML

    extract_from_url('https://www.reddit.com/r/ruby/comments/123/ruby-thread', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Reddit')
      expect(payload['markdown']).to include('Reddit comment 1 is visible.', 'Reddit comment 10 is visible.')
      expect(payload['markdown'].index('Reddit comment 1')).to be < payload['markdown'].index('Reddit comment 10')
    end
  end

  it 'preserves all Stack Overflow answers in order' do
    answers = repeated_nodes(<<~HTML, 8)
      <div class="answer" data-answerid="%<index>d">
        <div class="js-post-body">Stack Overflow answer %<index>d contains useful detail.</div>
      </div>
    HTML
    html = <<~HTML
      <div id="question"><h1 id="question-header"><a>Ruby blocks</a></h1>
        <div class="js-post-body">How do Ruby blocks work?</div>
      </div>
      <div id="answers" data-answercount="8">#{answers}</div>
    HTML

    extract_from_url('https://stackoverflow.com/questions/123/ruby-blocks', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Overflow')
      expect(payload['markdown']).to include('Stack Overflow answer 1', 'Stack Overflow answer 8')
    end
  end
end
