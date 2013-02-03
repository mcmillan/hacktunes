# Express + deps
express = require('express')
http = require('http')
path = require('path')

# Passport
passport = require('passport')
passportFacebookStrategy = require('passport-facebook').Strategy

# NowJS
nowjs = require('now')

# Shred
shred = require('shred')
shred = new shred()

# Async
async = require('async')

# DB
mongoskin = require('mongoskin')
db = mongoskin.db('localhost/hack')

# Configure passport
passport.use(

  new passportFacebookStrategy

    clientID: process.env.APP_ID
    clientSecret: process.env.APP_SECRET
    callbackURL: '/auth',

    (access_token, refresh_token, profile, done) ->

      profile.access_token = access_token

      done null, profile

)

passport.serializeUser (user, done) ->

  done null, user

passport.deserializeUser (user, done) ->

  done null, user

app = express()

app.configure ->

  app.set 'port', process.env.PORT or 3000
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.locals.pretty = true

  app.use express.favicon()
  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser('gangnam style')
  app.use express.session()
  app.use passport.initialize()
  app.use passport.session()
  app.use require('connect-assets')(build: true)
  app.use app.router
  app.use express.static(path.join(__dirname, 'public'))
  app.use express.errorHandler()

app.get '/', (req, res) ->

  dz_channel = 'http://' + req.host + '/channel'
  now_url = 'http://' + req.host + ':' + (process.env.PORT or 3000) + '/nowjs/now.js'

  res.render 'index', user: (JSON.stringify req.user or false), logged_in: req.user?, dz_id: process.env.DZ_ID, dz_channel: dz_channel, now_url: now_url

app.get '/auth', passport.authenticate 'facebook', successRedirect: '/', failureRedirect: '/', scope: ['publish_actions', 'user_actions.music']

app.get '/channel', (req, res) ->

  res.send '<script src="http://cdn-files.deezer.com/js/min/dz.js"></script>'

server = http.createServer(app).listen app.get('port')

everyone = nowjs.initialize server

everyone.now.backfill_users = ->

  everyone.getUsers (clients) ->

    clients.forEach (id) ->

      nowjs.getClient id, ->

        unless @now.user.disabled?
          everyone.now.new_user @now.user

everyone.now.start = ->

  db.collection('songs').find().toArray (err, songs) ->

    added = []
    buffer = []

    while buffer.length < 5

      index = Math.floor Math.random() * songs.length

      if index of added
        continue

      buffer.push songs[index]
      added.push index


    everyone.now.receive buffer

everyone.now.win = (correct, time) ->

  everyone.now.won(@now.user, correct, time)

everyone.now.post_og = (url) ->

  shred.post

    url: 'https://graph.facebook.com/me/hacksongs:guess'
    content: 'access_token=' + @now.user.access_token + '&song=' + encodeURIComponent(url)
    on:
      response: (response) ->

        console.log response.content.body

everyone.now.get_songs = (callback) ->

  unless @now.user
    return

  @now.user.taste = []

  shred.get

    url: 'https://graph.facebook.com/me/music.listens?fields=data&limit=25&access_token=' + @now.user.access_token
    
    on:

      200: (response) =>

        music = JSON.parse(response.content.body).data
        queue = []

        music.forEach (item) =>

          queue.push (callback) =>

            shred.get(

              url: 'https://graph.facebook.com/' + item.data.song.id + '?access_token=' + @now.user.access_token

            ).on('response', (response) =>

              if response.isError
                return callback response.status

              song = JSON.parse response.content.body
              formatted =
                url: song.url
                title: song.title
                artist: song.data.musician[0].name
                image: song.image[0].url
                user: @now.user.displayName
                user_id: @now.user.id
                facebook_id: song.id

              if @now.user.taste.length < 3
                @now.user.taste.push formatted.artist

              db.collection('songs').findOne facebook_id: formatted.facebook_id, (err, result) ->

                if result
                  return callback err, result

                db.collection('songs').insert formatted, (err, result) ->

                  callback err, result

            )

        async.parallel queue, (err, results) =>

          if results.length >= 3

            everyone.now.new_user @now.user

          else

            @now.user.disabled = true

          callback results.length

nowjs.on('disconnect', ->

  if !@now.user
    return

  db.collection('songs').remove user_id: @now.user.id

  everyone.now.get_lost @now.user

)