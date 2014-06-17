#!/usr/bin/env coffee

require 'colors'
fs = require 'fs'
path = require 'path'
async = require 'async'
program = require 'commander'
execSync = require 'execSync'


configFileName = 'updater.json'
smartFileName = 'smart.json'
packageFileName = 'package.js'

program
	.version('0.0.1')
	.option('-d, --directory [path]', 'Meteor packages parent directory', String, '.')
	.parse(process.argv);

if not program.directory?
	return program.help()

console.log program.directory


validateModule = (dir) ->
	requiredFiles = [
		path.join dir, configFileName
		path.join dir, smartFileName
		path.join dir, packageFileName
	]

	for file in requiredFiles
		try
			stat = fs.statSync file
			console.log "✓ #{file}".green
		catch e
			console.log "#{file} not found".red



processModule = (dir) ->
	if validateModule(dir) is false
		return

	smart = fs.readFileSync path.join dir, smartFileName
	smart = JSON.parse smart

	process.chdir path.join dir, 'lib'

	output = execSync.exec 'git fetch origin master'
	if output.code isnt 0 then return console.log output.stdout?.red

	output = execSync.exec 'git rev-parse --short HEAD'
	if output.code isnt 0 then return console.log output.stdout?.red
	currentHash = output.stdout.replace /\n$/, ''

	output = execSync.exec 'git show-ref --abbrev --tags -d'
	if output.code isnt 0 then return console.log output.stdout?.red

	tagsList = output.stdout.replace /\n$/, ''
	tagsList = tagsList.split('\n')
	tags = {}
	for tag in tagsList
		if tag.indexOf('^{}') > -1
			tag = tag.split(' ')
			tags[tag[0]] = tag[1].replace('refs/tags/', '').replace(/^v/, '').replace('^{}', '')

	output = execSync.exec 'git log --pretty=format:"%h %s" --all'
	if output.code isnt 0 then return console.log output.stdout?.red
	gitLogs = output.stdout.replace /\n$/, ''
	gitLogs = gitLogs.split('\n')

	nextLog = undefined
	gitLogs.forEach (gitLog, index) ->
		if gitLog.indexOf(currentHash) > -1 and index > 0
			nextLog = gitLogs[index - 1]

	if not nextLog? then return console.log 'No changes'.green

	nextLog = nextLog.split(' ')
	nextHash = nextLog.shift()
	nextCommit = nextLog.join(' ')

	console.log nextHash, nextCommit

	output = execSync.exec "git checkout #{nextHash}"
	if output.code isnt 0 then return console.log output.stdout?.red

	process.chdir '../'

	versionAppend = "+#{nextHash}"

	# console.log tags
	if tags[nextHash]?
		console.log "     #{tags[nextHash]}".yellow
		versionAppend = ''
		smart.version = tags[nextHash]
		fs.writeFileSync smartFileName, JSON.stringify(smart, null, '  ')

	output = execSync.exec "git commit -a -m \"updated submodule to commit #{nextHash} (#{nextCommit})\""
	if output.code isnt 0 then return console.log output.stdout?.red

	output = execSync.exec "git tag -a v#{smart.version}#{versionAppend} -m \"#{nextCommit}\""
	if output.code isnt 0 then return console.log output.stdout?.red

	# output = execSync.exec "git push origin master --tags"
	# if output.code isnt 0 then return console.log output.stdout?.red

	# if tags[nextHash]?
	# 	output = execSync.exec "mrt publish"
	# 	if output.code isnt 0 then return console.log output.stdout?.red

	process.chdir '../'
	processModule dir

###
 cd lib
 #git rev-parse --short HEAD
 git fetch origin master
 #git log --oneline

array = git log --oneline HEAD..origin/master
nextCommit = array.pop

git checkout 38d5c9f
git commit -a -m "updated submodule to commit 38d5c9f"
git submodule status
git submodule update
cd lib
cd ..
git -a tag 0.0.0+38d5c9f -m ""
git push origin master --tags
###





files = fs.readdirSync program.directory

files.forEach (file) ->
	try
		stat = fs.statSync file
		if stat.isDirectory() is true
			processModule file
	catch e
		console.log e
