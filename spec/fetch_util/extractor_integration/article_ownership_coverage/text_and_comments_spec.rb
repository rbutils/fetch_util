# frozen_string_literal: true

RSpec.describe 'FetchUtil visible article material and comment ownership' do
  include_context 'extractor integration helpers'

  def fixture(name)
    fixture_contents(File.expand_path("../../../fixtures/article_ownership_coverage/#{name}", __dir__))
  end

  def extract_fixture(name)
    payload = nil
    with_url_page('https://counter.example/articles/comment-boundary', fixture(name)) do |page|
      payload = extract_payload(page)
    end
    payload
  end

  it 'keeps visible DIV and SPAN closing material outside the selected body' do
    payload = extract_fixture('plain-div-closing.html')

    expect_content_type(payload, 'article')
    expect(payload['title']).to eq('Harbor repair plan')
    expect(payload['byline']).to eq('Harbor Desk')
    expect(payload['publishedTime']).to eq('2026-09-29T08:00:00Z')
    expect(payload['markdown']).to include(
      'Municipal engineers published the primary harbor repair report',
      'the north walkway reopens before the next inspection',
      'Download the signed harbor closing report PDF'
    )
    expect(payload['html']).to include('/reports/harbor-closing.pdf')
  end

  it 'keeps visible bare text nodes outside the selected body' do
    payload = extract_fixture('bare-text-closing.html')

    expect_content_type(payload, 'article')
    expect(payload['title']).to eq('Bridge inspection notice')
    expect(payload['markdown']).to include(
      'Municipal engineers published the primary harbor repair report',
      'Inspectors appended a separate unwrapped note: the west bridge remains open during all work.'
    )
  end

  it 'appends a proved outside thread despite an empty in-body discussion form' do
    payload = extract_fixture('empty-placeholder-external-comments.html')

    expect_content_type(payload, 'article')
    expect(payload['markdown']).to include(
      'The city published a complete transit repair report',
      'Alicia confirms the noon shuttle reaches the east terminal.',
      'Alicia Example',
      'Posted at 10:14 UTC'
    )
    expect(payload['html']).to include('href="https://counter.example/people/alicia"')
    expect(payload['markdown']).not_to include('Join the discussion', 'Post a reply')
  end

  it 'keeps material in-body and outside owned threads once each, in source order' do
    payload = extract_fixture('inside-and-outside-comments.html')
    markdown = payload.fetch('markdown')

    expect_content_type(payload, 'article')
    expect(markdown.scan('Inside reply: the temporary ramp works for wheelchairs.').length).to eq(1)
    expect(markdown.scan('Outside reply: the ferry operator will post the accessible boarding times.').length).to eq(1)
    expect(markdown).to include(
      'Morgan Inside', 'Posted at 10:20 UTC',
      'Lee Outside', 'Posted at 10:24 UTC'
    )
    expect(markdown.index('The harbor published a complete coastal access report'))
      .to be < markdown.index('Inside reply: the temporary ramp works for wheelchairs.')
    expect(markdown.index('Inside reply: the temporary ramp works for wheelchairs.'))
      .to be < markdown.index('Outside reply: the ferry operator will post the accessible boarding times.')
  end
end
