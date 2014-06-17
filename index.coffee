#!/usr/bin/env coffee

require 'colors'
fs = require 'fs'
path = require 'path'
async = require 'async'
program = require 'commander'


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





files = fs.readdirSync program.directory

files.forEach (file) ->
	try
		stat = fs.statSync file
		if stat.isDirectory() is true
			processModule file
	catch e
		console.log e
