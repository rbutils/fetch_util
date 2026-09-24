# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil compact CJK fallback excerpts' do
  include_context 'extractor integration helpers'

  it 'begins with the first owned article paragraph rather than a repeated heading or later long paragraph' do
    heading = '记录 ChatGPT 账号解封之后的订阅状态变化与公开说明'
    lead = '事先声明，这个账号是我自己从很早以前就一直使用的，突然收到提醒时我感到疑惑，所以决定记录实际经过。'
    continuation = '第二天我查看了收到的通知，逐项核对账户资料和订阅凭证，并把具体的处理步骤完整记录下来。'
    later = 'The later investigation followed a separate route with much longer prose about resolution and billing records.'
    html = <<~HTML
      <html><head><title>#{heading} - Notes</title></head><body><main>
        <h1>#{heading}</h1>
        <article class="article-content">
          <p>#{heading}</p><p>#{lead}</p><p>#{continuation}</p><p>#{later}</p>
          <figure><figcaption>资料来源与图片说明不应该成为正文摘要，即使这段文字很长也不会优先于文章开头。</figcaption></figure>
        </article>
      </main></body></html>
    HTML

    with_url_page('https://notes.example.test/a/123', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['excerpt']).to start_with(lead)
      expect(payload['excerpt']).to include(continuation)
      expect(payload['excerpt']).not_to include(heading, later, '资料来源与图片说明')
      expect(payload['markdown']).to include(lead, continuation, later)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
