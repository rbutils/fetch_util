# frozen_string_literal: true

RSpec.describe 'FetchUtil editorial frame destinations' do
  include_context 'extractor integration helpers'

  def article_with_frames(frames, lead: '')
    <<~HTML
      <!doctype html><html><head><title>Restoring the river</title>
      <meta name="generator" content="WordPress 6.8">
      <style>.hidden-frame { display: none; }</style></head><body><main><article>
        <header><h1 class="entry-title">Restoring the river</h1>#{lead}</header><div class="entry-content">
          <p>The restoration team returned to the river to measure the water quality and inspect the
          restored habitats. Their detailed report documents the improvements and the remaining work.</p>
          #{frames}
          <p>Local volunteers recorded the results throughout the year and shared their observations
          with the research team. The full findings will guide the next stage of the restoration.</p>
        </div></article></main></body></html>
    HTML
  end

  it 'retains each visible editorial frame as its source-labeled destination in place' do
    frames = <<~HTML
      <figure><iframe src="https://media.example.test/first" title="The restoration film"></iframe>
        <figcaption>Footage from the river</figcaption></figure>
      <figure><iframe src="/river-data" title="Interactive river measurements"></iframe></figure>
    HTML
    html = article_with_frames(frames)

    with_url_page('https://example-blog.test/restoration/', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      markdown = payload['markdown']
      expect(markdown).to include('[The restoration film](https://media.example.test/first)',
                                  '[Interactive river measurements](https://example-blog.test/river-data)',
                                  'Footage from the river')
      expect(markdown.index('The restoration team')).to be < markdown.index('[The restoration film]')
      expect(markdown.index('[Interactive river measurements]')).to be < markdown.index('Local volunteers')
      expect(payload['html']).to include('href="https://media.example.test/first"')
      expect(payload['html']).not_to include('<iframe')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'does not promote hidden, unlabeled, unsafe, or non-editorial frames into links' do
    frame = '<iframe src="https://media.example.test/excluded" title="Excluded player"></iframe>'
    frames = <<~HTML
      #{frame}<aside><figure>#{frame}</figure></aside>
      <figure style="display:none">#{frame}</figure><figure style="visibility:hidden">#{frame}</figure>
      <figure class="advertisement">#{frame}</figure><div class="related-posts"><figure>#{frame}</figure></div>
      <figure><iframe src="javascript:void(0)" title="Unsafe player"></iframe></figure>
      <figure><iframe src="https://media.example.test/unlabeled"></iframe></figure>
    HTML

    extract_from_url('https://example-blog.test/restoration/', article_with_frames(frames)) do |payload|
      expect(payload['markdown']).not_to include('media.example.test', 'Excluded player', 'Unsafe player', 'javascript:')
      expect(payload['html']).not_to include('<iframe')
      expect(payload['markdown']).to include('The restoration team returned to the river')
    end
  end

  it 'retains source visibility when header context detaches the WordPress body for cleanup' do
    frames = <<~HTML
      <figure class="hidden-frame"><iframe src="/hidden-film" title="Hidden film"></iframe></figure>
      <figure><iframe src="/public-film" title="Public film"></iframe></figure>
    HTML
    html = article_with_frames(frames, lead: '<p class="entry-summary">The river restoration is progressing.</p>')

    extract_from_url('https://example-blog.test/restoration/', html) do |payload|
      expect(payload['markdown']).to include('[Public film](https://example-blog.test/public-film)')
      expect(payload['markdown']).not_to include('Hidden film', 'hidden-film')
    end
  end
end
