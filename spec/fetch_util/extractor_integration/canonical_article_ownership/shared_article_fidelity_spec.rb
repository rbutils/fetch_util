# frozen_string_literal: true

RSpec.describe 'FetchUtil shared article ownership fidelity' do
  include_context 'extractor integration helpers'

  def extract_case(url, fixture)
    html = fixture_contents("spec/fixtures/canonical_article_ownership/#{fixture}")
    with_url_page(url, html) { |page| extract_payload(page) }
  end

  it 'preserves an owned lead and hero figure outside the article body' do
    payload = extract_case('https://counter.example/articles/harbor-repair-plan', 'owned_header_context.html')

    expect(payload['contentType']).to eq('article')
    expect(payload['markdown']).to include(
      'harbor authority published a repair plan',
      'Crews prepare the eastern pier',
      'Crews reinforcing the eastern pier',
      'first work stage begins',
      'Ferry operators will publish service notices'
    )
    expect(payload['html']).to include(
      'harbor authority published a repair plan',
      'Crews prepare the eastern pier for repairs.'
    )
  end

  it 'keeps an editorial newsletter heading and removes the signup widget' do
    payload = extract_case('https://counter.example/articles/publishing-guide', 'newsletter_editorial_heading.html')

    expect(payload['contentType']).to eq('article')
    expect(payload['markdown']).to include(
      'publication workflow',
      'transparent corrections',
      'Publishing and newsletters the easy way'
    )
    expect(payload['html']).to include('Publishing and newsletters the easy way')
    expect(payload['markdown']).not_to include('Subscribe to the newsletter', 'Sign up')
  end

  it 'keeps a separately linked nested article without replacing the canonical prose' do
    payload = extract_case('https://counter.example/articles/bridge-inspection-notice', 'foreign_nested_article_body.html')

    expect(payload['contentType']).to eq('article')
    expect(payload['title']).to eq('Bridge inspection notice')
    expect(payload['markdown']).to include(
      'The city published a notice',
      'Traffic officers will keep one lane open',
      'Separate flood response story',
      'different event, different locations'
    )
    primary_position = payload['markdown'].index('The city published a notice')
    separate_story_position = payload['markdown'].index('Separate flood response story')
    expect(primary_position).to be < separate_story_position
  end
end
