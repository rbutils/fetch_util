# frozen_string_literal: true

RSpec.describe 'Complete source-owned event dates' do
  include_context 'extractor integration helpers'

  def extract_event_dates(html, path = '/events/research-workshop/42')
    with_url_page("https://events.publication.example.test#{path}", html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract(page)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      yield result
    end
  end

  it 'retains the complete day-month-year date rather than its year prefix' do
    html = <<~HTML
      <html><head><title>Public research workshop</title></head><body><main>
        <h1>Public research workshop</h1><p>7 Dec 2015</p>
        <div class="event-location">Community research hall</div>
        <p>Register to attend this public workshop. Researchers will explain their complete methods and discuss the original results with all participants.</p>
        <p>The workshop includes an accessible presentation, questions from participants, and a complete published account of the research.</p>
      </main></body></html>
    HTML

    extract_event_dates(html) do |result|
      expect(result.fetch('publishedTime')).to eq('7 Dec 2015')
      expect(result.fetch('markdown')).to include('complete methods', 'complete published account')
    end
  end

  it 'keeps the training and submission schedule without borrowing its dates' do
    html = <<~HTML
      <html><head><title>Research workshop data challenge</title></head><body><main>
        <h1>Research workshop data challenge</h1>
        <p>Register to participate in the research challenge. The complete task description explains how to prepare data, submit predictions, and compare the original results.</p>
        <div class="event-location">Community research hall</div>
        <section aria-labelledby="important-dates"><h2 id="important-dates">Important dates</h2>
          <ul><li>Release of training: from 7 Dec 2015</li><li>Release of development set: 30 Dec 2015</li>
          <li>Submission deadline: 15 Jan 2016</li></ul>
        </section>
        <p>Every release date belongs to the challenge schedule. The page does not declare when the workshop itself starts.</p>
      </main></body></html>
    HTML

    extract_event_dates(html, '/challenge') do |result|
      expect(result['publishedTime']).to be_nil
      expect(result.fetch('markdown')).to include('7 Dec 2015', '30 Dec 2015', '15 Jan 2016')
      expect(result.fetch('markdown')).to include('complete task description', 'does not declare when the workshop itself starts')
    end
  end

  it 'distinguishes scheduled release time elements from the declared event date' do
    html = <<~HTML
      <html><head><title>Public research workshop</title></head><body><main>
        <h1>Public research workshop</h1>
        <section><h2>Preparation</h2><dl>
          <dt>Release of training data</dt><dd><time datetime="2015-12-07">7 Dec 2015</time></dd>
          <dt>Submission deadline</dt><dd><time datetime="2016-01-15">15 Jan 2016</time></dd>
        </dl></section>
        <p class="event-date">When: 20 Jan 2016</p>
        <div class="event-location">Community research hall</div>
        <p>Register to attend the complete public workshop. The preparation schedule remains available for every participant.</p>
      </main></body></html>
    HTML

    extract_event_dates(html) do |result|
      expect(result.fetch('publishedTime')).to eq('When: 20 Jan 2016')
      expect(result.fetch('markdown')).to include('preparation schedule')
      expect(result.fetch('markdown')).not_to include('- Date: 2015-12-07')
    end
  end

  it 'keeps complete month-first dates without inventing a day from a year' do
    ['December 7, 2015', 'December 2015'].each do |date|
      html = <<~HTML
        <html><head><title>Public research workshop</title></head><body><main>
          <h1>Public research workshop</h1><p>#{date}</p>
          <div class="event-location">Community research hall</div>
          <p>Register to attend the complete public workshop and discuss the original research with its authors.</p>
        </main></body></html>
      HTML

      extract_event_dates(html) do |result|
        expect(result['publishedTime']).to eq(date == 'December 2015' ? nil : date)
        expect(result.fetch('markdown')).to include(date)
      end
    end
  end

  it 'does not borrow dates from a literal program or hidden text' do
    html = <<~HTML
      <html><head><title>Public research workshop</title></head><body><main>
        <h1>Public research workshop</h1>
        <pre><code>example = "December 7, 2015"</code></pre>
        <p hidden>December 8, 2015</p>
        <div class="event-location">Community research hall</div>
        <p>Register to attend the public research workshop. The complete example is documentation, not an event date declaration.</p>
      </main></body></html>
    HTML

    extract_event_dates(html) do |result|
      expect(result['publishedTime']).to be_nil
      expect(result.fetch('markdown')).to include('example = "December 7, 2015"')
      expect(result.fetch('markdown')).not_to include('December 8, 2015')
    end
  end
end

RSpec.describe 'Event dates distinct from submission milestones' do
  include_context 'extractor integration helpers'

  def with_event_milestones(workshop:)
    date = workshop ? '<li>Workshop: 11/12 Apr 2016 (Registration open to all)</li>' : ''
    html = <<~HTML
      <html><head><title>Research workshop timetable</title></head><body><main>
        <h1>Research workshop timetable</h1>
        <p>Register to participate in the public research workshop. The complete task description explains every dataset, submission and report.</p>
        <div class="event-location">Community research hall</div>
        <section><h2>Important dates</h2><ul>
          <li>Release of training: from 7 Dec 2015</li>
          <li>Release of dev set: 30 Dec 2015</li>
          <li>Release of test set: 31 Jan 2016</li>
          <li><b>Submission of results: 7 Feb 2016</b></li>
          <li><b>Submission of reports: 7 Feb 2016</b></li>
          <li>Challenge Notification: 18 Feb 2016</li>
          <li>Challenge camera-ready deadline: 28 Feb 2016</li>
          #{date}
        </ul></section>
        <p>All participants can consult the complete timetable and the published account of the research.</p>
      </main></body></html>
    HTML
    with_url_page('https://events.publication.example.test/events/research-workshop/42', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract(page)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      yield result
    end
  end

  it 'uses the complete declared workshop date after all release and submission milestones' do
    with_event_milestones(workshop: true) do |result|
      expect(result.fetch('publishedTime')).to eq('11/12 Apr 2016')
      expect(result.fetch('markdown')).to include('Submission of results: 7 Feb 2016', 'Registration open to all', 'complete timetable')
    end
  end

  it 'does not invent an event date when only releases, submissions and notification dates are declared' do
    with_event_milestones(workshop: false) do |result|
      expect(result['publishedTime']).to be_nil
      expect(result.fetch('markdown')).to include('7 Dec 2015', '7 Feb 2016', '18 Feb 2016', '28 Feb 2016', 'complete timetable')
    end
  end
end
