const fs = require('fs')
const os = require('os')
const { exec } = require('child_process')
const path = process.argv[2];

if (typeof(path) === 'undefined') {
	console.log('Missing path')
	process.exit(0)
}

fs.readFile(path, 'utf8', (err, data) => {
	if (err) throw err

	data = data.replace(/<animation/, '<temp')
	data = replaceLast("</animation>", "</temp>", data)

	data = data.replace(/<animation(.*?)>/g, '')
	data = data.replace(/<\/animation(.*?)>/g, '')

	data = data.replace(/<temp/g, '<animation')
	data = data.replace(/<\/temp>/g, '</animation>')

	fs.rename(path, path + '-o', (err) => {
		if (err) throw err

		fs.writeFile(path, data, () => {
			console.log('Done!')
			exec('open ' + path)
			process.exit(1)
		})
	})
});

function replaceLast(find, replace, string) {
    var lastIndex = string.lastIndexOf(find);
    
    if (lastIndex === -1) {
        return string;
    }
    
    var beginString = string.substring(0, lastIndex);
    var endString = string.substring(lastIndex + find.length);
    
    return beginString + replace + endString;
}