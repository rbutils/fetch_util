# frozen_string_literal: true

RSpec.describe 'Readability excerpts selected from owned article prose' do
  include_context 'extractor integration helpers'

  let(:fixture_html) do
    fixture_contents(File.expand_path('../../fixtures/skynewsarabia_article.html', __dir__))
  end

  let(:source_summary) do
    'قال الرئيس السوري، أحمد الشرع، الثلاثاء، إن الشراكة الاستراتيجية التي تؤسس لها سوريا ' \
      'مع فرنسا نموذج نريده للعلاقة مع أوروبا والعالم، شراكة تبنى على المصالح تخدم شعبينا لا على الشعارات.'
  end

  it 'replaces a proved source byline excerpt with its owned summary on an unknown host' do
    source_byline = 'سكاي نيوز عربية - أبوظبي'
    source_description = 'الرئيس السوري أحمد الشرع يقول إن الشراكة الاستراتيجية مع فرنسا تقوم على المصالح المتبادلة.'
    source_body = 'وأضاف الشرع، خلال اجتماعه بالرئيس الفرنسي إيمانويل ماكرون بقصر الشعب بدمشق:'

    with_url_page('https://unknown-publisher.example/story', fixture_html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['excerpt']).to eq(source_summary)
      expect(payload['description']).to eq(source_description)
      expect(payload['byline']).to eq(source_byline)
      expect(payload['title']).to eq('الشرع: نؤسس لشراكة تقوم على المصالح المتبادلة مع فرنسا')
      expect(payload['html']).to include(source_summary, source_byline, source_body)
      expect(payload['markdown']).to include(source_summary, source_byline, source_body)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'preserves narrative subtitle text and selects a short owned lead in full' do
    narrative = fixture_html.sub('سكاي نيوز عربية - أبوظبي', 'سكاي نيوز عربية - “قالت الحكومة إن الاتفاق تأجل”')
    summary_removed = fixture_html.sub(%r{<p class="article-summary"[^>]*>.*?</p>}m, '')
    short_lead = summary_removed.sub(
      %r{<p[^>]*>وأضاف الشرع، خلال اجتماعه.*?</p>}m,
      '<p>تحدث الشرع في دمشق.</p>'
    )
    existing_short_excerpt = fixture_html.sub(source_summary, 'تحدث الشرع في دمشق.')

    with_url_page('https://narrative-publisher.example/story', narrative) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page)
      expect(payload['excerpt']).to eq(source_summary)
      expect(payload['byline']).to eq('سكاي نيوز عربية - “قالت الحكومة إن الاتفاق تأجل”')
      expect(payload['html']).to include(source_summary, payload['byline'])
      expect(payload['markdown']).to include(source_summary, payload['byline'])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end

    with_url_page('https://short-lead.example/story', short_lead) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).to eq('تحدث الشرع في دمشق.')
      expect(payload['markdown']).to include('تحدث الشرع في دمشق.')
      expect(payload['byline']).to eq('سكاي نيوز عربية - أبوظبي')
    end

    with_url_page('https://existing-excerpt.example/story', existing_short_excerpt) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).to eq('تحدث الشرع في دمشق.')
    end
  end

  it 'retains complete owned summary and first-body paragraphs beyond a presentation-length boundary' do
    details = 'وتتضمن الشراكة مشروعات اقتصادية وتعليمية وتفاصيل التعاون بين المؤسسات العامة. ' \
              'وتشمل الاتفاقيات تبادل الخبرات المهنية وتطوير شبكات النقل ومراجعة القوانين التجارية. ' \
              'وستتولى فرق مشتركة متابعة المراحل التنفيذية ونشر تقارير دورية عن نتائج المشروعات.'
    long_lead = "#{source_summary} #{details}"
    expect(long_lead.length).to be > 280
    long_summary = fixture_html.sub(source_summary, long_lead)
    long_body = fixture_html.sub(%r{<p class="article-summary"[^>]*>.*?</p>}m, '').sub(
      %r{<p[^>]*>وأضاف الشرع، خلال اجتماعه.*?</p>}m, "<p>#{long_lead}</p>"
    )

    [long_summary, long_body].each_with_index do |source, index|
      with_url_page("https://complete-lead.example/story-#{index}", source) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract_payload(page)

        expect(payload['excerpt']).to eq(long_lead.strip)
        expect(payload['byline']).to eq('سكاي نيوز عربية - أبوظبي')
        expect(payload['markdown']).to include(long_lead.strip)
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
      end
    end
  end

  it 'does not borrow foreign or missing prose, or override conflicting author metadata' do
    byline = 'سكاي نيوز عربية - أبوظبي'
    description = 'الرئيس السوري أحمد الشرع يقول إن الشراكة الاستراتيجية مع فرنسا تقوم على المصالح المتبادلة.'
    missing_prose = fixture_html.sub(%r{<p class="article-summary"[^>]*>.*?</p>}m, '')
    missing_prose = missing_prose.sub(%r{<section class="article-content"[^>]*>.*?</section>}m, '')
    foreign_body = fixture_html.sub(%r{<p class="article-summary"[^>]*>.*?</p>}m, '')
    foreign_body = foreign_body.sub('<section class="article-content"', '<aside><section class="article-content"')
    foreign_body = foreign_body.sub('</section>', '</section></aside>')
    conflicting_author = fixture_html.sub('"name": "سكاي نيوز عربية"', '"name": "مراسل آخر"')

    with_url_page('https://missing-prose.example/story', missing_prose) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).not_to eq(description)
      expect(payload['markdown']).not_to include(description)
    end

    with_url_page('https://foreign-body.example/story', foreign_body) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).not_to eq(source_summary)
      expect(payload['markdown']).not_to include(description)
    end

    with_url_page('https://conflicting-author.example/story', conflicting_author) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page)
      expect(payload['excerpt']).to eq(source_summary)
      expect(payload['description']).to eq(description)
      expect(payload['byline']).to eq('مراسل آخر')
      expect(payload['html']).to include(source_summary, byline)
      expect(payload['markdown']).to include(source_summary, byline)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'rejects a matching declared summary moved into a foreign component beside the owned article' do
    source = fixture_html.sub(%r{<p class="article-summary"[^>]*>.*?</p>}m, '')
    declared = source.sub(
      /<meta name="description" content="[^"]*">/,
      %(<meta name="description" content="#{source_summary}">)
    )
    body = 'وأضاف الشرع، خلال اجتماعه بالرئيس الفرنسي إيمانويل ماكرون بقصر الشعب بدمشق:'
    variants = {
      aside: "<aside><p class=\"article-summary\">#{source_summary}</p></aside>",
      form: "<form><p class=\"article-summary\">#{source_summary}</p></form>",
      other_article: "<article><h2>Other story</h2><p class=\"article-summary\">#{source_summary}</p></article>",
      other_article_plain: "<article><h2>Other story</h2><p>#{source_summary}</p></article>",
      independent_section: "<section><h2>Other story</h2><p>#{source_summary}</p></section>",
      independent_section_after: "<section><h2>Other story</h2><p>#{source_summary}</p></section>",
      nested_other_article: "<article><h2>Other story</h2><p class=\"article-summary\">#{source_summary}</p></article>"
    }

    variants.each do |kind, component|
      [false, true].each do |branded|
        html = if kind == :independent_section_after
                 declared.sub("    </section>\n  </main>", "    </section>\n#{component}  </main>")
               else
                 declared.sub('<section class="article-content"', "#{component}<section class=\"article-content\"")
               end
        if kind == :nested_other_article
          html = html.sub('<main class="article_detail_page">', '<main class="article_detail_page"><article>')
                     .sub('</main>', '</article></main>')
        end
        html = branded_article_title(html) if branded
        with_url_page("https://foreign-summary.example/#{kind}-#{branded}", html) do |page|
          before = page.evaluate('document.body.outerHTML')
          payload = extract_payload(page)
          expect(payload['contentType']).to eq('article')
          expect(payload['excerpt']).not_to eq(source_summary), "foreign #{kind}, branded=#{branded}"
          expect(payload['markdown']).to include(body)
          expect(page.evaluate('document.body.outerHTML')).to eq(before)
        end
      end
    end
  end

  it 'keeps the actual visible summary when another article has its own different summary' do
    foreign = '<article><h2>Other story</h2><p class="article-summary">A separate story reviews another public agreement.</p></article>'
    source = fixture_html.sub('<section class="article-content"', "#{foreign}<section class=\"article-content\"")

    [false, true].each do |branded|
      [false, true].each do |sectioned_summary|
        html = branded ? branded_article_title(source) : source
        if sectioned_summary
          html = html.sub(%r{(<p class="article-summary"[^>]*>.*?</p>)}m, '<section>\1</section>')
        end
        with_url_page("https://nearby-summary.example/story-#{branded}-#{sectioned_summary}", html) do |page|
          before = page.evaluate('document.body.outerHTML')
          payload = extract_payload(page)
          expect(payload['contentType']).to eq('article')
          expect(payload['excerpt']).to eq(source_summary)
          expect(payload['markdown']).to include(source_summary, 'وأضاف الشرع، خلال اجتماعه بالرئيس الفرنسي')
          expect(page.evaluate('document.body.outerHTML')).to eq(before)
        end
      end
    end
  end

  def branded_article_title(html)
    title = 'الشرع: نؤسس لشراكة تقوم على المصالح المتبادلة مع فرنسا'
    html.sub("<title>#{title}</title>", "<title>#{title} | Publisher</title>")
        .sub('</head>', '<meta property="og:site_name" content="Publisher"></head>')
  end
end
