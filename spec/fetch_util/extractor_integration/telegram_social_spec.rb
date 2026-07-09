# frozen_string_literal: true

RSpec.describe 'Telegram public extractor integration' do
  include_context 'extractor integration helpers'

  def telegram_fixture(name)
    fixture_contents(File.expand_path("../../fixtures/#{name}", __dir__))
  end

  it 'extracts one public preview message as a Telegram post' do
    extract_from_url('https://t.me/s/examplechannel/42', telegram_fixture('telegram_public_message.html')) do |payload|
      expect(payload).to include(
        'contentType' => 'social',
        'socialKind' => 'post',
        'platform' => 'Telegram',
        'handle' => '@examplechannel',
        'community' => '@examplechannel',
        'publishedTime' => '2026-07-10T12:34:56+00:00'
      )
      expect(payload['byline']).to eq('Example Channel')
      expect(payload['markdown']).to include('A public focal message with')
      expect(payload['markdown']).to include('[release notes](https://example.com/release-notes)')
      expect(payload['markdown']).not_to include('Second retained channel update')
    end
  end

  it 'uses a current preview message permalink when the card omits data-post' do
    extract_from_url('https://t.me/s/examplechannel/42', telegram_fixture('telegram_current_message.html')) do |payload|
      expect(payload).to include(
        'contentType' => 'social',
        'socialKind' => 'post',
        'platform' => 'Telegram',
        'handle' => '@examplechannel',
        'community' => '@examplechannel',
        'publishedTime' => '2026-07-10T12:34:56+00:00'
      )
      expect(payload['markdown']).to include('Synthetic focal message')
      expect(payload['markdown']).to include('[sample link](https://example.com/useful)')
      expect(payload['markdown']).not_to include('Adjacent channel update')
    end
  end

  it 'classifies a preview retaining multiple message cards as a Telegram feed' do
    extract_from_url('https://t.me/s/examplechannel', telegram_fixture('telegram_public_channel.html')) do |payload|
      expect(payload).to include(
        'contentType' => 'social',
        'socialKind' => 'feed',
        'platform' => 'Telegram',
        'handle' => '@examplechannel',
        'community' => '@examplechannel'
      )
      expect(payload['markdown']).to include('First retained fixture update')
      expect(payload['markdown']).to include('Second retained fixture update')
    end
  end

  it 'leaves header-only channel shells untyped' do
    extract_from_url('https://t.me/s/examplechannel', telegram_fixture('telegram_channel_shell.html')) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload.values_at('socialKind', 'platform', 'handle', 'community')).to all(be_nil)
    end
  end

  it 'keeps Telegraph article extraction unchanged' do
    extract_from_url('https://telegra.ph/fixture-article-07-10', telegram_fixture('telegraph_article.html')) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['siteName']).to eq('Telegraph')
      expect(payload['markdown']).to include('This standalone Telegraph article remains an article')
      expect(payload.values_at('socialKind', 'platform', 'handle', 'community')).to all(be_nil)
    end
  end

  it 'preserves Telegram login shells as interstitials' do
    extract_from_url('https://t.me/examplechannel', telegram_fixture('telegram_login_shell.html')) do |payload|
      expect(payload['contentType']).to eq('interstitial')
      expect(payload['warnings']).to include('auth_or_login_interstitial')
      expect(payload.values_at('socialKind', 'platform', 'handle', 'community')).to all(be_nil)
    end
  end

  it 'does not classify Telegram-shaped cards on other hosts' do
    extract_from_url('https://example.com/s/examplechannel/42', telegram_fixture('telegram_current_message.html')) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload.values_at('socialKind', 'platform', 'handle', 'community')).to all(be_nil)
    end
  end
end
