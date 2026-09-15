# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor empty markdown link cleanup' do
  include_context 'extractor integration helpers'

  it 'preserves a block boundary after removing an empty supporting link' do
    records = (1..8).map do |number|
      <<~HTML
        <article>
          <h3><a href="/stories/#{number}">Independent report number #{number}</a></h3>
          <p>Locally owned context for independent report number #{number}.</p>
          #{'<a href="/tracking-placeholder"></a><img src="/image-placeholder.png" alt="">' if number == 4}
        </article>
      HTML
    end
    html = <<~HTML
      <html><head><title>Daily reports</title></head><body><main>
        <h1>Daily reports</h1>
        <section><h2>Morning desk</h2>#{records.take(4).join}</section>
        <section><h2>Culture desk</h2>#{records.drop(4).join}</section>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      markdown = payload['markdown']

      expect(markdown).to include("\n\n## Culture desk\n\n- [Independent report number 5")
      expect(markdown).not_to include('tracking-placeholder', 'image-placeholder', '- ## Culture desk')
    end
  end
end
