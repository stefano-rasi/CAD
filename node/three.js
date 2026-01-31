import * as THREE from 'three';

import { STLLoader } from "three/examples/jsm/loaders/STLLoader.js";
import { STLExporter } from "three/examples/jsm/exporters/STLExporter.js";

import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";

window.THREE = THREE;

window.STLLoader = STLLoader;
window.STLExporter = STLExporter;

STLLoader.prototype.parseBase64 = function(base64String) {
    let binaryString = atob(base64String);

    let uint8Array = Uint8Array.from(binaryString, c => c.charCodeAt(0));

    return new STLLoader().parse(uint8Array.buffer);
};

window.OrbitControls = OrbitControls;