# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Osnova articles' do
  include_context 'extractor integration helpers'

  it "extracts the primary Osnova article body without recommendation feed posts" do
    html = <<~HTML
      <html lang="ru">
        <head>
          <title>Российский книжный союз раскритиковал законопроект об ИИ — AI на vc.ru</title>
          <meta property="og:site_name" content="vc.ru">
          <meta name="description" content="Первое чтение документа запланировано в Госдуме.">
        </head>
        <body>
          <div class="layout-wrapper">
            <div class="layout">
              <div class="view">
                <div class="entry">
                  <div class="content">
                    <div class="content__body">
                      <h1 class="content-title content-title--low-indent">Российский книжный союз раскритиковал законопроект об ИИ</h1>
                      <article class="content__blocks">
                        <figure><p>Первое чтение документа запланировано в Госдуме на 7 июля 2026 года, пишут СМИ.</p></figure>
                        <figure>
                          <ul>
                            <li>Российский книжный союз, Национальная федерация музыкальной индустрии и другие правообладатели раскритиковали законопроект о развитии ИИ.</li>
                            <li>В текущем виде законопроект не считает нарушением авторских прав обучение ИИ на общедоступных произведениях.</li>
                            <li>По мнению авторов обращений, это позволяет использовать без согласия правообладателей фактически любой доступный в интернете контент.</li>
                            <li>Профильные ассоциации просят привлечь правообладателей к обсуждению регулирования нейросетей.</li>
                          </ul>
                        </figure>
                        <figure class="block-wrapper block-wrapper--media">
                          <div class="block-wrapper__content">
                            <div class="block-osnova-embed"><div class="andropov-osnova-embed">
                              <div class="content content--short content--without-footer content--embed"><div class="content__body">СМИ: правительство переработало законопроект об ИИ</div></div>
                            </div></div>
                          </div>
                        </figure>
                      </article>
                    </div>
                  </div>
                </div>
                <div class="entry">
                  <div class="recommendations">
                    <div class="content-list">
                      <div class="content content--short"><div class="content__body"><h2>Привычка, которую все стесняются: почему разговор вслух с самим собой прокачивает мозг</h2><time datetime="2026-07-07T08:00:00+03:00">08:00</time></div></div>
                      <div class="content content--short"><div class="content__body"><h2>Как основатели стартапа искали первые инвестиции</h2><time datetime="2026-07-07T09:15:00+03:00">09:15</time></div></div>
                      <div class="content content--short"><div class="content__body"><h2>Почему разработчики спорят о новых правилах платформ</h2><time datetime="2026-07-07T10:30:00+03:00">10:30</time></div></div>
                      <div class="content content--short"><div class="content__body"><h2>Кейс недели: как команда автоматизировала поддержку</h2><time datetime="2026-07-07T11:45:00+03:00">11:45</time></div></div>
                      <div class="content content--short"><div class="content__body"><h2>Инвесторы рассказали о спросе на ИИ-сервисы</h2><time datetime="2026-07-07T12:10:00+03:00">12:10</time></div></div>
                      <div class="rotator rotator--limitless"><div class="content content--short"><div class="content__body"><h2>Я уехал в США с $3000 в кармане, через 3,5 года вернулся в Россию</h2><time datetime="2026-07-07T13:25:00+03:00">13:25</time></div></div></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://vc.ru/ai/3014512-rossijskij-knizhnyj-soyuz-kritikuet-zakonoproekt-ob-ii", html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("Российский книжный союз раскритиковал законопроект об ИИ")
      expect(payload["markdown"]).to include("Профильные ассоциации просят привлечь правообладателей")
      expect(payload["markdown"]).not_to include("Привычка, которую все стесняются")
      expect(payload["markdown"]).not_to include("Я уехал в США")
      expect(payload["markdown"]).not_to include("СМИ: правительство переработало")
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial multi_topic_page])
    end
  end
end
