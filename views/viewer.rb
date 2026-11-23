require 'opal'

require 'lib/three'
require 'lib/window'
require 'lib/console'
require 'lib/document'

module Viewer
    extend self

    DEBUG = false

    CLICK_TOLERANCE = 5

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

        @scene.add(@camera)

        directional_light = Three::DirectionalLight.new(
            Three::Color.new('hsl(0, 100%, 100%)'),
            2
        )

        directional_light.position.set(1, 1, 0)

        light_target = Three::Object3D.new()

        light_target.position.set(0, 0, -1)

        @camera.add(directional_light)
        @camera.add(light_target)

        directional_light.target = light_target

        if DEBUG
            light_helper = Three::DirectionalLightHelper.new(directional_light)

            @scene.add(light_helper)
        end

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

        mouse_down_x = nil
        mouse_down_y = nil

        @selected = nil

        @renderer.domElement.addEventListener('mousedown') do |event|
            event = Native(event)

            mouse_down_x = event.clientX
            mouse_down_y = event.clientY
        end

        @renderer.domElement.addEventListener('mouseup') do |event|
            event = Native(event)

            clicked = mouse_down_x &&
                (event.clientX - mouse_down_x).abs <= CLICK_TOLERANCE &&
                (event.clientY - mouse_down_y).abs <= CLICK_TOLERANCE

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

                        object[:mesh].geometry.dispose()
                        object[:mesh].material.dispose()
                        object[:lines].geometry.dispose()
                        object[:lines].material.dispose()
                    end

                    @objects = []

                    @selected = nil

                    load_objects do
                        @loading = false
                    end
                end
            when 'e'
                if @selected
                    Window.location.href = "/export/#{@selected[:index]}/models/#{model_path}"
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

    def model_path()
        Document.getElementById('path').value
    end

    def load_objects()
        Window.fetch("/stl/models/#{model_path}").then do |response|
            response = Native(response)

            if response.ok
                response.json().then do |objects|
                    objects.each_with_index do |object, index|
                        object = Native(object)

                        loader = Three::STLLoader.new()

                        geometry = loader.parseBase64(object['stl_base64'])

                        material = Three::MeshStandardMaterial.new()

                        if object['color']
                            material.color = Three::Color.new(object['color'])
                        else
                            material.color = MESH_COLOR
                        end

                        if object['opacity']
                            material.transparent = true
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
                            index: index,
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