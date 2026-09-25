# frozen_string_literal: true

RSpec.describe 'FetchUtil WordPress prose excerpts' do
  include_context 'extractor integration helpers'

  def wordpress_excerpt_page(lead: '', before_body: '', body_prefix: '')
    <<~HTML
      <html><head><title>Restoring the river</title><meta name="generator" content="WordPress 6.8"></head>
      <body><main><article><header><h1 class="entry-title">Restoring the river</h1>#{lead}</header>
        #{before_body}<div class="entry-content">
          #{body_prefix}
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

  it 'skips image-strip labels for excerpts while retaining the label and images in the article' do
    strip = '<div><div><p>As seen in:</p></div><div><img src="/partner.svg" alt="News partner"></div></div>'

    extract_from_url('https://example-blog.test/restoration/', wordpress_excerpt_page(body_prefix: strip)) do |payload|
      expect(payload['excerpt']).to start_with('The restoration team returned to the river')
      expect(payload['markdown']).to include('As seen in:', 'News partner', 'https://example-blog.test/partner.svg')
    end
  end

  it 'uses body prose after caption fields or standalone photo-credit lines without removing their content' do
    credit = 'Jabulani Mabuza, raadsvoorsitter van Eskom (Foto: Nhlanhla Phillips/African News Agency/ANA)'
    captions = [
      "<div class='wp-caption'><img src='/portrait.jpg' alt='Interview portrait'><p class='wp-caption-text'>#{credit}</p></div>",
      "<p class='wp-caption-text'>#{credit}</p>", "<p>#{credit}</p>",
      '<p>Volunteers beside the river (Photo: Field team)</p>'
    ]
    captions.each do |caption|
      extract_from_url('https://example-blog.test/restoration/', wordpress_excerpt_page(body_prefix: caption)) do |payload|
        expect(payload['excerpt']).to start_with('The restoration team returned to the river')
        expect(payload['markdown']).to include(caption.include?('Jabulani') ? credit : 'Volunteers beside the river (Photo: Field team)')
        expect(payload['html']).to include('https://example-blog.test/portrait.jpg') if caption.include?('<img')
      end
    end
  end

  it 'keeps editorial explanations, linked leads, and unrelated caption classes eligible as excerpts' do
    explanation = 'The report explains image attribution. Its example reads (Photo: Field team)'
    prefixes = {
      "<p>#{explanation}</p>" => explanation,
      '<p><a href="/interview">Field interview</a> (Photo: Field team)</p>' => 'Field interview (Photo: Field team)',
      '<p class="caption">Floods returned to the river.</p>' => 'Floods returned to the river.'
    }
    prefixes.each do |prefix, expected|
      extract_from_url('https://example-blog.test/restoration/', wordpress_excerpt_page(body_prefix: prefix)) do |payload|
        expect(payload['excerpt']).to eq(expected)
      end
    end
  end

  it 'preserves short or linked leads and colon-ending prose with an independent body' do
    prefixes = {
      '<p>Floods returned.</p>' => 'Floods returned.',
      '<p>A <a href="/breakthrough">breakthrough</a>.</p>' => 'A breakthrough.',
      '<p>The results follow:</p>' => 'The results follow:'
    }

    prefixes.each do |prefix, expected|
      extract_from_url('https://example-blog.test/restoration/', wordpress_excerpt_page(body_prefix: prefix)) do |payload|
        expect(payload['excerpt']).to eq(expected)
      end
    end
  end
end
