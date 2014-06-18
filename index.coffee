#!/usr/bin/env coffee

require 'colors'
fs = require 'fs'
path = require 'path'
async = require 'async'
semver = require 'semver'
program = require 'commander'
execSync = require 'execSync'


configFileName = 'updater.json'
smartFileName = 'smart.json'
packageFileName = 'package.js'

initialDir = process.cwd()

program
	.version('0.0.1')
	.option('-d, --directory [path]', 'Meteor packages parent directory', String, '.')
	.option('-u, --username <username>', 'Atmosphere Username')
	.option('-p, --password <password>', 'Atmosphere Password')
	.parse(process.argv);

if not program.username? or not program.password?
	return program.help()


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

	process.chdir initialDir
	process.chdir path.join dir, 'lib'

	#Download git data
	output = execSync.exec 'git fetch origin master'
	if output.code isnt 0 then return console.log output.stdout?.red

	#List all tags
	output = execSync.exec 'git show-ref --abbrev --tags -d'
	if output.code isnt 0 then return console.log output.stdout?.red

	tagsList = output.stdout.replace /\n$/, ''
	tagsList = tagsList.split('\n')
	tags = {}
	for tag in tagsList
		if tag.indexOf('^{}') > -1
			tag = tag.split(' ')
			tags[tag[0]] = tag[1].replace('refs/tags/', '').replace(/^v/, '').replace('^{}', '')

	#List all logs
	output = execSync.exec 'git log --pretty=format:"%h %s" --all'
	if output.code isnt 0 then return console.log output.stdout?.red
	gitLogs = output.stdout.replace /\n$/, ''
	gitLogs = gitLogs.split('\n')

	doProcess = ->
		#Get current position
		output = execSync.exec 'git rev-parse --short HEAD'
		if output.code isnt 0 then return console.log output.stdout?.red
		currentHash = output.stdout.replace /\n$/, ''

		#Find next position in log
		nextLog = undefined
		gitLogs.forEach (gitLog, index) ->
			if gitLog.indexOf(currentHash) > -1 and index > 0
				nextLog = gitLogs[index - 1]

		#Return if not found
		if not nextLog? then return console.log 'No changes'.green

		nextLog = nextLog.split(' ')
		nextHash = nextLog.shift()
		nextCommit = nextLog.join(' ').replace(/"/g, '\\"')

		console.log nextHash, nextCommit

		#Put lib in next position
		output = execSync.exec "git checkout #{nextHash}"
		if output.code isnt 0 then return console.log output.stdout?.red

		#Go back to package dir
		process.chdir '../'

		versionAppend = "+#{nextHash}"
		version = smart.version

		#Update package if need
		if tags[nextHash]?
			console.log "tag -> #{tags[nextHash]}".yellow
			version = tags[nextHash]
			versionAppend = ''
			if semver.gt(tags[nextHash], smart.version) is true
				smart.version = tags[nextHash]
				fs.writeFileSync smartFileName, JSON.stringify(smart, null, '  ')

		#Commit changes
		output = execSync.exec "git commit -a -m \"updated submodule to commit #{nextHash} (#{nextCommit})\""
		if output.code isnt 0 then return console.log output.stdout?.red

		#Tag changes
		output = execSync.exec "git tag -a v#{version}#{versionAppend} -m \"#{nextCommit}\""
		if output.code isnt 0 then return console.log output.stdout?.red

		output = execSync.exec "git push origin master --tags"
		if output.code isnt 0 then return console.log output.stdout?.red

		if tags[nextHash]? and tags[nextHash] is smart.version
			console.log "mrt publish -> #{tags[nextHash]}".yellow
			output = execSync.exec "mrt publish . --repoUsername #{program.username} --repoPassword #{program.password}"
			if output.code isnt 0 then console.log output.stdout?.red

		process.chdir 'lib'
		doProcess()

	doProcess()

###
git log --pretty=format:"%h||%d||%s" --all
###


files = fs.readdirSync program.directory

files.forEach (file) ->
	try
		stat = fs.statSync file
		if stat.isDirectory() is true
			processModule file
	catch e
		console.log e
