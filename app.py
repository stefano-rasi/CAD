import sys
import base64
import tempfile
import traceback

from pathlib import Path

import flask
import cadquery as cq

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5000

STL_TOLERANCE = 0.001
STL_ANGULAR_TOLERANCE = 0.1

app = flask.Flask(__name__)

app.config['TEMPLATES_AUTO_RELOAD'] = True

exported_stls = {}

def model_file(path):
    if '..' in Path(path).parts:
        flask.abort(404)

    return Path('models') / path

def flatten(cq_object):
    if isinstance(cq_object, (tuple, list)):
        for item in cq_object:
            yield from flatten(item)
    else:
        yield cq_object

def run_model(file):
    objects = []

    def show_object(cq_object, color=None, opacity=None):
        for item in flatten(cq_object):
            objects.append({
                'color': color,
                'opacity': opacity,
                'cq_object': item
            })

    code = compile(file.read_text(), str(file), 'exec')

    exec(code, {
        'cq': cq,
        '__name__': '__main__',
        '__file__': str(file.absolute()),
        'show_object': show_object
    })

    return objects

def to_stl(cq_object, directory):
    stl_file = Path(directory) / 'object.stl'

    cq.exporters.export(
        cq_object,
        str(stl_file),
        tolerance=STL_TOLERANCE,
        angularTolerance=STL_ANGULAR_TOLERANCE
    )

    return stl_file.read_bytes()

@app.route('/styles/<path:path>')
def styles(path):
    return flask.send_from_directory('styles', path)

@app.route('/models/<path:path>')
def viewer(path):
    return flask.render_template('viewer.html', path=path)

@app.route('/stl/models/<path:path>')
def stl(path):
    file = model_file(path)

    try:
        objects = run_model(file)

        with tempfile.TemporaryDirectory() as directory:
            stls = [to_stl(obj['cq_object'], directory) for obj in objects]
    except Exception:
        return traceback.format_exc(), 500

    exported_stls[path] = stls

    return [
        {
            'color': obj['color'],
            'opacity': obj['opacity'],
            'stl_base64': base64.b64encode(stl).decode('utf-8')
        }
        for obj, stl in zip(objects, stls)
    ]

@app.route('/export/<int:index>/models/<path:path>')
def export(index, path):
    stls = exported_stls.get(path)

    if stls is None or index >= len(stls):
        flask.abort(404)

    filename = f'{Path(path).stem}-{index + 1}.stl'

    return flask.Response(
        stls[index],
        headers={'Content-Disposition': f'attachment; filename="{filename}"'},
        mimetype='model/stl'
    )

if __name__ == '__main__':
    app.run(port=PORT)
