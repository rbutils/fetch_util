# frozen_string_literal: true

RSpec.describe 'FetchUtil StackOverflow extraction' do
  include_context 'extractor integration helpers'

  it 'extracts question pages as social threads with question body and top answers' do
    fixture_path = File.expand_path('../../fixtures/stackoverflow_question.html', __dir__)

    extract_from_url('https://stackoverflow.com/questions/11828270/how-do-i-exit-the-vim-editor', fixture_contents(fixture_path)) do |payload|
      markdown = payload['markdown']

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Overflow',
                                 'replyCount' => nil, 'community' => 'Stack Overflow', 'score' => 2800)
      expect(payload['hostAware']).to eq(true)
      expect(payload['warnings']).not_to include('multi_topic_page')
      expect(markdown).to include('# How do I open a fixture panel?')
      expect(markdown).to include('## Question')
      expect(markdown).to include('press SAMPLE<Enter> to continue')
      expect(markdown).to include('### Accepted answer (4500 votes)')
      expect(markdown).to include('type `run` and press Enter')
      expect(markdown).to include('### Answer (3200 votes)')
      expect(markdown).to include('Use `save` to keep the sample')
      expect(markdown).not_to include('example user')
    end
  end
end
