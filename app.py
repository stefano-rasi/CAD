import os
import sys
import base64
import tempfile
import traceback

from flask import Flask, render_template

import yaml

import cadquery as cq

RUBY_PORT = sys.argv[1]
PYTHON_PORT = sys.argv[2]

app = Flask(__name__)

@app.route('/models/<path:path>')
def model(path):
    path = os.path.join('models', path)

    return render_template(
        'viewer.html',

        path=path,
        opal_port=RUBY_PORT
    )

@app.route('/stl/models/<path:path>')
def stl(path):
    try:
        objects = []

        def show_object(cq_object, color=None, opacity=None):
            if isinstance(cq_object, tuple):
                cq_objects = cq_object
            else:
                cq_objects = [ cq_object ]

            for cq_object in cq_objects:
                objects.append({
                    'color': color,
                    'opacity': opacity,
                    'cq_object': cq_object
                })

        path = os.path.join('models', path)

        with open(path, 'r') as file:
            script = file.read()

            exec(script, { 'cq': cq, 'show_object': show_object })

        for obj in objects:
            tmp = tempfile.NamedTemporaryFile(suffix='.stl', delete=False)

            obj['cq_object'].val().exportStl(tmp.name)

            with open(tmp.name, 'rb') as stl_file:
                stl_bytes = stl_file.read()

                stl_base64 = base64.b64encode(stl_bytes).decode('utf-8')

            obj['stl_base64'] = stl_base64

            del obj['cq_object']

        return objects
    except Exception as e:
        return traceback.format_exc(), 500

if __name__ == '__main__':
    app.run(port=PYTHON_PORT)