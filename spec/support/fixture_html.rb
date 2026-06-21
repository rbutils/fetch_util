# frozen_string_literal: true

RSpec.shared_context 'fixture html helpers' do
  def simple_html_document(title:, body:, lang: nil, head: nil)
    language = lang ? %( lang="#{lang}") : ''

    <<~HTML
      <html#{language}>
        <head>
          <title>#{title}</title>
          #{head}
        </head>
        <body>
          #{body}
        </body>
      </html>
    HTML
  end

  def simple_consent_wall_html(title:, heading:, paragraphs:, buttons: [], head: nil)
    body = <<~HTML
      <main>
        <h1>#{heading}</h1>
        #{paragraphs.map { |paragraph| "<p>#{paragraph}</p>" }.join("\n        ")}
        #{buttons.map { |button| "<button>#{button}</button>" }.join("\n        ")}
      </main>
    HTML

    simple_html_document(title: title, body: body, head: head)
  end
end
