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


processModule = (dir) ->
	requiredFiles = [
		path.join dir, configFileName
		path.join dir, smartFileName
		path.join dir, packageFileName
	]

	verifyFile = (file, cb) ->
		fs.stat file, (err, data) ->
			if err?
				return cb "#{file} not found"
			console.log "✓ #{file}".green
			cb()

	async.forEach requiredFiles, verifyFile, (err, data) ->
		if err?
			console.log err.red
			return process.exit()


fs.readdir program.directory, (err, files) ->
	files.forEach (file) ->
		fs.stat file, (err, data) ->
			if data.isDirectory() is true
				processModule file
