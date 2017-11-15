"""


"""

PAGE_SIZE            = 100

os_path              = require('path')

{React}              = require('smc-webapp/smc-react')
express              = require('express')
misc                 = require('smc-util/misc')
{defaults, required} = misc

react_support        = require('./react')
{Landing}            = require('smc-webapp/share/landing')
{PublicPathsBrowser} = require('smc-webapp/share/public-paths-browser')
{Page}               = require('smc-webapp/share/page')
{get_public_paths}   = require('./public_paths')
{render_public_path, render_sub_public_path} = require('./render-public-path')

react = (res, component) ->
    react_support.react(res, <Page>{component}</Page>)

exports.share_router = (opts) ->
    opts = defaults opts,
        database : required
        path     : required
        logger   : undefined

    if opts.logger?
        dbg = (args...) ->
            opts.logger.debug("share_router: ", args...)
    else
        dbg = ->

    if opts.path.indexOf('[project_id]') == -1
        # VERY BAD
        throw RuntimeError("opts.path must contain '[project_id]'")

    path_to_files = (project_id) ->
        return opts.path.replace('[project_id]', project_id)

    _ready_queue = []
    public_paths = undefined
    dbg("getting_public_paths")
    get_public_paths opts.database, (err, x) ->
        if err
            # This is fatal and should be impossible...
            dbg("get_public_paths - ERROR", err)
        else
            public_paths = x
            dbg("got_public_paths - initialized")
            for cb in _ready_queue
                cb()
            _ready_queue = []

    ready = (cb) ->
        if public_paths?
            cb()
        else
            _ready_queue.push(cb)

    router = express.Router()

    router.get '/', (req, res) ->
        ready ->
            react res, <Landing public_paths = {public_paths.get()} />

    router.get '/paths', (req, res) ->
        ready ->
            react res, <PublicPathsBrowser
                page_number  = {parseInt(req.query.page ? 0)}
                page_size    = {PAGE_SIZE}
                public_paths = {public_paths.get()} />

    router.get '/raw/:id/:path', (req, res) ->
        ready ->
            info = public_paths.get(req.params.id)
            if not info?
                res.sendStatus(404)
            else
                dir = path_to_files(info.get('project_id'))
                res.sendFile(os_path.join(dir, req.params.path))

    router.get '/:id/:sub', (req, res) ->
        ready ->
            info = public_paths.get(req.params.id)
            if not info?
                res.sendStatus(404)
            else
                render_sub_public_path
                    res  : res
                    info : info
                    path : req.params.sub
                    dir  : path_to_files(info.get('project_id'))

    router.get '/:id', (req, res) ->
        ready ->
            info = public_paths.get(req.params.id)
            if not info?
                res.sendStatus(404)
            else
                render_public_path
                    res   : res
                    info  : info
                    dir   : path_to_files(info.get('project_id'))
                    react : react

    router.get '*', (req, res) ->
        res.send("unknown path='#{req.path}'")

    return router

