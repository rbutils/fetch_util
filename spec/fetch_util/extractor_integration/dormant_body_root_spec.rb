# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - dormant body roots" do
  include_context "extractor integration helpers"

  def dormant_body_records
    (1..8).map do |index|
      <<~HTML
        <article class="forecast-card">
          <h2><a href="/forecast/#{index}">Regional forecast #{index}</a></h2>
          <p>
            Detailed regional outlook #{index} covers daytime and overnight conditions, expected temperatures,
            travel considerations, precipitation changes, and the weather pattern for the coming week.
          </p>
        </article>
      HTML
    end.join
  end

  def dormant_body_html(class_name: "template-root", extra: "", tag_name: "div", root_id: nil,
                        records: dormant_body_records)
    <<~HTML
      <html><head><title>Regional weather outlooks</title></head><body>
        <#{tag_name}#{%( id="#{root_id}") if root_id} class="#{class_name}" style="display: none">
          <h1>Regional weather outlooks</h1>
          <p>Choose a detailed outlook for every region in the national forecast collection.</p>
          #{records}
          #{extra}
        </#{tag_name}>
        <noscript></noscript>
        <iframe title="telemetry"></iframe>
      </body></html>
    HTML
  end

  it "recovers a dominant dormant document root" do
    with_url_page("https://weather.example/", dormant_body_html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      links = payload.fetch("markdown").scan(%r{/forecast/(\d+)})

      expect(payload["contentType"]).to eq("list")
      expect(links.flatten.map(&:to_i)).to eq((1..8).to_a)
      expect(payload.fetch("markdown")).to include("Detailed regional outlook 1", "Detailed regional outlook 8")
      expect(payload.fetch("warnings")).not_to include("empty_extraction", "short_extraction")
      expect(payload).not_to have_key("listExtraction")
    end
  end

  it "rejects a dormant root made mostly from independently hidden branches" do
    hidden_branches = (1..12).map do |index|
      %(<div style="display: none"><span>Unselected application draft #{index}</span></div>)
    end.join

    with_url_page("https://weather.example/", dormant_body_html(extra: hidden_branches)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).not_to include("Regional forecast", "/forecast/")
      expect(payload.fetch("warnings")).to include("empty_extraction")
    end
  end

  {
    "aria-hidden" => 'aria-hidden="true"',
    "inert" => "inert",
    "visibility-hidden" => 'style="visibility: hidden"',
    "visibility-collapsed" => 'style="visibility: collapse"'
  }.each do |label, attribute|
    it "rejects records owned by a nested #{label} branch" do
      records = %(<div #{attribute}>#{dormant_body_records}</div>)

      with_url_page("https://weather.example/", dormant_body_html(records: records)) do |page|
        payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

        expect(payload.fetch("markdown")).not_to include("Regional forecast", "/forecast/")
        expect(payload.fetch("warnings")).to include("empty_extraction")
      end
    end
  end

  it "rejects dormant application and chrome roots" do
    with_url_page("https://weather.example/", dormant_body_html(class_name: "application-shell")) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).not_to include("Regional forecast", "/forecast/")
    end
  end

  {
    "root id" => { root_id: "root" },
    "app id" => { root_id: "app" },
    "Next.js root id" => { root_id: "__next" },
    "React root class" => { class_name: "react-root" }
  }.each do |label, options|
    it "rejects a dormant #{label}" do
      with_url_page("https://weather.example/", dormant_body_html(**options)) do |page|
        payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

        expect(payload.fetch("markdown")).not_to include("Regional forecast", "/forecast/")
      end
    end
  end

  it "rejects dormant custom-element application roots" do
    with_url_page("https://weather.example/", dormant_body_html(tag_name: "weather-app")) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).not_to include("Regional forecast", "/forecast/")
      expect(payload.fetch("warnings")).to include("empty_extraction")
    end
  end

  it "does not replace short visible focal content" do
    visible_copy = "This concise visible report explains today's weather conditions and timing."
    html = dormant_body_html.sub("<body>", <<~HTML.chomp)
      <body>
        <main>
          <h1>Current weather</h1>
          <p>#{visible_copy}</p>
        </main>
    HTML

    with_url_page("https://weather.example/analysis/current", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: true).extract(page)

      expect(payload.fetch("markdown")).not_to include("Regional forecast", "/forecast/")
    end
  end
end
