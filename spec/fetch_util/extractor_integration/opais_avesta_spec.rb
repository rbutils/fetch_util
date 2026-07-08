# frozen_string_literal: true

RSpec.describe 'FetchUtil O Pais and Avesta extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts the O Pais article body without the next-story bleedthrough' do
    expect_fixture_article(
      url: 'https://opais.co.mz/dia-dos-herois-nyusi-convida-mocambicanos-a-reflectirem-sobre-a-necessidade-da-paz',
      fixture_path: File.expand_path('../fixtures/opais_article.html', __dir__),
      includes: [
        'Passam hoje 51 anos do assassinato de Eduardo Chivambo Mondlane',
        'Pela efeméride, o Presidente da República convida os moçambicanos',
        'Estamos em diálogo, mas aqueles que matam os moçambicanos'
      ],
      excludes: ['Registado mais um óbito e 111 recuperados da COVID-19'],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts the Avesta article body instead of the front-page listing card' do
    expect_fixture_article(
      url: 'https://avesta.tj/2025/05/12/avesta-tj-zapuskaet-angloyazychnuyu-versiyu-sajta-s-podderzhkoj-ii-novosti-budushhego-uzhe-segodnya/',
      fixture_path: File.expand_path('../fixtures/avesta_article.html', __dir__),
      includes: [
        'Информационное агентство Avesta.tj сегодня, 12 мая 2025 года',
        'Теперь пользователи Avesta.tj смогут получать новости режиме реального времени',
        'Редакция Avesta.tj осознаёт потенциал и риски'
      ],
      excludes: ['Таджикистан планирует построить новые международные линии связи'],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial]
    )
  end
end
