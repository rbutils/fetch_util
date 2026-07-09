# frozen_string_literal: true

RSpec.describe 'FetchUtil health and medical extraction' do
  include_context 'extractor integration helpers'

  it 'treats CDC MedicalWebPage schema as a medical article instead of a topic list' do
    expect_fixture_article(
      url: 'https://www.cdc.gov/diabetes/about/',
      fixture_path: File.expand_path('../../fixtures/cdc_medical_webpage.html', __dir__),
      content_type: 'medical',
      includes: ['Diabetes is a chronic health condition', 'Insulin helps blood sugar enter the cells', 'Talk with your doctor'],
      excludes: ['Featured', 'For Professionals', 'Health Topics'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch multi_topic_page]
    )
  end

  it 'keeps a Mayo Clinic disease article as article body content instead of nav cards' do
    expect_fixture_article(
      url: 'https://www.mayoclinic.org/diseases-conditions/depression/symptoms-causes/syc-20356007',
      fixture_path: File.expand_path('../../fixtures/mayo_depression_article.html', __dir__),
      includes: ['Depression is a mood disorder', 'Feelings of sadness', 'When to see a doctor'],
      excludes: ['Appointments', 'Diseases & Conditions', 'Featured topics'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch multi_topic_page]
    )
  end

  it 'does not convert a WebMD article-shaped page with incidental 404 chrome into not found' do
    expect_fixture_article(
      url: 'https://www.webmd.com/depression/guide/what-is-depression',
      fixture_path: File.expand_path('../../fixtures/webmd_depression_article.html', __dir__),
      includes: ['A field note on steady-day energy changes', 'Clinical depression is more than grief', 'treatment can help'],
      excludes: ['The page you requested cannot be found', 'Health A-Z'],
      warning_excludes: %w[not_found_interstitial empty_extraction short_extraction url_content_mismatch]
    )
  end
end
