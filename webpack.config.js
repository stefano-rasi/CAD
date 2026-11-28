const path = require('path');

module.exports = {
    mode: 'development',
    entry: './node/three.js',
    output: {
        filename: 'three.js',
        path: path.resolve(__dirname, 'static'),
    },
    devtool: 'source-map'
};