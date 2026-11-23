require 'opal'

require 'lib/three'
require 'lib/window'
require 'lib/console'
require 'lib/document'

class Viewer
    DEBUG = false

    CLICK_TOLERANCE = 5

    INITIAL_VIEW_SIZE = 100

    LINE_COLOR = Three::Color.new('hsl(0, 0%, 0%)')
    MESH_COLOR = Three::Color.new('hsl(50, 100%, 50%)')
    LIGHT_COLOR = Three::Color.new('white')
    BACKGROUND_COLOR = Three::Color.new('hsl(0, 0%, 70%)')
    SELECTED_LINE_COLOR = Three::Color.new('hsl(0, 0%, 100%)')

    VIEW_DIRECTIONS = {
        top: [ 0, 0, 1 ],
        left: [ 0, -1, 0 ],
        front: [ 1, 0, 0 ],
        isometric: [ 1, -1, 1 ]
    }

    KEY_VIEWS = {
        't' => :top,
        'l' => :left,
        'f' => :front,
        'i' => :isometric
    }

    def start()
        @model_path = Document.getElementById('path').value

        @objects = []

        @loading = false

        @selected = nil

        create_renderer()
        create_scene()
        create_camera()
        create_lights()
        create_controls()

        listen_to_mouse()
        listen_to_keyboard()
        listen_to_resize()

        render()

        load_objects { fit_camera() }
    end

    def create_renderer()
        @renderer = Three::WebGLRenderer.new({
            antialias: true
        })

        @renderer.setSize(Window.innerWidth, Window.innerHeight)

        Document.body.appendChild(@renderer.domElement)
    end

    def create_scene()
        @scene = Three::Scene.new()

        @scene.background = BACKGROUND_COLOR

        @scene.add(Three::AmbientLight.new(LIGHT_COLOR))

        @scene.add(Three::AxesHelper.new(1000000))
    end

    def create_camera()
        @camera = Three::OrthographicCamera.new(-1, 1, 1, -1, 0.1, 1000000)

        @camera.up.set(0, 0, 1)

        @camera.position.set(INITIAL_VIEW_SIZE, -INITIAL_VIEW_SIZE, INITIAL_VIEW_SIZE)

        set_frustum(INITIAL_VIEW_SIZE)

        @scene.add(@camera)
    end

    def create_lights()
        directional_light = Three::DirectionalLight.new(LIGHT_COLOR, 2)

        directional_light.position.set(1, 1, 0)

        light_target = Three::Object3D.new()

        light_target.position.set(0, 0, -1)

        @camera.add(directional_light)
        @camera.add(light_target)

        directional_light.target = light_target

        if DEBUG
            @scene.add(Three::DirectionalLightHelper.new(directional_light))
        end
    end

    def create_controls()
        @controls = Three::OrbitControls.new(@camera, @renderer.domElement)

        @controls.mouseButtons = {
            LEFT: Three::MOUSE.ROTATE,
            RIGHT: Three::MOUSE.DOLLY,
            MIDDLE: Three::MOUSE.PAN
        }
    end

    def listen_to_mouse()
        mouse_down = nil

        @renderer.domElement.addEventListener('mousedown') do |event|
            event = Native(event)

            mouse_down = [ event.clientX, event.clientY ]
        end

        @renderer.domElement.addEventListener('mouseup') do |event|
            event = Native(event)

            if event.button == 0 && mouse_down && click?(mouse_down, event)
                select_at(event.clientX, event.clientY)
            end
        end
    end

    def listen_to_keyboard()
        Window.addEventListener('keydown') do |event|
            key = Native(event).key

            if KEY_VIEWS[key]
                view(KEY_VIEWS[key])
            elsif key == 'r'
                reload()
            elsif key == 'e'
                export_selected()
            elsif key == 'h'
                toggle_help()
            end
        end
    end

    def toggle_help()
        Document.getElementById('help').classList.toggle('hidden')
    end

    def listen_to_resize()
        Window.addEventListener('resize') do
            resize
        end
    end

    def click?(mouse_down, event)
        (event.clientX - mouse_down[0]).abs <= CLICK_TOLERANCE &&
            (event.clientY - mouse_down[1]).abs <= CLICK_TOLERANCE
    end

    def select_at(x, y)
        deselect

        mouse = Three::Vector2.new(
            (x / Window.innerWidth) * 2 - 1,
            -(y / Window.innerHeight) * 2 + 1
        )

        raycaster = Three::Raycaster.new()

        raycaster.setFromCamera(mouse, @camera)

        intersects = raycaster.intersectObjects(@objects.map { |object| object[:mesh] })

        unless intersects.empty?
            @selected = @objects.find { |object| intersects[0].object == object[:mesh] }

            @selected[:lines].material.color.copy(SELECTED_LINE_COLOR)
        end
    end

    def deselect()
        if @selected
            @selected[:lines].material.color.copy(LINE_COLOR)

            @selected = nil
        end
    end

    def export_selected()
        if @selected
            Window.location.href = "/export/#{@selected[:index]}/models/#{@model_path}"
        end
    end

    def view(type, distance = nil)
        target = @controls.target

        distance ||= @camera.position.distanceTo(target)

        direction = Three::Vector3.new(*VIEW_DIRECTIONS[type]).normalize()

        @camera.position.copy(target)
        @camera.position.addScaledVector(direction, distance)

        @camera.updateProjectionMatrix()
    end

    def fit_camera()
        unless @objects.empty?
            box = Three::Box3.new()

            @objects.each do |object|
                box.expandByObject(object[:mesh])
            end

            size = Three::Vector3.new()

            box.getSize(size)

            center = Three::Vector3.new()

            box.getCenter(center)

            largest_size = [ size.x, size.y, size.z ].max

            set_frustum(largest_size)

            @controls.target.copy(center)

            view(:isometric, largest_size * 2)
        end
    end

    def set_frustum(height)
        aspect = Window.innerWidth / Window.innerHeight

        @camera.top = height / 2
        @camera.bottom = -height / 2
        @camera.left = -height * aspect / 2
        @camera.right = height * aspect / 2

        @camera.updateProjectionMatrix()
    end

    def render()
        Window.requestAnimationFrame do
            render
        end

        @controls.update()

        @renderer.render(@scene, @camera)
    end

    def resize()
        @renderer.setSize(Window.innerWidth, Window.innerHeight)

        set_frustum(@camera.top - @camera.bottom)
    end

    def reload()
        unless @loading
            clear_objects

            load_objects
        end
    end

    def clear_objects()
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
    end

    def load_objects(&on_loaded)
        @loading = true

        Window.fetch("/stl/models/#{@model_path}").then do |response|
            response = Native(response)

            if response.ok
                response.json().then do |objects|
                    add_objects(objects)

                    on_loaded.call if on_loaded
                end.to_n
            else
                response.text().then do |error|
                    Window.alert(error)
                end.to_n
            end
        end.catch do |error|
            Window.alert(Native(error).message)
        end.finally do
            @loading = false
        end
    end

    def add_objects(objects)
        objects.each_with_index do |object, index|
            object = Native(object)

            geometry = Three::STLLoader.new().parseBase64(object['stl_base64'])

            material = Three::MeshStandardMaterial.new({
                color: object['color'] || MESH_COLOR
            })

            if object['opacity']
                material.transparent = true
                material.opacity = object['opacity']
            end

            mesh = Three::Mesh.new(geometry, material)

            lines = Three::LineSegments.new(
                Three::EdgesGeometry.new(geometry, 30),
                Three::LineBasicMaterial.new({
                    color: LINE_COLOR
                })
            )

            @scene.add(mesh)
            @scene.add(lines)

            @objects << {
                index: index,
                mesh: mesh,
                lines: lines
            }
        end
    end
end

Viewer.new.start
