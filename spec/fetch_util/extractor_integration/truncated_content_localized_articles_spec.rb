# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - truncated_content localized articles' do
  include_context 'extractor integration helpers'

  def localized_article_fixture(title:, body:, lang:)
    links = Array.new(4) do |index|
      <<~HTML
        <li><a href="/related/#{index}">Related regional update #{index}</a></li>
      HTML
    end.join
    chrome = Array.new(60) do |index|
      <<~HTML
        <div class="sidebar-note">Regional market bulletin #{index} with navigation, newsletter, weather, and edition details.</div>
      HTML
    end.join

    <<~HTML
      <!doctype html>
      <html lang="#{lang}">
        <head>
          <title>#{title}</title>
          <meta property="og:title" content="#{title}">
        </head>
        <body>
          <nav>Home Politics Sports Latest News</nav>
          <main>
            <article class="post-description article-main">
              <h1>#{title}</h1>
              #{body.map { |paragraph| "<p>#{paragraph}</p>" }.join("\n")}
            </article>
            <aside class="related-news"><ul>#{links}</ul>#{chrome}</aside>
          </main>
        </body>
      </html>
    HTML
  end

  cases = [
    [
      'Dinakaran',
      'https://www.dinakaran.com/news/straitofhormuz-commercialships-iran-usa/',
      'ஹார்முஸ் நீரிணையில் 3 வர்த்தக கப்பல்கள் தாக்கப்பட்டதைக் கண்டித்து',
      'ta',
      [
        'ஹார்முஸ் நீரிணையில் 3 வர்த்தக கப்பல்கள் தாக்கப்பட்டதைக் கண்டித்து அதிகாரிகள் விரிவான அறிக்கை வெளியிட்டனர்.',
        'கடல் வழித்தடத்தில் பாதுகாப்பு நடவடிக்கைகள் வலுப்படுத்தப்பட்டுள்ளன என்று அதிகாரிகள் தெரிவித்தனர்.',
        'வர்த்தக கப்பல்கள் பாதுகாப்பாகச் செல்ல அனைத்து துறைகளும் ஒருங்கிணைந்து கண்காணிப்பு மேற்கொள்கின்றன.'
      ]
    ],
    [
      'Klix',
      'https://www.klix.ba/sport/nogomet/poznati-su-svi-parovi-cetvrtfinala-svjetskog-prvenstva-evo-kada-se-igraju-utakmice/260707205',
      'U preostalim duelima sastaju se Francuska i Maroko',
      'bs',
      [
        'U preostalim duelima sastaju se Francuska i Maroko nakon što su završeni svi susreti osmine finala.',
        'Raspored utakmica potvrđen je poslije večerašnjeg programa, a navijači sada znaju termine četvrtfinala.',
        'Organizatori očekuju pun stadion i dodatne sigurnosne mjere tokom obje utakmice.'
      ]
    ],
    [
      'APA football',
      'https://apa.az/football/fifa-rusiya-komandalarina-tetbiq-olunan-sanksiyalarin-legvini-muzakire-edecek-979466',
      'Beynəlxalq Futbol Federasiyası (FIFA)',
      'az',
      [
        'Beynəlxalq Futbol Federasiyası (FIFA) məsələ ilə bağlı növbəti iclasda geniş müzakirə aparacaq.',
        'Qərarın qəbul olunması üçün assosiasiyaların rəsmi müraciətləri və turnir təqvimi nəzərə alınacaq.',
        'Müzakirələrdən sonra federasiya yekun mövqeyini ictimaiyyətə açıqlayacaq.'
      ]
    ],
    [
      'APA social',
      'https://apa.az/social/xocavend-ve-susaya-novbeti-koc-karvani-yola-salinib-foto-979468',
      'Prezident İlham Əliyevin tapşırığına uyğun olaraq',
      'az',
      [
        'Prezident İlham Əliyevin tapşırığına uyğun olaraq növbəti köç karvanı bu gün yola salınıb.',
        'Ailələr üçün yeni yaşayış məntəqəsində sosial infrastruktur və zəruri xidmətlər hazırlanıb.',
        'Sakinlər doğma yurdlarına qayıtdıqları üçün sevincli olduqlarını bildiriblər.'
      ]
    ],
    [
      'Sakshi',
      'https://www.sakshi.com/telugu-news/international/us-charges-lawrence-bishnoi-goldy-brar-nijjar-assassination-2837548',
      'లారెన్స్ బిష్ణోయ్',
      'te',
      [
        'లారెన్స్ బిష్ణోయ్ కేసుపై అమెరికా అధికారులు కొత్త ఆరోపణలు నమోదు చేసినట్లు నివేదికలు తెలిపాయి.',
        'దర్యాప్తు సంస్థలు అంతర్జాతీయ సహకారంతో వివరాలు సేకరిస్తున్నాయని అధికార వర్గాలు పేర్కొన్నాయి.',
        'ఈ కేసులో మరిన్ని వివరాలు త్వరలో వెల్లడయ్యే అవకాశం ఉందని అధికారులు చెప్పారు.'
      ]
    ]
  ]

  cases.each do |name, url, expected_snippet, lang, paragraphs|
    it "does not flag truncated_content for #{name}" do
      html = localized_article_fixture(title: "#{name} article", body: paragraphs, lang: lang)

      extract_from_url(url, html) do |payload|
        expect_content_type(payload, 'article')
        expect(payload['warnings']).not_to include('truncated_content')
        expect(payload['markdown']).to include(expected_snippet)
      end
    end
  end
end
