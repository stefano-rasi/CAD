namespace :three do
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

task :start, [:ruby_port, :python_port] => 'three:build' do |task, arguments|
    ruby_port = arguments.fetch(:ruby_port, '4567')
    python_port = arguments.fetch(:python_port, '5000')

    python = Process.spawn('python', 'app.py', ruby_port, python_port)

    begin
        ruby 'app.rb', ruby_port, python_port
    ensure
        Process.kill(:KILL, python) rescue nil

        Process.wait(python) rescue nil
    end
end

task default: 'three:build'
