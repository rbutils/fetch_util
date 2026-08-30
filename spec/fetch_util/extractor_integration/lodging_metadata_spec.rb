# frozen_string_literal: true

RSpec.describe "lodging metadata extraction" do
  include_context "extractor integration helpers"

  it "keeps lodging extraction visibility-pruned without truncating visible amenities" do
    html = <<~HTML
      <!doctype html>
      <html>
        <head><title>LODGE:Property</title></head>
        <body>
          <main>
            <h1>LODGE:Property</h1>
            <div itemprop="address">LODGE:Visible Address</div>
            <div data-testid="property-description">
              LODGE:Visible description text provides enough detail for the lodging page output.
              <span style="display:none">LODGE:Hidden display description</span>
              <span style="visibility:hidden">
                LODGE:Hidden visibility description
                <span style="visibility:visible">LODGE:Restored description detail</span>
              </span>
            </div>
            <section data-testid="amenity-list">
              <ul>
                <li>LODGE:Visible Amenity A</li>
                <li style="display:none">LODGE:Hidden Amenity B</li>
                <li style="visibility:hidden">
                  LODGE:Hidden Amenity C
                  <span style="visibility:visible">LODGE:Restored Amenity D</span>
                </li>
                <li>LODGE:Visible Amenity E</li>
                <li>LODGE:Visible Amenity F</li>
              </ul>
            </section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://example.test/hotel/visible-lodge", html) do |result|
      expect(result["contentType"]).to eq("hotel")
      expect(result["markdown"]).to include(
        "LODGE:Visible description text",
        "LODGE:Restored description detail",
        "LODGE:Visible Amenity A",
        "LODGE:Restored Amenity D",
        "LODGE:Visible Amenity E",
        "LODGE:Visible Amenity F"
      )
      expect(result["markdown"]).not_to include(
        "LODGE:Hidden display description",
        "LODGE:Hidden visibility description",
        "LODGE:Hidden Amenity B",
        "LODGE:Hidden Amenity C"
      )
      expect(result["markdown"].scan(/^- LODGE:/).length).to eq(4)
      expect(result["markdown"].index("LODGE:Visible Amenity A")).to be < result["markdown"].index("LODGE:Restored Amenity D")
      expect(result["markdown"].index("LODGE:Restored Amenity D")).to be < result["markdown"].index("LODGE:Visible Amenity E")
      expect(result["markdown"].index("LODGE:Visible Amenity E")).to be < result["markdown"].index("LODGE:Visible Amenity F")
    end
  end
end
