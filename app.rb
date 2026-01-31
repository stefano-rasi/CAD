require 'opal'
require 'yaml'
require 'sinatra'

RUBY_PORT = ARGV[0]
PYTHON_PORT = ARGV[1]

set :port, RUBY_PORT

get '/views/*' do
    content_type 'text/javascript'

    builder = Opal::Builder.new()

    builder.append_paths('lib')

    builder.build_str(%Q{
        require 'opal'

        PYTHON_PORT = #{PYTHON_PORT}
    })

    builder.build(params[:splat][0], debug: true)

    "#{builder.to_s}\n//# sourceMappingURL=data:application/json;base64,#{Base64.strict_encode64(JSON.dump(builder.source_map.as_json))}"
end