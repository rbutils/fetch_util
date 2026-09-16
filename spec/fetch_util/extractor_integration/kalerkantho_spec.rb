# frozen_string_literal: true

RSpec.describe 'FetchUtil Kaler Kantho extractor integration' do
  include_context 'extractor integration helpers'

  let(:article_url) { 'https://www.kalerkantho.com/online/national/2026/07/07/1708171' }
  let(:article_html) { fixture_contents(File.expand_path('../../fixtures/kalerkantho_article.html', __dir__)) }
  let(:article_paragraphs) do
    [
      'প্রধানমন্ত্রী তারেক রহমানের সফরের পর বাংলাদেশি শ্রমিকদের জন্য আবারও খুলে দেওয়া হয়েছে মালয়েশিয়ার ' \
      'শ্রমবাজার। গতকাল সোমবার থেকে মালয়েশিয়ার শ্রমবাজার উন্মুক্ত হয়েছে বলে জানিয়েছেন প্রবাসীকল্যাণ মন্ত্রী আরিফুল হক চৌধুরী।',
      'মঙ্গলবার দুপুরে সিলেট সার্কিট হাউসে এ কথা জানান তিনি। আগামী এক থেকে দুই মাসের মধ্যে বিনা খরচে কর্মী পাঠানো শুরু হবে বলে আশা করছে সরকার।',
      'প্রবাসীকল্যাণ মন্ত্রী বলেন, খুব দ্রুত মধ্যপ্রাচ্য, জাপান, মরিশাসের শ্রমবাজার নিয়ে সুখবর আসবে।',
      'তবে এবার মালয়েশিয়া নয়, বাংলাদেশই রিক্রুটিং এজেন্সি নির্বাচন করবে।',
      'সিন্ডিকেট ও দুর্নীতি এড়াতে সরকার ও এজেন্সিগুলোর সমন্বিত উদ্যোগ'
    ]
  end
  let(:article_chrome) do
    [
      'ই-পেপার সাবস্ক্রিপশন',
      'জুলাইয়ের মধ্যে স্থানীয় নির্বাচনের বিধিমালা',
      'related story body should not leak'
    ]
  end

  def extract_with_dom_observation(page, reader_mode:)
    extractor_for(reader_mode).__send__(:inject_assets, page)
    before = page.evaluate('document.documentElement.outerHTML')
    extraction = page.evaluate_async(<<~JS, 5)
      const done = arguments[arguments.length - 1];
      const mutations = [];
      const recordMutations = function(records) {
        records.forEach(function(record) {
          mutations.push({
            type: record.type,
            target: record.target.nodeName,
            attribute: record.attributeName || null
          });
        });
      };
      const observer = new MutationObserver(recordMutations);
      observer.observe(document.documentElement, {
        subtree: true,
        childList: true,
        attributes: true,
        characterData: true
      });
      const payload = window.FetchUtilExtract.extract({reader_mode: #{reader_mode}});
      setTimeout(function() {
        recordMutations(observer.takeRecords());
        setTimeout(function() {
          recordMutations(observer.takeRecords());
          observer.disconnect();
          done({payload, mutations});
        }, 0);
      }, 0);
    JS
    after = page.evaluate('document.documentElement.outerHTML')

    [extraction['payload'], extraction['mutations'], before, after]
  end

  it 'extracts Kaler Kantho articles through shared article ownership' do
    with_url_page(article_url, article_html) do |page|
      payload, mutations, before, after = extract_with_dom_observation(page, reader_mode: false)

      expect(payload).to include(
        'title' => 'প্রধানমন্ত্রীর সফরের পর খুলল মালয়েশিয়ার শ্রমবাজার',
        'contentType' => 'article',
        'contentFormat' => nil,
        'hostAware' => false,
        'readerMode' => false,
        'suspect' => false,
        'warnings' => []
      )
      article_paragraphs.each { |paragraph| expect(payload['markdown']).to include(paragraph) }
      %w[html markdown textContent].each do |field|
        article_chrome.each { |text| expect(payload[field]).not_to include(text) }
      end
      expect(payload['docsLike']).not_to eq(true)
      expect(after).to eq(before)
      expect(mutations).to eq([])
    end
  end

  it 'preserves shared Kaler Kantho article ownership in reader mode' do
    with_url_page(article_url, article_html) do |page|
      payload, mutations, before, after = extract_with_dom_observation(page, reader_mode: true)

      expect(payload).to include(
        'title' => 'প্রধানমন্ত্রীর সফরের পর খুলল মালয়েশিয়ার শ্রমবাজার',
        'contentType' => 'article',
        'hostAware' => false,
        'readerMode' => true,
        'suspect' => false,
        'warnings' => []
      )
      article_paragraphs.each { |paragraph| expect(payload['markdown']).to include(paragraph) }
      %w[html markdown textContent].each do |field|
        article_chrome.each { |text| expect(payload[field]).not_to include(text) }
      end
      expect(after).to eq(before)
      expect(mutations).to eq([])
    end
  end

  it 'leaves Kaler Kantho homepages on shared extraction' do
    cards = Array.new(8) do |index|
      <<~HTML
        <article>
          <h2><a href="/online/national/2026/07/#{index + 10}/story-#{index}">সংবাদ শিরোনাম #{index + 1}</a></h2>
          <p>এই প্রতিবেদনের নিজস্ব সংক্ষিপ্ত বিবরণ #{index + 1}।</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <!doctype html>
      <html lang="bn">
        <head><title>সর্বশেষ সংবাদ | কালের কণ্ঠ</title></head>
        <body><main><h1>সর্বশেষ সংবাদ</h1>#{cards}</main></body>
      </html>
    HTML

    with_url_page('https://www.kalerkantho.com/', html) do |page|
      payload = extract_payload(page, reader_mode: false)

      expect(payload).to include('contentType' => 'list', 'hostAware' => false)
      8.times do |index|
        expect(payload['markdown']).to include("[সংবাদ শিরোনাম #{index + 1}](https://www.kalerkantho.com/online/national/2026/07/#{index + 10}/story-#{index})")
      end
    end
  end
end
