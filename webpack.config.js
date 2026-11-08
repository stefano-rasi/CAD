const path = require('path');

module.exports = {
    entry: './node/three.js',
    output: {
        filename: 'three.js',
        path: path.resolve(__dirname, 'static'),
    },
    mode: 'development',
    devtool: 'source-map',
};