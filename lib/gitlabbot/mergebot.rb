module GitlabBot
  class MergeBot
    attr_accessor :config
    def initialize(opts = {})
      @config = opts
    end

    def handlePayload(jso)
      if jso['object_kind'] == 'merge_request'

        if jso['user']['username'] != @config['botUsername']

          # Merge request hook
          # Check if we already seen this MR - if so remove it - as MR has been updated
          mr_config = "MRS/#{jso['object_attributes']['id']}.json"
          project_id = jso['object_attributes']['target_project_id']
          mr_id = jso['object_attributes']['id']
          File.unlink(mr_config) if File.exist?(mr_config)

          file_jso = {
            'lgtm' => 0,
            'lgtmers' => []
          }
          puts 'RESET INIT MR'
          File.write(mr_config, file_jso.to_json)

          RestClient::Request.execute(method: :post, url: "#{@config['endpoint']}/projects/#{project_id}/merge_requests/#{mr_id}/notes", payload: { body: 'LGTM init/reset' }, headers: { 'PRIVATE-TOKEN' => @config['token'] })
        end
      end
      if jso['object_kind'] == 'note' && jso['object_attributes']['noteable_type'] == 'MergeRequest'
        # Merge request hook
        #

        puts 'GOT MR NOTE'
        mr_config = "MRS/#{jso['merge_request']['id']}.json"

        # check if note contains LGTM
        note = jso['object_attributes']['note']

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
          if @config["lgtmUsers"].include? jso['user']['username']
            unless file_jso['lgtmers'].include?("@#{jso['user']['username']}")
              # user is a LGTM user & and has not already lgtm'd
              puts 'IN IF'
              file_jso['lgtmers'].push("@#{jso['user']['username']}")
              file_jso['lgtm'] += 1

              puts "Updated MR with lgtm #{file_jso.inspect}"

              File.write(mr_config, file_jso.to_json)
              if file_jso['lgtm'] >= @config["lgtmRequired"]
                # POST COMMENT VIA API
                # call MERGE via API
                project_id = jso['merge_request']['target_project_id']
                mr_id = jso['merge_request']['id']

                approvers = file_jso['lgtmers'].join(' ')

                # Comment on MR

                RestClient::Request.execute(method: :post, url: "#{@config['endpoint']}/projects/#{project_id}/merge_requests/#{mr_id}/notes", payload: { body: "I will merge this as #{approvers} approved it" }, headers: { 'PRIVATE-TOKEN' => @config['token'] })
                RestClient::Request.execute(method: :put, url: "#{@config['endpoint']}/projects/#{project_id}/merge_request/#{mr_id}/merge?merge_when_build_succeeds=true", headers: { 'PRIVATE-TOKEN' => @config['token'] })

              end
            end
          end
        end

      end
    end
  end
end
