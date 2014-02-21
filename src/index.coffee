
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

  initialize: ->
    @layout = new Layout

  index: -> @me()

  login: ->
    @layout.show new LoginView(model: models.me)
  
  signup: ->
    @layout.show new SignupView(model: models.me)

  me: ->
    self = @
    models.me.fetch
      success: ->
        self.layout.show new MeView(model: models.me)


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


#--- VIEWS ---#

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

