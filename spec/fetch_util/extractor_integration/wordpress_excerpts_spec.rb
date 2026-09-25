# frozen_string_literal: true

RSpec.describe 'FetchUtil WordPress prose excerpts' do
  include_context 'extractor integration helpers'

  def wordpress_excerpt_page(lead: '', before_body: '')
    <<~HTML
      <html><head><title>Restoring the river</title><meta name="generator" content="WordPress 6.8"></head>
      <body><main><article><header><h1 class="entry-title">Restoring the river</h1>#{lead}</header>
        #{before_body}<div class="entry-content">
          <figure><img src="/river.jpg" alt="River photograph"><figcaption>A photographer's credit.</figcaption></figure>
          <blockquote><p>A quoted statement remains part of the complete article.</p></blockquote>
          <p>The restoration team returned to the <a href="/river">river</a> to inspect the restored habitats and measure the water quality.</p>
          <p>Local volunteers shared detailed observations with the research team, whose findings will guide the next restoration stage.</p>
        </div></article></main></body></html>
    HTML
  end

  it 'uses the complete owned textual lead without importing image markup or caption text' do
    text = 'The river restoration combines field research, local observations, and a public record of the work. ' * 4
    lead = "<div class='entry-summary'>#{text}<a href='/evidence'>Read the evidence.</a></div>"

    extract_from_url('https://example-blog.test/restoration/', wordpress_excerpt_page(lead: lead)) do |payload|
      expect(payload['excerpt']).to eq("#{text}Read the evidence.")
      expect(payload['markdown']).to include('River photograph', "A photographer's credit.")
      expect(payload['markdown']).to include('A quoted statement remains part of the complete article.')
      expect(payload['html']).to include('https://example-blog.test/evidence')
    end
  end

  it 'uses the first body paragraph when media or a quotation precedes the prose' do
    media = '<figure class="post-thumbnail"><img src="/lead.jpg" alt="Featured view"><figcaption>Lead credit</figcaption></figure>'

    extract_from_url('https://example-blog.test/restoration/', wordpress_excerpt_page(before_body: media)) do |payload|
      expect(payload['excerpt']).to eq('The restoration team returned to the river to inspect the restored habitats and measure the water quality.')
      expect(payload['markdown']).to include('Featured view', 'Lead credit', 'A quoted statement remains part of the complete article.')
    end
  end
end
