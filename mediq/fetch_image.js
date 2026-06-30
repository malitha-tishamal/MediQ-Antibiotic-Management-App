const fs = require('fs');
const http = require('https');
const zlib = require('zlib');

const mmd = fs.readFileSync('diagram.mmd', 'utf8');
const state = { code: mmd, mermaid: { theme: 'default' } };
const json = JSON.stringify(state);
const data = Buffer.from(json, 'utf8');
const compressed = zlib.deflateSync(data, { level: 9 });
const encoded = compressed.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const url = `https://mermaid.ink/img/pako:${encoded}?type=jpeg`;

console.log("Fetching: " + url);

const file = fs.createWriteStream("uml_use_case_diagram.jpg");
http.get(url, function(response) {
  if (response.statusCode === 200) {
    response.pipe(file);
    file.on('finish', function() {
      file.close();
      console.log("Image downloaded successfully");
    });
  } else {
    console.log("Server responded with: " + response.statusCode);
  }
}).on('error', function(err) {
  console.log("Error: " + err.message);
});
