
# Tests for no-boilerplate-passport

This test module drives all the tests through multiple configurations.

## Required modules

	_ = require('lodash')
	nbPassport = require('../index')
	express = require('express')
	passport = require('passport')

## Common config objects for all tests

	baseConfig =
		baseURL: process.env.NO_BOILERPLATE_PASSPORT_TEST_BASE_URL
		providers: {}

	twitter =
		paths:
			start: 		'/no-boilerplate-passport/v1/auth/twitter/start'
			callback: 	'/no-boilerplate-passport/v1/auth/twitter/callback'
			success:	'/no-boilerplate-passport/v1/auth/twitter/success'
			failure:	'/no-boilerplate-passport/v1/auth/twitter/failure'
		config:
			consumerKey: 	process.env.NO_BOILERPLATE_PASSPORT_TEST_TWITTER_CONSUMER_KEY
			consumerSecret: process.env.NO_BOILERPLATE_PASSPORT_TEST_TWITTER_CONSUMER_SECRET
		handler:
			module:		'tests'
			function:	'<set by test>'

## Tests

	describe 'no-boilerplate-passport configures Passport', ->
		it 'with Twitter auth', ->
			app = express()
			app.use(passport.initialize())
			app.use(passport.session())
			config = _.clone baseConfig
			config.providers.twitter = twitter
			nbPassport(app, config)
