require 'json'
require './lib/gitlabbot/mergebot.rb'
require './lib/gitlabbot/server.rb'

# Read config
if File.exist?('config.json')
  config_file = File.read('config.json')
  config = JSON.parse(config_file)
  server = GitlabBot::Server.new(config)
  server.run!

else
  raise 'Config file not found'
end
trap 'INT' do
  server.stop
end
