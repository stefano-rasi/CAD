namespace :node do
    output = 'static/three.js'

    modules = 'node_modules/.package-lock.json'

    file modules => 'package.json' do
        sh 'npm', 'install'
    end

    file output => [ modules, 'webpack.config.js', *FileList['node/**/*.js'] ] do
        sh 'npx', 'webpack'
    end

    task build: output

    task watch: modules do
        sh 'npx', 'webpack', '--watch'
    end
end

namespace :opal do
    output = 'static/viewer.js'

    sources = FileList['views/**/*.rb', 'lib/**/*.rb']

    file output => sources do
        require 'opal'

        builder = Opal::Builder.new()

        builder.append_paths('.')

        builder.build('views/viewer.rb', debug: true)

        source_map = Base64.strict_encode64(JSON.dump(builder.source_map.as_json))

        mkdir_p File.dirname(output)

        File.write(output, "#{builder.to_s}\n//# sourceMappingURL=data:application/json;base64,#{source_map}")

        puts "Built #{output}"
    end

    task build: output

    task :watch do
        loop do
            Rake::Task[output].reenable
            Rake::Task[output].invoke

            sleep 1
        end
    end
end

file 'static/viewer.css' => 'views/viewer.css' do |task|
    mkdir_p File.dirname(task.name)

    cp task.source, task.name
end

task build: [ 'node:build', 'opal:build', 'static/viewer.css' ]

task :start, [:port] => :build do |task, arguments|
    port = arguments.fetch(:port, '5000')

    sh 'python', 'app.py', port
end

task default: :build
