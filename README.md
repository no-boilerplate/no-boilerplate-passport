# NoBoilerplate Passport

No boilerplate configuration for [Passport](http://passportjs.org) for [Node.js](http://nodejs.org)

## Goal

Passport is authentication middleware for Node.js with support for many different authentication providers. It is extensible through its Strategy feature and is is very easy to setup and use. However, when you have to support more than just one provider it easily leads to a lot of boilerplate code with some minor variations in:

	1.	Paths for starting authorization and for OAuth2 provider callbacks.
	2.	Authorization handler functions for each separate provider.

Such boilerplate isn't required by Passport but everyone will solve it in a different manner if at all. NoBoilerplate Passport offers a no-boilerplate solution to this.

## Example

Say we wanted to add Twitter authorization to our server. With NoBoilerplate Passport we would start like this:

```js
nbPassport = require('no-boilerplate-passport');
nbPassport(app, {
	version: '1.0.0',
	baseURL: 'https://your-domain.com'
	providers: {
		twitter: {
			paths: {
				start: 		'/auth/twitter',
				callback: 	'/auth/twitter/callback'
				success:	'/account',
				failure:	'/
			},
			callbackURLProperty: 'callbackURL',
			config: {
				consumerKey: 	'your Twitter consumer key',
				consumerSecret: 'your Twitter consumer secret'
			},
			handler: function(token, tokenSecret, profile, done) {
				//	`profile` object contains both properties of the provider
				//	like its name and of user. For more information on it
				//	visit http://passportjs.org/guide/profile/

				//	Insert/update user-provider data in the database.
				//	If this fails send error object to done function.
				done();
			}
		}
	}
});
```

We would of course have to make sure that both `passport` and `passport-twitter` are included in our `package.json` but otherwise this configures your Express `app` object to:

	1.	Accept GET requests to `/auth/twitter` (as `providerName` is `twitter`) to start authorization process on Twitter. This in turn will redirect the user's browser to Twitter and inform it of the client ID and callback URL (passed to Passport through `callbackURLProperty` and automatically set to `https://your-domain.com/auth/twitter/callback`)
	2.	Accept GET callback requests to `/auth/twitter/callback` that end authorization process by Twitter.
	3.	Invoke your handler function if authorization was successful.
	4.	Redirect authorization successes to `/account` path and authorization failures to `/` path.

If we later wanted to add a new authorization provider, say Dropbox which can be done through `passport-dropbox-oauth2` strategy package, we would *only* add the following to `providers` part of the configuration object:

```js
	'dropbox-oauth2': {
		paths: {
			start: 		'/auth/dropbox',
			callback: 	'/auth/dropbox/callback'
			success:	'/account',
			failure:	'/
		},
		callbackURLProperty: 'callbackURL',
		config: {
			clientID:		'your Dropbox client ID',
			clientSecret: 	'your Dropbox client secret'
		},
		handler: function(config, token, tokenSecret, profile, done) {
			//	Insert/update user-provider data in the database.
			//	If this fails send error object to done function.

			done();
		}
	}
```

Now your `app` accepts requests to `/auth/dropbox` and `/auth/dropbox/callback` paths and can correctly request authorization on Dropbox. Unfortunately this is starting to look like boilerplate only now in configuration objects vs. code itself. We can observe the following commonalities in our example:

	* `success` and `failure` paths are exactly the same
	* `start` and `callback` paths look the same but for replacing `/twitter` with `/dropbox`
	* `callbackURLProperty` values are exactly the same
	* `handler` might not be the same but probably should be

To solve these issues NoBoilerplate Passport provides a configuration for common properties between providers. Thus instead of defining all these properties time and again they can be provided once and then user for each provider. And if the provider needs to override any of the properties - that's easy as well.

```js
	common: {
		callbackURLProperty: 'callbackURL',
		paths: {
			start: 		'/auth/{providerName}',
			callback: 	'/auth/{providerName}/callback'
			success:	'/account',
			failure:	'/
		},
		handler: function(config, token, tokenSecret, profile, done) {
			//	Create user-provider model based on the config and other arguments.
			//	Insert/update model in the database.
			//	If this fails send error object to done function.
			done();
		}
	}
```

Now our `providers` section looks like this:

```js
	providers: {
		twitter: {
			config: {
				consumerKey: 	'your Twitter consumer key',
				consumerSecret:	'your Twitter consumer secret'
			}
		},
		'dropbox-oauth2': {
			config: {
				clientID:		'your Dropbox client ID',
				clientSecret: 	'your Dropbox client secret'
			}
		}
	}
```

The only problem is that we now changed `/auth/dropbox` and `/auth/dropbox/callback` to `/auth/dropbox-oauth2` and `/auth/dropbox-oauth2/callback`. That at the same time manages to look bad *and* exposes an implementation detail. To fix it we can override the paths (as well as other common properties though we don't need to do that here):

```js
		'dropbox-oauth2': {
			paths: {
				start: 		'/auth/dropbox',
				callback: 	'/auth/dropbox/callback'
			},
			config: {
				clientID:		'your Dropbox client ID',
				clientSecret: 	'your Dropbox client secret'
			}
		}
```

That's nicer but now again we are repeating ourselves with `/auth` prefix and `/callback` suffix. Let's fix that:


```js
	'dropbox-oauth2': {
		providerName: 'dropbox',
		config: {
			clientID:		'your Dropbox client ID',
			clientSecret: 	'your Dropbox client secret'
		}
	}
```

Now NoBoilerplate Passport knows to `dropbox` name when creating authorization so our paths are again `/auth/dropbox` and `/auth/dropbox/callback` but we aren't repeating ourselves.

Later on we want to add access to Facebook but there we want to define `scope` and other authorization parameters:

```js
	facebook: {
		config: {
			clientID:		'your Facebook app ID',
			clientSecret: 	'your Facebook app secret',
			enableProof:	false,
			profileFields: ['id', 'displayName', 'photos']
		},
		options: {
			scope: ['user_status', 'user_checkins']
		}
	}
```

NoBoilerplate Passport knows that it needs to use `options` to adapt the behavior of the strategy so it does so. At the same time it also knows, from the rest of the configuration, that it may need to extend `options` object with other properties while *also* respecting any overrides.

Further down the line you decide that you want to provider authorization specific to your site so you decide to use Passport's `LocalStrategy`. However, that strategy doesn't produce token and tokenSecret or token and refresh token but instead may produce username and password so `handler` needs to be overriden:

```js
	local: {
		config: {
			usernameField: 	'email',
			passwordField:	'password',
			passReqToCallback : true
		},
		handler: function(req, email, password, done) {
			//	Insert/update user-provider data in the database.
			//	If this fails send error object to done function.
			done();
		}
	}
```

At the same time you realize that your common handler function is pretty ugly as it switches on the config's provider name. Now you want to associate a custom function to your configuration objects so that the common handler can use it. For that we use `custom` property which is ignored by NoBoilerplate Passport and is sent together with the configuration object:

```js
	common: {
		handler: function(config, token, tokenSecret, profile, done) {
			var model = config.custom.createModel(config, token, tokenSecret, profile);
			//	Insert/update model in the database.
			//	If this fails send error object to done function.
			done();
		}
	},
	...
	twitter: {
		config: {
			consumerKey: 	'your Twitter consumer key',
			consumerSecret:	'your Twitter consumer secret'
		},
		custom: {
			createModel: function(config, token, tokenSecret, profile) {
				//	Create the model corresponding to Twitter auth.
			}
		}
	},
	'dropbox-oauth2': {
		providerName: 'dropbox',
		config: {
			clientID:		'your Dropbox client ID',
			clientSecret: 	'your Dropbox client secret'
		},
		custom: {
			createModel: function(config, token, tokenSecret, profile) {
				//	Create the model corresponding to Dropbox auth.
			}
		}
	},
```

And so on. Here's the final state of our example:

```js
nbPassport = require('no-boilerplate-passport');
nbPassport(app, {
	version: '1.0.0',
	baseURL: 'https://your-domain.com'
	common: {
		callbackURLProperty: 'callbackURL',
		paths: {
			start: 		'/auth/{providerName}',
			callback: 	'/auth/{providerName}/callback'
			success:	'/account',
			failure:	'/
		},
		handler: function(config, token, tokenSecret, profile, done) {
			var model = config.custom.createModel(config, token, tokenSecret, profile);
			//	Insert/update model in the database.
			//	If this fails send error object to done function.
			done();
		}
	},
	providers: {
		twitter: {
			config: {
				consumerKey: 	'your Twitter consumer key',
				consumerSecret:	'your Twitter consumer secret'
			},
			custom: {
				createModel: function(config, token, tokenSecret, profile) {
					//	Create the model corresponding to Twitter auth.
				}
			}
		},
		'dropbox-oauth2': {
			providerName: 'dropbox',
			config: {
				clientID:		'your Dropbox client ID',
				clientSecret: 	'your Dropbox client secret'
			},
			custom: {
				createModel: function(config, token, tokenSecret, profile) {
					//	Create the model corresponding to Dropbox auth.
				}
			}
		},
		facebook: {
			config: {
				clientID:		'your Facebook app ID',
				clientSecret: 	'your Facebook app secret',
				enableProof:	false,
				profileFields: ['id', 'displayName', 'photos']
			},
			options: {
				scope: ['user_status', 'user_checkins']
			}
		},
		local: {
			config: {
				usernameField: 	'email',
				passwordField:	'password',
				passReqToCallback : true
			},
			handler: function(req, email, password, done) {
				//	Insert/update user-provider data in the database.
				//	If this fails send error object to done function.
				done();
			}
		}
	}
});
```
