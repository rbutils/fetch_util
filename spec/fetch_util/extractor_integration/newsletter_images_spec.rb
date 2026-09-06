# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - newsletter image evidence' do
  include_context 'extractor integration helpers'

  def illustrated_sections(linked:)
    sections = 6.times.map do |index|
      image = %(<img src="https://images.example/icon-#{index}.png" alt="Illustration #{index}">)
      image = %(<a href="/story-#{index}">#{image}View story #{index}</a>) if linked
      <<~HTML
        <h2>Topic #{index}</h2>
        <p>#{image} A short explanation of this topic and its practical benefits for members.</p>
      HTML
    end.join

    <<~HTML
      <html><head><title>Community overview</title></head><body><main><article>
        <h1>Community overview</h1>
        #{sections}
      </article></main></body></html>
    HTML
  end

  it 'does not count decorative images as newsletter destinations' do
    with_url_page('https://community.example/overview', illustrated_sections(linked: false)) do |page|
      payload = extract(page)

      expect(payload['contentFormat']).to be_nil
      expect(payload['warnings']).not_to include('multi_topic_page')
      expect(payload['markdown']).to include('Topic 0', 'Topic 5')
    end
  end

  it 'still counts real story destinations that wrap images' do
    with_url_page('https://community.example/overview', illustrated_sections(linked: true)) do |page|
      payload = extract(page)

      expect(payload['contentFormat']).to eq('newsletter')
      expect(payload['warnings']).to include('multi_topic_page')
    end
  end
end
