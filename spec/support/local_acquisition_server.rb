# frozen_string_literal: true

require "socket"
require "timeout"

class LocalAcquisitionServer
  Request = Struct.new(:path, :headers, keyword_init: true)

  attr_reader :port

  def initialize
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @requests = Queue.new
    @mutex = Mutex.new
    @closed = false
    @clients = []
    @workers = []
    @acceptor = Thread.new { accept_requests }
  end

  def url(path)
    "http://127.0.0.1:#{port}#{path}"
  end

  def wait_for_request(path, timeout: 2.0)
    Timeout.timeout(timeout) do
      loop do
        request = @requests.pop
        return request if request.path == path
      end
    end
  rescue Timeout::Error
    raise "timed out waiting for local request #{path}"
  end

  def close
    @server.close
    clients, workers = @mutex.synchronize do
      @closed = true
      [@clients.dup, @workers.dup]
    end
    clients.each do |client|
      client.close unless client.closed?
    rescue IOError
      nil
    end
    @acceptor.join(1)
    workers.each { |worker| worker.join(1) }
  end

  private

  def accept_requests
    loop do
      client = @server.accept
      @mutex.synchronize do
        if @closed
          client.close
        else
          @clients << client
          @workers << Thread.new(client) { |socket| serve(socket) }
        end
      end
    end
  rescue IOError, Errno::EBADF
    nil
  end

  def serve(client)
    request = read_request(client)
    return unless request

    @requests << request
    case request.path
    when "/redirect"
      respond(client, "302 Found", { "Location" => "/hydrated" }, "")
    when "/hydrated"
      body = <<~HTML
        <!doctype html><html><head><title>redirected</title></head><body>
        <main id="hydrated">waiting</main>
        <script>setTimeout(() => { document.querySelector('#hydrated').textContent = 'hydrated body'; }, 120);</script>
        </body></html>
      HTML
      respond(client, "200 OK", { "Content-Type" => "text/html" }, body)
    when "/persistent"
      text = "content ready #{"visible body text " * 24}"
      body = "<!doctype html><html><body><main>#{text}</main><script>fetch('/pending');</script></body></html>"
      respond(client, "200 OK", { "Content-Type" => "text/html" }, body)
    when "/pending"
      client.write("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 1000000\r\n\r\npending")
      client.flush
      wait_for_client_close(client)
    when "/set-cookie"
      respond(client, "200 OK", { "Content-Type" => "text/html", "Set-Cookie" => "local_session=kept; Path=/; SameSite=Lax" }, html("cookie set"))
    when "/echo-cookie"
      cookie = request.headers.fetch("cookie", "")
      respond(client, "200 OK", { "Content-Type" => "text/html" }, html(cookie))
    when "/drop"
      nil
    else
      respond(client, "200 OK", { "Content-Type" => "text/html" }, html("recovered"))
    end
  rescue IOError, SystemCallError, Timeout::Error
    nil
  ensure
    client.close unless client.closed?
    @mutex.synchronize { @clients.delete(client) }
  end

  def read_request(client)
    Timeout.timeout(2.0) do
      request_line = client.gets("\r\n")
      return unless request_line

      headers = {}
      while (line = client.gets("\r\n")) && line != "\r\n"
        name, value = line.split(":", 2)
        headers[name.downcase] = value.to_s.strip if value
      end
      Request.new(path: request_line.split[1].to_s.split("?", 2).first, headers: headers.freeze)
    end
  rescue Timeout::Error, IOError, SystemCallError
    nil
  end

  def respond(client, status, headers, body)
    fields = headers.merge("Content-Length" => body.bytesize.to_s, "Connection" => "close")
    client.write("HTTP/1.1 #{status}\r\n")
    fields.each { |name, value| client.write("#{name}: #{value}\r\n") }
    client.write("\r\n#{body}")
  end

  def wait_for_client_close(client)
    loop do
      next unless IO.select([client], nil, nil, 0.1)

      data = client.read_nonblock(1024, exception: false)
      break if data.nil? || data == :eof
    end
  end

  def html(text)
    "<!doctype html><html><body><main>#{text}</main></body></html>"
  end
end
