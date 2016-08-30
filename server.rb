require 'webrick'
require 'json'
require 'rest-client'

lgtm_users = ['hjanuschka', 'd.karl', 'c.felberbauer', 'l.relota', 's.schimpf', 'j.stiegler', 'h.kaplan']
require_lgtm = 2
gitlab_host = 'http://gitlab.krone.at/api/v3'
gitlab_api_token = 'm9M4tANJvasF3enqm9sb'

server = WEBrick::HTTPServer.new(Port: ARGV.first)
server.mount_proc '/' do |req, _res|
  jso_body = JSON.parse(req.body)

  if jso_body['object_kind'] == 'merge_request'

    if jso_body['user']['username'] != 'kmm.deploy'

      # Merge request hook
      # Check if we already seen this MR - if so remove it - as MR has been updated
      mr_config = "/ci-bot/MRS/#{jso_body['object_attributes']['id']}.json"
      project_id = jso_body['object_attributes']['target_project_id']
      mr_id = jso_body['object_attributes']['id']
      File.unlink(mr_config) if File.exist?(mr_config)

      file_jso = {
        'lgtm' => 0,
        'lgtmers' => []
      }
      puts 'RESET INIT MR'
      File.write(mr_config, file_jso.to_json)

      RestClient::Request.execute(method: :post, url: "#{gitlab_host}/projects/#{project_id}/merge_requests/#{mr_id}/notes", payload: { body: 'LGTM init/reset' }, headers: { 'PRIVATE-TOKEN' => gitlab_api_token })
    end
  end
  if jso_body['object_kind'] == 'note' && jso_body['object_attributes']['noteable_type'] == 'MergeRequest'
    # Merge request hook
    #

    puts 'GOT MR NOTE'
    mr_config = "/ci-bot/MRS/#{jso_body['merge_request']['id']}.json"

    # check if note contains LGTM
    note = jso_body['object_attributes']['note']

    if File.exist?(mr_config)
      file = File.read(mr_config)
      file_jso = JSON.parse(file)
    else
      file_jso = {
        'lgtm' => 0,
        'lgtmers' => []
      }
    end

    puts file_jso.inspect

    if note =~ /LGTM/
      if lgtm_users.include? jso_body['user']['username']
        unless file_jso['lgtmers'].include?("@#{jso_body['user']['username']}")
          # user is a LGTM user & and has not already lgtm'd
          puts 'IN IF'
          file_jso['lgtmers'].push("@#{jso_body['user']['username']}")
          file_jso['lgtm'] += 1

          puts "Updated MR with lgtm #{file_jso.inspect}"

          File.write(mr_config, file_jso.to_json)
          if file_jso['lgtm'] >= require_lgtm
            # POST COMMENT VIA API
            # call MERGE via API
            project_id = jso_body['merge_request']['target_project_id']
            mr_id = jso_body['merge_request']['id']

            approvers = file_jso['lgtmers'].join(' ')

            # Comment on MR

            # system('curl', '-s', '-o', '/dev/null', '--form', 'body='.$current_msg, '--header', 'PRIVATE-TOKEN: '.$config{private_token}, $config{gitlab_url}.'/api/v3/projects/'.$project_id.'/merge_requests/'.$id.'/notes');
            RestClient::Request.execute(method: :post, url: "#{gitlab_host}/projects/#{project_id}/merge_requests/#{mr_id}/notes", payload: { body: "I will merge this as #{approvers} approved it" }, headers: { 'PRIVATE-TOKEN' => gitlab_api_token })
            RestClient::Request.execute(method: :put, url: "#{gitlab_host}/projects/#{project_id}/merge_request/#{mr_id}/merge?merge_when_build_succeeds=true", headers: { 'PRIVATE-TOKEN' => gitlab_api_token })

          end
        end
      end
    end

  end
end

trap 'INT' do
  server.shutdown
end
server.start
