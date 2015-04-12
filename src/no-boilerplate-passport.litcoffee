
# no-boilerplate Passport

A configuration package for [Passport](http://passportjs.org). It configures Passport based on the given configuration object, instantiating and registering different Passport strategies.

## Required modules

    _ = require('lodash')
    debug = require('debug')('no-boilerplate::passport')
    passport = require('passport')
    validate = require('jsonschema').validate

## Schemas

Root and provider schemas for easier validation of configuration data.

    rootSchema =
        type: 'object'
        properties:
            baseURL:
                type: 'string'
            providers:
                type: 'object'
                # The properties of this object depend on the provider names
                additionalProperties: true
        required: ['baseURL', 'providers']

    providerSchema =
        type: 'object'
        properties:
            paths:
                type: 'object'
                properties:
                    start:
                        type: 'string'
                    callback:
                        type: 'string'
                    success:
                        type: 'string'
                    failure:
                        type: 'string'
                required: ['start', 'callback', 'success', 'failure']
            config:
                # The properties of this object depend on the expectations
                # of the provider's strategy
                type: 'object'
            handler:
                type: 'object'
                properties:
                    module:
                        type: 'string'
                    function:
                        type: 'string'
        additionalProperties: false

## Public functions

`init` function initializes Passport based on the given configuration.

    init = (app, config) ->

        if not validate(config, rootSchema)
            throw new Error('Bad configuration object')

        baseURL = config.baseURL
        debug 'Base URL for Passport configuration', baseURL
        _.each config.providers, (providerConfig, providerName) ->

            if not validate(providerConfig, providerSchema)
                throw new Error('Bad configuration object for provider ' + providerName)

            strategyName = 'no-boilerplate-' + providerName + '-auth-strategy'

            configureProviderStrategy strategyName, baseURL, providerName, providerConfig
            
            # Add GET endpoint that starts with authorization
            debug 'Setting up start endpoint on', providerConfig.paths.start
            app.get providerConfig.paths.start, (req, res, next) ->
                passport.authorize(strategyName)(req, res, next)

            # Add GET endpoint that ends authorization with provider's callback
            debug 'Setting up callback endpoint on', providerConfig.paths.callback
            app.get providerConfig.paths.callback, (req, res, next) ->
                options =
                    successRedirect: providerConfig.paths.success
                    failureRedirect: providerConfig.paths.failure
                handler = (err, user, info) ->
                    if err
                        debug('Failed to authorize:', err)
                        return res.redirect(options.failureRedirect)
                    res.redirect(options.successRedirect)
                passport.authorize(strategyName, options, handler)(req, res, next)

## Private functions

    configureProviderStrategy = (strategyName, baseURL, providerName, providerConfig) ->
        Strategy = require('passport-' + providerName).Strategy

        strategyOptions = providerConfig.config
        strategyOptions.callbackURL = baseURL + providerConfig.paths.callback

Each provider strategy object handles the callbacks in the exactly same way - by invoking the configured handler. Handler gets the collected data and the "done" callback which it must invoke once the processing has finished.

        strategy = new Strategy(strategyOptions, (token, tokenSecret, profile, done) ->
            # We test if the handler is a function before testing if it's an object
            # because _.isObject returns true for functions.
            if _.isFunction providerConfig.handler
                handlerFunction = providerConfig.handler
            else if _.isObject providerConfig.handler
                handlerModule = require(providerConfig.handler.module)
                handlerFunction = handlerModule.exports[providerConfig.handler.function]
            else if _.isString providerConfig.handler
                handlerFunction = eval(providerConfig.handler)
            else
                throw new Error('Unsupported handler function type for provider ' + providerName)

            # We send to our own handler the data we got from the Passport.
            handlerFunction token, tokenSecret, profile, done
        )

        passport.use strategyName, strategy

## Exporting of public functions

    module.exports = init
