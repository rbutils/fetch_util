# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Discourse topics' do
  include_context 'extractor integration helpers'

  it 'extracts Discourse topic threads as social output from DOM signals' do
    html = fixture_contents(File.expand_path('../../fixtures/discourse_topic.html', __dir__))

    with_url_page('https://forum.example/t/trust-levels-explained/123', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Discourse', 'community' => nil)
      expect(payload['readerMode']).to eq(false)
      expect(payload['warnings']).to eq([])
      expect(payload['markdown']).to include('# Trust levels explained')
      expect(payload['markdown']).to include('## post by alice on 2026-06-01')
      expect(payload['markdown']).to include('First post body explains how trust levels unlock community features.')
      expect(payload['markdown']).to include('> Quoted guidance should remain visible.')
      expect(payload['markdown']).to include('Read topics')
      expect(payload['markdown']).to include('Reply constructively')
      expect(payload['markdown']).to include('## post by bob on 2026-06-02')
      expect(payload['markdown']).to include('Second post body adds moderation context for new members.')
      expect(payload['markdown']).to include('```')
      expect(payload['markdown']).to include('trust_level = 2')
    end
  end

  it 'classifies Discourse listing pages as social feeds' do
    html = fixture_contents(File.expand_path('../../fixtures/discourse_list.html', __dir__))

    with_url_page('https://forum.example/c/community', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Discourse', 'community' => nil)
      expect(payload['readerMode']).to eq(false)
      expect(payload['warnings']).to eq([])
      expect(payload['markdown']).to include('Welcome to our forum')
      expect(payload['markdown']).to include('Release notes')
      expect(payload['markdown']).to include('How to ask for help')
      expect(payload['markdown']).to include('Category feedback')
      expect(payload['markdown']).not_to include('post by')
    end
  end
end
