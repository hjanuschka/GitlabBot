module GitlabBot
  require 'webrick'
  require 'json'
  require 'rest-client'
  
  class Server
    attr_accessor :config, :mrbot
    def initialize(conf = {})
      @config = conf
      @mrbot = MergeBot.new(conf)
    end

    def run!
      server = WEBrick::HTTPServer.new(Port: @config['port'])
      server.mount_proc '/' do |req, _res|
        handleRequest req
      end
      server.start
    end

    def stop
      server.shutdown
    end

    def handleRequest(req)
      jso_body = JSON.parse(req.body)
      @mrbot.handlePayload(jso_body)
    end
  end
end
