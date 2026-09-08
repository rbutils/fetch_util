# frozen_string_literal: true

RSpec.describe 'Generic list route admission' do
  include_context 'extractor integration helpers'

  def admitted_route_urls(entries)
    root = File.expand_path('../../..', __dir__)
    manifest = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
    source = manifest.reject { |path| path.empty? || path.start_with?('#') }.map do |path|
      content = File.read(File.join(root, 'websieve', path))
      next content unless path == '99_outro.js'

      <<~JS + content
        global.__listRouteCandidates = function(entries) {
          return entries.map(function(entry) {
            var card = document.createElement("article");
            var link = document.createElement("a");
            link.setAttribute("href", entry.url);
            link.textContent = "Regional information bulletin";
            card.appendChild(link);
            if (entry.detail) {
              var paragraph = document.createElement("p");
              paragraph.textContent = entry.detail;
              card.appendChild(paragraph);
            }
            document.querySelector("main").appendChild(card);
            var candidate = listLinkCandidate(link, card, listPageContext());
            return candidate ? candidate.url : null;
          });
        };
      JS
    end.join("\n")
    html = '<html><head><title>Regional bulletins</title></head><body><main></main></body></html>'
    with_url_page('https://publisher.example/archive', html) do |page|
      page.add_script_tag(content: source)
      return JSON.parse(page.evaluate("JSON.stringify(window.__listRouteCandidates(#{JSON.generate(entries)}))"))
    end
  end

  it 'does not confuse hostnames or query values with account and privacy routes' do
    hosts = %w[subscribe subscription abonnement login register newsletter account instellingen settings privacy cookies consent]
    urls = hosts.map { |host| "https://#{host}.example/news/bulletin" }
    urls << 'https://publisher.example/news/bulletin?next=/subscribe&ref=/privacy/settings'

    expect(admitted_route_urls(urls.map { |url| { url: url } })).to eq(urls)
  end

  it 'continues rejecting actual account routes and unsafe or credential-bearing URLs' do
    routes = %w[subscribe subscription abonnement login register newsletter account instellingen settings privacy cookies consent]
    urls = routes.map { |route| "https://publisher.example/#{route}/preferences" }
    urls += ['javascript:openRecord()', 'ftp://publisher.example/news/bulletin',
             'https://example-user:example-secret@publisher.example/news/bulletin']

    expect(admitted_route_urls(urls.map { |url| { url: url } })).to eq(Array.new(urls.length))
  end

  it 'compares the target origin as well as the path when excluding self-links' do
    urls = [
      'https://other.example/archive',
      'https://publisher.example/archive',
      'https://publisher.example/archive?page=2',
      'http://publisher.example/archive',
      'https://publisher.example:8443/archive'
    ]

    expect(admitted_route_urls(urls.map { |url| { url: url } })).to eq([urls[0], nil, nil, urls[3], urls[4]])
  end

  it 'applies weather and programme route exclusions only to their paths' do
    weather_detail = 'Weather forecast temperature wind rain snow and storm information.'
    programme_detail = 'Vsak dan ob 12.30, nova epizoda oddaja.'
    entries = [
      { url: 'https://weather.example/news/bulletin', detail: weather_detail },
      { url: 'https://publisher.example/news/bulletin?ref=/weather/today', detail: weather_detail },
      { url: 'https://publisher.example/weather/today', detail: weather_detail },
      { url: 'https://publisher.example/news/bulletin?ref=/tv/schedule', detail: programme_detail },
      { url: 'https://publisher.example/tv/schedule', detail: programme_detail }
    ]

    expect(admitted_route_urls(entries)).to eq([entries[0][:url], entries[1][:url], nil, entries[3][:url], nil])
  end
end
