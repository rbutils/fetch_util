# frozen_string_literal: true

RSpec.describe 'FetchUtil generic article extraction' do
  include_context 'extractor integration helpers'

  it 'extracts a DW Spanish article without chrome' do
    expect_fixture_article(
      url: 'https://www.dw.com/es/trump-expresa-decepci%C3%B3n-con-la-otan-por-no-secundar-su-ofensiva-en-ir%C3%A1n/a-77867531',
      fixture_path: File.expand_path('../fixtures/dw_trump.html', __dir__),
      includes: ['Donald Trump', 'OTAN', 'Irán'],
      excludes: ['Ir al contenido', 'Ir al menú principal'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts another DW Spanish article without navigation noise' do
    expect_fixture_article(
      url: 'https://www.dw.com/es/le-pen-anuncia-candidatura-a-presidencia-de-francia-a-pesar-de-condena/a-77869086',
      fixture_path: File.expand_path('../fixtures/dw_lepen.html', __dir__),
      includes: ['confirmó este martes', 'liderará a una extrema derecha', 'Tribunal de Apelación de París'],
      excludes: ['Ir al contenido', 'Ir al menú principal'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts the DW Mbappe article without related-module clutter' do
    expect_fixture_article(
      url: 'https://www.dw.com/es/onu-apoya-a-mbapp%C3%A9-y-rechaza-declaraciones-despreciables-de-senadora-de-paraguay/a-77867955',
      fixture_path: File.expand_path('../fixtures/dw_mbappe.html', __dir__),
      includes: %w[Mbappé ONU Paraguay],
      excludes: ['Ir al contenido', 'Ir al menú principal'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts the DW Marine Le Pen article cleanly' do
    expect_fixture_article(
      url: 'https://www.dw.com/es/marine-le-pen-es-condenada-a-quince-meses-de-inhabilitaci%C3%B3n/a-77865586',
      fixture_path: File.expand_path('../fixtures/dw_marine.html', __dir__),
      includes: ['Marine Le Pen', 'inhabilitación', 'París'],
      excludes: ['Ir al contenido', 'Ir al menú principal'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts the DW Ukraine article cleanly' do
    expect_fixture_article(
      url: 'https://www.dw.com/es/ucrania-reivindica-ataques-contra-ocho-buques-de-la-flota-fantasma-rusa/a-77863822',
      fixture_path: File.expand_path('../fixtures/dw_ukraine.html', __dir__),
      includes: ['ocho buques petroleros', 'atacaron durante la madrugada', '58 objetivos militares legítimos'],
      excludes: ['Ir al contenido', 'Ir al menú principal'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts a no-profile Hindustan Times opinion article' do
    expect_fixture_article(
      url: 'https://www.hindustantimes.com/opinion/hindi-and-its-role-in-the-unified-future-of-india-101726241382225.html',
      fixture_path: File.expand_path('../fixtures/ht_hindi.html', __dir__),
      includes: ['Hindi Divas', 'official language of the Union', 'Hindi has 55 distinct varieties'],
      excludes: ['Skip to content', 'Subscribe'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial multi_topic_page stale_content]
    )
  end
end
