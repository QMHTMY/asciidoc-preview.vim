const asciidoctor = require('asciidoctor')() 
var fs = require('fs')
var data = fs.readFileSync('sample.adoc','utf-8');
const html = asciidoctor.convert(data)
console.log(html)
