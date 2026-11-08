require 'opal'

require 'js'
require 'native'

module Three
    def self.const_missing(name)
        ThreeClass.new(name)
    end

    class ThreeClass
        def initialize(name)
            @name = name

            @class = $$[:THREE][name]
        end

        def new(*args)
            Native(JS.new(@class, *args.map(&:to_n)))
        end

        def method_missing(name, *args, &block)
            $$[:THREE][@name][name]
        end
    end

    class STLLoader
        def self.new(*args)
            Native(JS.new($$[:STLLoader], *args.map(&:to_n)))
        end
    end

    class STLExporter
        def self.new(*args)
            Native(JS.new($$[:STLExporter], *args.map(&:to_n)))
        end
    end

    class OrbitControls
        def self.new(*args)
            Native(JS.new($$[:OrbitControls], *args.map(&:to_n)))
        end
    end
end