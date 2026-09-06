# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - warning content size" do
  include_context "extractor integration helpers"

  def warning_content_size_html(text)
    destination = "https://requests.example/continue?state=#{"request-state-" * 60}"
    <<~HTML
      <html><head><title>Request information</title></head><body>
        <div><p>#{text}</p>
          <p>Check the current request details before you continue. The information below belongs to this browser session
          and explains what happens next. <a href="#{destination}">Continue to the requested page</a>.</p>
        </div>
      </body></html>
    HTML
  end

  it "does not let long Markdown link destinations hide a short access check" do
    html = warning_content_size_html(
      "Our systems have detected unusual traffic from your computer network. " \
      "This page checks to see if it is really you sending the requests, and not a robot."
    )
    with_url_page("https://checkpoint.example/request", html) do |page|
      payload = extract(page)

      expect(payload["markdown"].length).to be > 500
      expect(payload["textContent"].length).to be < 500
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
      expect(payload["suspect"]).to be(true)
    end
  end

  it "does not flag ordinary short information with long links as an access check" do
    html = warning_content_size_html(
      "Your requested record is available in the public archive. " \
      "The link below includes the record identifier so that the archive can display the correct revision."
    )
    with_url_page("https://records.example/request", html) do |page|
      payload = extract(page)

      expect(payload["markdown"].length).to be > 500
      expect(payload["textContent"].length).to be < 500
      expect(payload["warnings"]).not_to include("bot_or_access_interstitial")
    end
  end

  it "keeps substantial public prose that discusses unusual traffic" do
    text = "Network administrators study unusual traffic to understand changing usage patterns. " \
           "Their analysis separates routine client retries from deliberate bursts of requests. "
    with_url_page("https://network.example/request", warning_content_size_html(text * 5)) do |page|
      payload = extract(page)

      expect(payload["textContent"].length).to be > 500
      expect(payload["warnings"]).not_to include("bot_or_access_interstitial")
    end
  end
end
