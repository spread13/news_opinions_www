
### Config ###

config =
  apiurl: 'http://localhost:3333'

### Globals ###

router = null
models = {}
tpls = {}

### Framework ###

class window.App
  constructor: ->
    models.me = new Me()
    models.feeds = new Feeds()
    models.articles = new Articles()
    models.mySpreads = new Spreads(null, url: 'users/null/opinions')
    router = new Router
    @_configure()

  run: ->
    Backbone.history.start()

  _configure: ->
    $.ajaxSetup
      dataType: 'json'
      cache: false
      statusCode:
        201: (res) ->
          sessionStorage.token = res.token.id
          sessionStorage.tokenExpires = res.token.expires
          router.navigate '/', trigger: true
        401: ->
          delete sessionStorage.token
          delete sessionStorage.tokenExpires
          router.navigate 'login', trigger: true
        500: ->
          alert(xhr.responseText)
      beforeSend: (xhr, ops) ->
        token = sessionStorage.token
        expires = sessionStorage.tokenExpires

        if token
          xhr.setRequestHeader 'Authorization', token

    Backbone.$.ajaxPrefilter (ops, origOps, xhr) ->
      ops.url = "#{config.apiurl}/#{ops.url}"
      false     # to avoid error

class Layout
  constructor: ->
    @el = $("#main")

  show: (view) ->  
    if @view
      @view.remove()
      @view = null
      @el.empty()

    if view
      @view = view
      @el.html view.el
      @view.render()


### Router ###

class Router extends Backbone.Router
  routes:
    '': 'index'
    'login': 'login'
    'signup': 'signup'
    'me': 'me'
    'newFeed': 'newFeed'
    'feeds': 'feeds'
    'articles': 'articles'
    'mySpreads': 'mySpreads'
    'spreads/:id': 'spreads'

  initialize: ->
    @layout = new Layout

  index: -> @articles()

  login: ->
    @layout.show new LoginView(model: models.me)
  
  signup: ->
    @layout.show new SignupView(model: models.me)

  me: ->
    self = @
    models.me.fetch
      success: ->
        self.layout.show new MeView(model: models.me)

  newFeed: ->
    @layout.show new FeedEditView
      model: new Feed(null, collection: models.feeds)

  feeds: ->
    models.feeds.fetch()
    @layout.show new FeedsView
      model: models.feeds

  articles: ->
    models.articles.fetch()
    @layout.show new ArticlesView
      model: models.articles

  mySpreads: ->
    models.mySpreads.fetch()
    @layout.show new SpreadsView
      model: models.mySpreads

  spreads: (user) ->
    model = new Spreads(null, url: "users/#{user}/opinions")
    model.fetch()
    @layout.show new SpreadsView
      model: model

#--- MODELS ---#

class Me extends Backbone.Model
  url: 'me'
  login: (data) ->
    Backbone.sync 'create', @,
      url: 'login'
      attrs: data

  signup: (data) ->
    Backbone.sync 'create', @,
      url: 'users'
      attrs: data
      success: router.navigate 'login', trigger: true

  logout: ->
    delete sessionStorage.token
    delete sessionStorage.tokenExpires
    window.location = '/'


#--- MODELS ---#

class Feed extends Backbone.Model

class Feeds extends Backbone.Collection
  url: 'sites'
  model: Feed

class Article extends Backbone.Model

class Articles extends Backbone.Collection
  url: 'articles'
  model: Article 

class Spread extends Backbone.Model

class Spreads extends Backbone.Collection
  model: Spread


#--- VIEWS ---#

class SpreadView extends Backbone.View
  className: 'article'

  events:
    'click .spread': 'spread'

  template: ->
    tpls.spread ||= _.template $('#tpl-spread').html()

  render: ->
    @$el.html @template()(@model.toJSON())

  spread: ->
    Backbone.ajax
      type: 'POST'
      contentType: 'application/json'
      url: "articles/#{@model.article_id}/opinions"
      data: {}
      success: -> router.articles()

class SpreadsView extends Backbone.View
  views: []

  template: ->
    tpls.spreads ||= _.template $('#tpl-spreads').html()

  initialize: ->
    @listenTo @model, 'sync', @render

  render: ->
    for v in @views
      v.remove()
    @views = []

    @$el.html @template()(@model.toJSON())

    container = @$el.find('#spreads')
    for m in @model.models
      v = new SpreadView(model: m)
      v.render()
      @views.push v
      container.append v.el


class ArticleView extends Backbone.View
  className: 'article'

  events:
    'click .spread': 'spread'

  template: ->
    tpls.article ||= _.template $('#tpl-article').html()

  render: ->
    @$el.html @template()(@model.toJSON())

  spread: ->
    Backbone.ajax
      type: 'POST'
      contentType: 'application/json'
      url: "articles/#{@model.id}/opinions"
      data: {}
      success: -> router.articles()

class ArticlesView extends Backbone.View
  views: []

  template: ->
    tpls.articles ||= _.template $('#tpl-articles').html()

  initialize: ->
    @listenTo @model, 'sync', @render
    self = @
    $('body').mousewheel (e, delta) ->
      if self.els?.scrolldiv
        self.els.scrolldiv[0].scrollLeft -= delta*30
        e.preventDefault()

  render: ->
    for v in @views
      v.remove()
    @views = []

    @$el.html @template()(@model.toJSON())

    container = @$el.find('#articles')
    for m,i in @model.models
      v = new ArticleView(model: m)
      v.render()
      @views.push v
      container.append v.el
    container.css('width', @model.models.length*320)
    @els = scrolldiv: @$el.find('.scrolldiv')


class FeedView extends Backbone.View
  template: ->
    tpls.feed ||= _.template $('#tpl-feed').html()

  render: ->
    @$el.html @template()(@model.toJSON())

class FeedsView extends Backbone.View
  views: []

  events:
    'click #twitter': 'twitter'

  template: ->
    tpls.feeds ||= _.template $('#tpl-feeds').html()

  initialize: ->
    @listenTo @model, 'sync', @render

  render: ->
    for v in @views
      v.remove()
    @views = []

    @$el.html @template()(@model.toJSON())

    container = @$el.find('#feeds')
    for m in @model.models
      v = new FeedView(model: m)
      v.render()
      @views.push v
      container.append v.el

  twitter: ->
    oauthWindow = window.open(
      "#{config.apiurl}/auth/twitter",
      'twitter',
      'location=0,status=0,width=800,height=400'
    )
    callback = ->
      if oauthWindow.closed
        window.clearInterval oauthInterval
    oauthInterval = window.setInterval callback, 1000


class FeedEditView extends Backbone.View
  events:
    'click #submit': 'submit'

  template: ->
    tpls.feedEdit ||= _.template $('#tpl-feed-edit').html()

  render: ->
    @$el.html @template()(@model.toJSON())

  submit: ->
    @model.save {
      title: $('#title').val()
      url: $('#url').val()
      rss: $('#rss').val()
    }, {
      success: -> router.navigate 'feeds', trigger: true
    }
      

class MeView extends Backbone.View
  events:
    'click #logout': 'logout'

  template: ->
    tpls.me ||= _.template $('#tpl-me').html()

  render: ->
    @$el.html @template()(@model.toJSON())

  logout: -> @model.logout()


class LoginView extends Backbone.View
  events:
    'click #login': 'login'

  template: ->
    tpls.login ||= _.template $('#tpl-login').html()

  render: ->
    @$el.html @template()

  login: ->
    @model.login
      email: $('#email').val()
      password: $('#password').val()


class SignupView extends Backbone.View
  events:
    'click #signup': 'signup'

  template: ->
    tpls.signup ||= _.template $('#tpl-signup').html()

  render: ->
    @$el.html @template()

  signup: ->
    @model.signup
      email: $('#email').val()
      password: $('#password').val()
      passwordConfirm: $('#passwordConfirm').val()

