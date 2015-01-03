require "sinatra"
require "json"

configure do
    set(:deploy_config) { JSON.parse(File.open("config.json")) }
end


post '/deploy' do
    payload = JSON.parse(params[:payload])
    repo_name = @payload["repository"]["full_name"]
    halt 404, "Unknown repository" unless settings.deploy_config.has? repo_name
    verify_signature(request.body.read, settings.deploy_config[repo_name]["secret"])
    case request.env['HTTP_X_GITHUB_EVENT']
    when 'pull_request'
        if payload["action"].eql? "closed" && payload["pull_request"]["merged"]
            deploy repo_name
        end
    when 'push'
        if payload["ref"].eql? "refs/heads/master"
            deploy repo_name
        end
    else
        halt 400, "Bad Event."
    end
end

def verify_signature(payload_body, token)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), token, payload_body)
    halt 403, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
end

def deploy(repo_name)
    location = settings.deploy_config[repo_name]["location"]
    pre_pull_script = settings.deploy_config["pre_pull_script"]
    pull_script = settings.deploy_config["pull_script"]
    post_pull_script = settings.deploy_config["post_pull_script"]
    system("bash #{pre_pull_script}")
    system("bash #{pull_script}")
    system("bash #{post_pull_script}")
end