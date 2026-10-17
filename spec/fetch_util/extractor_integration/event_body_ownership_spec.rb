# frozen_string_literal: true

RSpec.describe 'Complete owned event descriptions' do
  include_context 'extractor integration helpers'

  def extract_owned_event_body(html)
    with_url_page('https://events.publication.example.test/events/research-workshop/42', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract(page)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      yield result
    end
  end

  it 'retains the introduction, every peer section, complete program and closing resources' do
    html = <<~HTML
      <html><head><title>Public research workshop</title></head><body><main>
        <h1>Public research workshop</h1>
        <time itemprop="startDate" datetime="2031-04-12T10:00:00Z">12 April 2031</time>
        <div class="event-location">Community research hall</div>
        <p>Register for the public workshop. The introduction explains the complete research methods and links to the <a href="/protocol">research protocol</a>.</p>
        <section><h2>Preparation</h2>
          <p>Every participant can reproduce the original analysis before discussing all of the results at the workshop.</p>
          <pre><code>curl --fail https://data.publication.example.test/complete.csv
      analyze --all complete.csv</code></pre>
        </section>
        <section><h2>Discussion</h2>
          <p>The second session includes questions from participants and a complete explanation of the original findings.</p>
        </section>
        <p>The closing account preserves every participant contribution and the <a href="/proceedings">complete proceedings</a>.</p>
        <p hidden>Unpublished private scheduling note.</p>
        <details><summary>Accessibility questions</summary><p>Private closed-answer text.</p></details>
      </main></body></html>
    HTML

    extract_owned_event_body(html) do |result|
      markdown = result.fetch('markdown')
      fragments = ['complete research methods', 'Preparation', 'reproduce the original analysis',
                   'curl --fail https://data.publication.example.test/complete.csv', 'analyze --all complete.csv',
                   'Discussion', 'complete explanation of the original findings', 'every participant contribution']
      fragments.each { |fragment| expect(markdown).to include(fragment) }
      expect(fragments.map { |fragment| markdown.index(fragment) }).to eq(fragments.map { |fragment| markdown.index(fragment) }.sort)
      expect(markdown.scan(/^# Public research workshop$/).length).to eq(1)
      expect(markdown).to include('[research protocol](https://events.publication.example.test/protocol)')
      expect(markdown).to include('[complete proceedings](https://events.publication.example.test/proceedings)')
      expect(markdown).to include('Accessibility questions')
      expect(markdown).not_to include('Unpublished private scheduling note', 'Private closed-answer text')
    end
  end

  it 'keeps authored paragraphs outside an explicitly named description without exposing controls' do
    html = <<~HTML
      <html><head><title>Public research workshop</title></head><body><main>
        <h1>Public research workshop</h1>
        <time itemprop="startDate" datetime="2031-04-12T10:00:00Z">12 April 2031</time>
        <div class="event-location">Community research hall</div>
        <p>The complete opening account explains why the original research matters to all workshop participants.</p>
        <div class="event-description"><h2>About this event</h2>
          <p>The central description explains the complete presentation and the questions that will be discussed.</p>
        </div>
        <section><h2>Further reading</h2>
          <p>The complete follow-up account and <a href="/references">authored references</a> remain available after the event.</p>
        </section>
        <form class="ticket-checkout"><p>Private purchase control.</p><button>Reserve a ticket</button></form>
        <p style="display:none">Hidden promotional text.</p>
      </main></body></html>
    HTML

    extract_owned_event_body(html) do |result|
      markdown = result.fetch('markdown')
      expect(markdown).to include('complete opening account', 'central description', 'complete follow-up account')
      expect(markdown).to include('[authored references](https://events.publication.example.test/references)')
      expect(markdown.scan(/^# Public research workshop$/).length).to eq(1)
      expect(markdown).not_to include('Private purchase control', 'Reserve a ticket', 'Hidden promotional text')
    end
  end
end
