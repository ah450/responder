require "sinatra"
require "json"

configure do
    set(:deploy_config) { JSON.parse(File.read("config.json")) }
end


post '/deploy' do
    body = request.body.read
    payload = JSON.parse(body)
    repo_name = payload["repository"]["full_name"]
    halt 404, "Unknown repository" unless settings.deploy_config.has_key? repo_name
    verify_signature(body, settings.deploy_config[repo_name]["secret"])
    case request.env['HTTP_X_GITHUB_EVENT']
    when 'pull_request'
        if payload["action"].eql? "closed" && payload["pull_request"]["merged"]
            deploy repo_name
            puts "Done with pull"
        end
    when 'push'
        if payload["ref"].eql? settings.deploy_config[repo_name]["ref"]
            deploy repo_name
            puts "Done with push"
        end
    else
        halt 400, "Bad Event."
    end
end

def verify_signature(payload_body, token)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), token, payload_body)
    halt 403, "Failed to verify signature!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
end

def deploy(repo_name)
    pre_pull_script = settings.deploy_config[repo_name]["pre_pull_script"]
    pull_script = settings.deploy_config[repo_name]["pull_script"]
    post_pull_script = settings.deploy_config[repo_name]["post_pull_script"]
    system("bash #{pre_pull_script}")
    system("bash #{pull_script}")
    system("bash #{post_pull_script}")
end
