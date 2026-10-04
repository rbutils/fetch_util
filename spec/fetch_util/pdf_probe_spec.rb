# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil.const_get(:PdfProbe, false) do
  it 'recognizes supported PDF URL patterns and derives titles' do
    expect(described_class.pdf_url?('https://example.test/paper.PDF')).to be(true)
    expect(described_class.pdf_url?('https://example.test/pdf/123')).to be(true)
    expect(described_class.pdf_url?('https://example.test/download?format=pdf')).to be(true)
    expect(described_class.pdf_url?('https://example.test/article')).to be(false)

    probe = described_class.new(timeout: 2)
    expect(probe.title('https://example.test/report%20final.pdf', {})).to eq('report final.pdf')
    headers = { 'content-disposition' => ['attachment; filename="C++.pdf"'] }
    expect(probe.title('https://example.test/download', headers)).to eq('C++.pdf')
  end

  it 'shares one timeout deadline across redirects' do
    now = 10.0
    redirect = Net::HTTPFound.new('1.1', '302', 'Found')
    redirect['location'] = '/paper.pdf'
    success = Net::HTTPOK.new('1.1', '200', 'OK')
    success['content-type'] = 'application/pdf'
    probe = described_class.new(timeout: 5)
    requests = []
    allow(probe).to receive(:monotonic_now) { now }
    allow(probe).to receive(:request_head) do |uri, timeout:|
      requests << [uri.to_s, timeout]
      now += 3 if requests.length == 1
      requests.length == 1 ? redirect : success
    end

    info = probe.send(:probe_pdf_headers, 'https://example.test/download?id=paper')

    expect(requests.map(&:first)).to eq(['https://example.test/download?id=paper', 'https://example.test/paper.pdf'])
    expect(requests.map(&:last)).to eq([5.0, 2.0])
    expect(info[:final_url]).to eq('https://example.test/paper.pdf')
  end

  it 'stops probing after the shared timeout is exhausted' do
    now = 10.0
    redirect = Net::HTTPFound.new('1.1', '302', 'Found')
    redirect['location'] = '/paper.pdf'
    probe = described_class.new(timeout: 5)
    requests = []
    allow(probe).to receive(:monotonic_now) { now }
    allow(probe).to receive(:request_head) do |uri, timeout:|
      requests << [uri.to_s, timeout]
      now += 5
      redirect
    end

    expect(probe.send(:probe_pdf_headers, 'https://example.test/download?id=paper')).to be_nil
    expect(requests).to eq([['https://example.test/download?id=paper', 5.0]])
  end

  it 'allows at most three redirects after the initial HEAD request' do
    redirect = Net::HTTPFound.new('1.1', '302', 'Found')
    redirect['location'] = '/next'
    requests = 0
    probe = described_class.new(timeout: 2)
    allow(probe).to receive(:request_head) do
      requests += 1
      redirect
    end

    expect(probe.send(:probe_pdf_headers, 'https://example.test/download')).to be_nil
    expect(requests).to eq(described_class::REDIRECT_LIMIT + 1)
  end

  it 'bounds HEAD connection and response timeouts by the remaining allowance' do
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    http = instance_double(Net::HTTP, request: response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(Timeout).to receive(:timeout).with(4.25).and_yield
    probe = described_class.new(timeout: 5)

    expect(probe.send(:request_head, URI('https://example.test/download'), timeout: 4.25)).to equal(response)
    expect(Net::HTTP).to have_received(:start).with(
      'example.test', 443, use_ssl: true, open_timeout: 4.25, read_timeout: 4.25
    )
  end
end
