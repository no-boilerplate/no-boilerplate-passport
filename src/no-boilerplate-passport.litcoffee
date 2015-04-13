
# no-boilerplate Passport

A configuration package for [Passport](http://passportjs.org). It configures Passport based on the given configuration object, instantiating and registering different Passport strategies.

## Required modules

    _ = require('lodash')
    debug = require('debug')('no-boilerplate::passport')
    passport = require('passport')
    validate = require('jsonschema').validate
    format = require('string-format')

## Schemas

Root and provider schemas for easier validation of configuration data.

    rootSchema =
        type: 'object'
        properties:
            version:
                type: 'string'
            baseURL:
                type: 'string'
            commonPaths:
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
                required: []
                additionalProperties: false
            providers:
                type: 'object'
                # The properties of this object depend on the provider names
                additionalProperties: true
        required: ['version', 'baseURL', 'providers']
        additionalProperties: false

    providerSchema =
        type: 'object'
        properties:
            providerName:
                type: 'string'                    
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
                required: []
                additionalProperties: false
            callbackUrlProperty:
                type: 'string'
            config:
                # The properties of this object depend on the expectations
                # of the provider's strategy
                type: 'object'
            handler:
                type: ['object', 'string', 'function'] # This is a hack - JSON doesn't store functions but in this case we abuse implementation detail
                properties:
                    module:
                        type: 'string'
                    function:
                        type: 'string'
                required: []
                additionalProperties: false
        required: ['callbackUrlProperty', 'config', 'handler']
        additionalProperties: false

## Public functions

`init` function initializes Passport based on the given configuration.

    init = (app, config) ->

        validationErrors = validate(config, rootSchema)?.errors or [];
        if not _.isEmpty(validationErrors)
            throw new Error('Bad configuration object: ' + _.first(validationErrors))

        baseURL = config.baseURL
        debug 'Base URL for Passport configuration', baseURL
        _.each config.providers, (providerConfig, providerName) ->

            validationErrors = validate(providerConfig, providerSchema)?.errors or [];
            if not _.isEmpty(validationErrors)
                throw new Error('Bad configuration object for ' + providerName + ': ' + _.first(validationErrors))

            strategyName = 'no-boilerplate-' + providerName + '-auth-strategy'
            pathsProviderName = providerConfig.providerName or providerName

            paths = getProviderPaths config.commonPaths, providerConfig.paths, pathsProviderName
        
            configureProviderStrategy strategyName, baseURL, paths, providerName, providerConfig

            # Add GET endpoint that starts with authorization
            debug 'Setting up start endpoint on', paths.start
            app.get paths.start, (req, res, next) ->
                passport.authorize(strategyName)(req, res, next)

            # Add GET endpoint that ends authorization with provider's callback
            debug 'Setting up callback endpoint on', paths.callback
            app.get paths.callback, (req, res, next) ->
                options =
                    successRedirect: paths.success
                    failureRedirect: paths.failure
                handler = (err, user, info) ->
                    if err
                        debug('Failed to authorize:', err)
                        return res.redirect(options.failureRedirect)
                    res.redirect(options.successRedirect)
                passport.authorize(strategyName, options, handler)(req, res, next)

## Private functions

Each provider strategy object handles the callbacks in the exactly same way - by invoking the configured handler. Handler gets the collected data and the "done" callback which it must invoke once the processing has finished. This function configures the strategy with the given handler and prepares it for authentication callbacks.

    configureProviderStrategy = (strategyName, baseURL, paths, providerName, providerConfig) ->
        Strategy = require('passport-' + providerName).Strategy

        strategyOptions = _.clone providerConfig.config
        strategyOptions[providerConfig.callbackUrlProperty] = baseURL + paths.callback

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

We generate provider paths with configured constant strings or formats.

    getProviderPaths = (commonPaths, providerPaths, providerName) ->
        paths = {}
        _.each ['start', 'callback', 'success', 'failure'], (pathName) ->
            path = (providerPaths and providerPaths[pathName]) or commonPaths[pathName]
            if path
                path = format path, {
                    providerName: providerName
                }
            else
                throw new Error(format('Inexistent path {0} for provider {1}', path, providerName))
            paths[pathName] = path
        return paths

## Exporting of public functions

    module.exports = init
