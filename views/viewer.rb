require 'opal'

require 'three'
require 'window'
require 'console'
require 'document'

PYTHON_SERVER = "http://localhost:#{PYTHON_PORT}"

class Viewer
    extend self

    DEBUG = false

    MESH_COLOR = Three::Color.new('hsl(50, 100%, 50%)')
    LINE_COLOR = Three::Color.new('hsl(0, 0%, 0%)')
    SELECTED_LINE_COLOR = Three::Color.new('hsl(0, 0%, 100%)')

    def init()
        @renderer = Three::WebGLRenderer.new({
            antialias: true
        })

        @renderer.setSize(Window.innerWidth, Window.innerHeight)

        Document.body.appendChild(@renderer.domElement)

        @scene = Three::Scene.new()

        @scene.background = Three::Color.new('hsl(0, 0%, 70%)')

        ambient_light = Three::AmbientLight.new(
            Three::Color.new('hsl(0, 100%, 100%)')
        )

        @scene.add(ambient_light)

        directional_light = Three::DirectionalLight.new(
            Three::Color.new('hsl(0, 100%, 100%)'),
            2
        )

        directional_light.position.set(10, 10, 10)

        @scene.add(directional_light)

        if DEBUG
            light_helper = Three::DirectionalLightHelper.new(directional_light)

            @scene.add(light_helper)
        end

        axes_helper = Three::AxesHelper.new(1000000)

        @scene.add(axes_helper)

        aspect = Window.innerWidth / Window.innerHeight

        distance = 100

        @camera = Three::OrthographicCamera.new(
            -distance * aspect / 2,
            distance * aspect / 2,
            distance / 2,
            -distance / 2,
            0.1,
            1000000
        )

        @camera.up.set(0, 0, 1)

        @camera.position.set(distance, -distance, distance)

        @controls = Three::OrbitControls.new(@camera, @renderer.domElement)

        @controls.mouseButtons = {
            LEFT: Three::MOUSE.ROTATE,
            RIGHT: Three::MOUSE.DOLLY,
            MIDDLE: Three::MOUSE.PAN
        }

        @renderer.render(@scene, @camera)

        render()

        @objects = []

        load_objects do
            unless @objects.empty?
                box = Three::Box3.new()
    
                @objects.each do |object|
                    box.expandByObject(object[:mesh])
                end
    
                size = Three::Vector3.new()
    
                box.getSize(size)
    
                center = Three::Vector3.new()
    
                box.getCenter(center)
    
                aspect = Window.innerWidth / Window.innerHeight
    
                distance = [ size.x, size.y, size.z ].max
    
                @camera.top = distance / 2
                @camera.left = -distance * aspect / 2
                @camera.right = distance * aspect / 2
                @camera.bottom = -distance / 2

                @controls.target.copy(center)

                view(:isometric)
            end
        end

        clicked = false

        @selected = nil

        @renderer.domElement.addEventListener('mousedown') do
            clicked = true
        end

        @renderer.domElement.addEventListener('mousemove') do
            clicked = false
        end

        @renderer.domElement.addEventListener('mouseup') do |event|
            event = Native(event)

            if clicked
                if event.button == 0
                    line_material = Three::LineBasicMaterial.new({
                        color: LINE_COLOR
                    })

                    if @selected
                        @selected[:lines].material = line_material
    
                        @selected = nil
                    end
    
                    mouse = Three::Vector2.new()
    
                    mouse.x = (event.clientX / Window.innerWidth) * 2 - 1
                    mouse.y = -(event.clientY / Window.innerHeight) * 2 + 1
    
                    raycaster = Three::Raycaster.new()
    
                    raycaster.setFromCamera(mouse, @camera)
    
                    meshes = @objects.map { |object| object[:mesh] }
    
                    intersects = raycaster.intersectObjects(meshes)
    
                    unless intersects.empty?
                        @selected = @objects.find { |object|
                            intersects[0].object == object[:mesh]
                        }

                        line_material = Three::LineBasicMaterial.new({
                            color: SELECTED_LINE_COLOR
                        })
    
                        @selected[:lines].material = line_material
                    end
                end
            end
        end

        Window.addEventListener('keydown') do |event|
            event = Native(event)

            case event.key
            when 't'
                view(:top)
            when 'l'
                view(:left)
            when 'f'
                view(:front)
            when 'i'
                view(:isometric)
            when 'r'
                unless @loading
                    @loading = true

                    @objects.each do |object|
                        @scene.remove(object[:mesh])
                        @scene.remove(object[:lines])
                    end

                    @objects = []

                    load_objects do
                        @loading = false
                    end
                end
            when 'e'
                if @selected
                    exporter = Three::STLExporter.new()

                    stl = exporter.parse(@selected[:mesh])

                    blob = JS.new($$[:Blob], [ stl ], { type: 'application/octet-stream' })

                    Window.showSaveFilePicker({
                        types: [{
                            accept: { 'model/stl': [ '.stl'] }
                        }]
                    }).then do |file|
                        file = Native(file)

                        file.createWritable().then do |writable|
                            writable = Native(writable)

                            writable.write(blob).then do
                                writable.close()
                            end
                        end
                    end
                end
            end
        end

        Window.addEventListener('resize') do
            resize
        end
    end

    def view(type)
        target = @controls.target.clone()

        distance = @camera.position.distanceTo(target)

        case type
        when :top
            @camera.position.set(
                target.x,
                target.y,
                target.z + distance
            )
        when :left
            @camera.position.set(
                target.x,
                target.y - distance,
                target.z
            )
        when :front
            @camera.position.set(
                target.x + distance,
                target.y,
                target.z
            )
        when :isometric
            @camera.position.set(
                target.x + distance,
                target.y - distance,
                target.z + distance
            )
        end

        @camera.updateProjectionMatrix()
    end

    def render()
        Window.requestAnimationFrame do
            render()
        end

        @controls.update()

        @renderer.render(@scene, @camera)
    end

    def resize()
        @renderer.setSize(Window.innerWidth, Window.innerHeight)

        aspect = Window.innerWidth / Window.innerHeight

        distance = @camera.top - @camera.bottom

        @camera.top =  distance / 2
        @camera.left = -distance * aspect / 2
        @camera.right = distance * aspect / 2
        @camera.bottom = -distance / 2

        @camera.updateProjectionMatrix()
    end

    def load_objects()
        path = Document.getElementById('path').value

        Window.fetch("#{PYTHON_SERVER}/stl/#{path}").then do |response|
            response = Native(response)

            if response.ok
                response.json().then do |objects|
                    objects.each do |object|
                        object = Native(object)

                        loader = Three::STLLoader.new()

                        geometry = loader.parseBase64(object['stl_base64'])

                        material = Three::MeshStandardMaterial.new({
                            transparent: true
                        })

                        if object['color']
                            material.color = Three::Color.new(object['color'])
                        else
                            material.color = MESH_COLOR
                        end

                        if object['opacity']
                            material.opacity = object['opacity']
                        end

                        mesh = Three::Mesh.new(geometry, material)

                        @scene.add(mesh)

                        edges = Three::EdgesGeometry.new(geometry, 30)

                        line_material = Three::LineBasicMaterial.new({
                            color: LINE_COLOR
                        })

                        lines = Three::LineSegments.new(edges, line_material)

                        @scene.add(lines)

                        @objects << {
                            mesh: mesh,
                            lines: lines
                        }
                    end

                    if block_given?
                        yield
                    end
                end
            else
                response.text().then do |error|
                    if block_given?
                        yield
                    end

                    Window.alert(error)
                end
            end
        end
    end
end

Viewer.init()