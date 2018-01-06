###
Drag tasks handle (and other support)
###

{React, rclass, rtypes}  = require('../smc-react')

{Icon} = require('../r_misc')

exports.DoneCheckbox = rclass
    propTypes :
        actions   : rtypes.object
        done      : rtypes.bool
        read_only : rtypes.bool
        task_id   : rtypes.string

    shouldComponentUpdate: (next) ->
        return @props.done      != next.done      or \
               @props.task_id   != next.task_id   or \
               @props.read_only != next.read_only

    render_checkbox: ->
        if @props.done
            name = 'check-square-o'
        else
            name = 'square-o'
        return <Icon name={name} style={if not @props.read_only then {cursor:'pointer'}} />

    toggle_done: ->
        if @props.done
            @props.actions.set_task_not_done(@props.task_id)
        else
            @props.actions.set_task_done(@props.task_id)

    render: ->
        checkbox = @render_checkbox()
        <div onClick={if not @props.read_only then @toggle_done} style={fontSize:'17pt', color:'#666'}>
            {checkbox}
        </div>
