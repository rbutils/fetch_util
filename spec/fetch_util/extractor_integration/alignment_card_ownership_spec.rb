require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor, 'alignment utility ownership' do
  include_context 'extractor integration helpers'

  it 'keeps independent headlines outside the primary story in alignment-only collections' do
    rich = (1..4).map do |index|
      %(<article><h3><a href="/reports/#{index}">Detailed neighborhood report #{index}</a></h3>) +
        %(<p>Report #{index} describes the local meeting and its decisions.</p></article>)
    end.join
    headlines = (5..10).map do |index|
      %(<a href="/reports/#{index}">Independent community headline number #{index}</a>)
    end.join

    %w[items-center md:items-start justify-items-end place-items-center].each do |alignment|
      html = <<~HTML
        <body><h1>Community news</h1>
          <div class="flex flex-col #{alignment}">
            <h2><a href="/news">Regional news coverage</a></h2>
            #{rich}#{headlines}
          </div>
          <nav class="items-center"><a href="/account">Manage your account settings</a></nav>
        </body>
      HTML
      with_url_page('https://bulletin.example/', html) do |page|
        result = extract_payload(page)
        (1..10).each { |index| expect(result['markdown']).to include("https://bulletin.example/reports/#{index}") }
        expect(result['markdown']).not_to include('https://bulletin.example/account')
      end
    end
  end

  it 'retains named records and their local metadata when they also use alignment utilities' do
    cards = (1..6).map do |index|
      <<~HTML
        <div class="news-card items-center">
          <h2><a href="/reports/#{index}">Neighborhood meeting number #{index}</a></h2>
          <p>Local account number #{index}.</p><span class="author">Reporter #{index}</span>
        </div>
      HTML
    end.join
    with_url_page('https://bulletin.example/', "<main><h1>Community news</h1>#{cards}</main>") do |page|
      result = extract_payload(page)
      (1..6).each do |index|
        line = result['markdown'].lines.find { |value| value.include?("/reports/#{index})") }
        expect(line).to include("Reporter #{index}", "Local account number #{index}")
      end
    end
  end
end
