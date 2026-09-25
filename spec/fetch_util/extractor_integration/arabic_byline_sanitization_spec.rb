# frozen_string_literal: true

RSpec.describe 'FetchUtil Arabic byline sanitization' do
  include_context 'extractor integration helpers'

  def page_with_author(author)
    <<~HTML
      <html><head><title>Regional water update</title><meta name="author" content="#{author}"></head>
      <body><main><article><h1>Regional water update</h1>
        <p>Water officials published a regional update after reviewing reservoir levels.</p>
        <p>The report describes the current supply and expected planning work.</p>
      </article></main></body></html>
    HTML
  end

  it 'drops an Arabic writer label when no name follows it' do
    extract_from_url('https://publisher.example/article/water-123456', page_with_author('كتب:')) do |payload|
      expect(payload['byline']).to be_nil
    end
  end

  it 'removes a leading Arabic writer label but preserves the named author' do
    extract_from_url('https://publisher.example/article/water-123456', page_with_author('كتب: إبراهيم سعيد')) do |payload|
      expect(payload['byline']).to eq('إبراهيم سعيد')
    end
  end
end
