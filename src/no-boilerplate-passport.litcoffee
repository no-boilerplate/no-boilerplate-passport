
# no-boilerplate Passport

A configuration package for [Passport](http://passportjs.org). It configures Passport based on the given configuration object, instantiating and registering different Passport strategies.

## Required modules

    _ = require('lodash')
    debug = require('debug')('no-boilerplate.passport')
    passport = require('passport')
    validate = require('jsonschema').validate
    format = require('string-format')
    deepExtend = require('deep-extend')

## Schemas

Root and provider schemas for easier validation of configuration data.

    PATHS_SCHEMA =
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

    COMPLETE_PATHS_SCHEMA =
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
        additionalProperties: false

    HANDLER_SCHEMA =
        handler:
            type: ['object', 'string', 'function'] # This is a hack - JSON doesn't store functions but in this case we abuse implementation detail
            properties:
                module:
                    type: 'string'
                function:
                    type: 'string'
            required: []
            additionalProperties: false

    ROOT_SCHEMA =
        type: 'object'
        properties:
            version:
                type: 'string'
            baseURL:
                type: 'string'
            common:
                type: 'object'
                properties:
                    paths: PATHS_SCHEMA
                    callbackURLProperty:
                        type: 'string'
                    handler: HANDLER_SCHEMA
                required: []
                additionalProperties: false
            providers:
                type: 'object'
                # The properties of this object depend on the provider names
                additionalProperties: true
        required: ['version', 'baseURL', 'providers']
        additionalProperties: false

    COMPLETE_PROVIDER_SCHEMA =
        type: 'object'
        properties:
            name:
                type: 'string'                    
            paths: COMPLETE_PATHS_SCHEMA
            callbackURLProperty:
                type: 'string'
            config:
                # The properties of this object depend on the expectations
                # of the provider's strategy
                type: 'object'
            handler: HANDLER_SCHEMA
            custom:
                type: 'object'
        required: ['paths', 'callbackURLProperty', 'config', 'handler']
        additionalProperties: false

## Public functions

`init` function initializes Passport based on the given configuration.

    init = (app, config) ->

Validate the given config object against the schema.

        validationErrors = validate(config, ROOT_SCHEMA)?.errors or [];
        if not _.isEmpty(validationErrors)
            throw new Error('Bad configuration object: ' + _.first(validationErrors))

        baseURL = config.baseURL
        commonConfig = config.common or {}
        debug 'Base URL for Passport configuration', baseURL

For each provider the common configuration is extended by its custom configuration and
any matching properties are overwritten. Then that complete configuration object is used to
configure the provider.

        _.each config.providers, (providerConfig, providerName) ->

            debug 'Configuring', providerName, 'strategy'

Get complete provider config object from the common configuration, provider specific configuration
and some other properties.

            completeProviderConfig = _.clone commonConfig
            deepExtend completeProviderConfig, providerConfig
            pathsProviderName = providerConfig.name or providerName
            paths = resolveProviderPaths completeProviderConfig.paths, pathsProviderName

Validate the complete provider config object.

            debug 'Complete configuration', completeProviderConfig

            validationErrors = validate(completeProviderConfig, COMPLETE_PROVIDER_SCHEMA)?.errors or [];
            if not _.isEmpty(validationErrors)
                throw new Error('Bad configuration object for ' + providerName + ': ' + _.first(validationErrors))

            strategyName = 'no-boilerplate-' + providerName + '-auth-strategy'

            configureProviderStrategy strategyName, baseURL, paths, providerName, completeProviderConfig

            # Add GET endpoint that starts with authorization
            debug 'Setting up start endpoint on', paths.start
            app.get paths.start, (req, res, next) ->
                debug 'Authorization start'
                passport.authorize(strategyName)(req, res, next)

            # Add GET endpoint that ends authorization with provider's callback
            debug 'Setting up callback endpoint on', paths.callback
            app.get paths.callback, (req, res, next) ->
                options =
                    successRedirect: paths.success
                    failureRedirect: paths.failure
                debug 'Authorization callback', paths.start
                handler = (err, user, info) ->
                    debug 'Authorization handler', err, user, info
                    if err
                        debug('Failed to authorize:', err)
                        return res.redirect(options.failureRedirect)
                    res.redirect(options.successRedirect)
                passport.authorize(strategyName, options, handler)(req, res, next)

## Private functions

Each provider strategy object handles the callbacks in the exactly same way - by invoking the configured handler. Handler gets the collected data and the "done" callback which it must invoke once the processing has finished. This function configures the strategy with the given handler and prepares it for authentication callbacks.

    configureProviderStrategy = (strategyName, baseURL, paths, providerName, providerConfig) ->
    
        # Load the strategy object per the provider name. We try `'passport_' + providerName` first
        # and if that fails than straight `providerName` as module name.
        Strategy = null;
        try
            Strategy = require('passport-' + providerName).Strategy
        catch error
            Strategy = require(providerName).Strategy
        
        strategyOptions = _.clone providerConfig.config
        strategyOptions[providerConfig.callbackURLProperty] = baseURL + paths.callback

        strategy = new Strategy(strategyOptions, (arg1, arg2, arg3, done) ->
            # We test if the handler is a function before testing if it's an object
            # because _.isObject returns true for functions.
            debug 'Strategy callback for', strategyName
            handlerFunction = null
            if _.isFunction providerConfig.handler
                debug 'Handler is a function'
                handlerFunction = providerConfig.handler
            else if _.isObject providerConfig.handler
                debug 'Handler is a module function'
                handlerModule = require(providerConfig.handler.module)
                handlerFunction = handlerModule.exports[providerConfig.handler.function]
            else if _.isString providerConfig.handler
                debug 'Handler is a string encoded function'
                handlerFunction = eval(providerConfig.handler)
            else
                throw new Error('Unsupported handler function type for provider ' + providerName)

            # We send to our own handler the data we got from the Passport.
            handlerFunction providerConfig, arg1, arg2, arg3, done
        )

        passport.use strategyName, strategy

We resolve provider paths with configured constant strings or formats.

    resolveProviderPaths = (paths, providerName) ->
        resolvedPaths = {}
        _.each ['start', 'callback', 'success', 'failure'], (pathName) ->
            path = paths[pathName]
            if path
                path = format path, {
                    name: providerName
                }
            else
                throw new Error(format('Path {0} not defined for provider {1}', path, providerName))
            resolvedPaths[pathName] = path
        return resolvedPaths

## Exporting of public functions

    module.exports = init
