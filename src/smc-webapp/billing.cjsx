##############################################################################
#
#    CoCalc: Collaborative Calculation in the Cloud
#
#    Copyright (C) 2016, Sagemath Inc.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################


$             = window.$
async         = require('async')
misc          = require('smc-util/misc')
_             = require('underscore')

{redux, rclass, React, ReactDOM, rtypes, Actions, Store}  = require('./app-framework')

# The billing actions and store:
require('./billing/actions')
{STATES, COUNTRIES} = require('./billing/data')
{ FAQ} = require("./billing/faq")
{AddPaymentMethod} = require('./billing/add-payment-method')
{PaymentMethod} = require('./billing/payment-method')
{powered_by_stripe} = require("./billing/util")

{Button, ButtonToolbar, FormControl, FormGroup, Row, Col, Accordion, Panel, Well, Alert, ButtonGroup, InputGroup} = require('react-bootstrap')
{ActivityDisplay, CloseX, ErrorDisplay, Icon, Loading, SelectorInput, r_join, SkinnyError, Space, TimeAgo, Tip, Footer} = require('./r_misc')
{HelpEmailLink, SiteName, PolicyPricingPageUrl, PolicyPrivacyPageUrl, PolicyCopyrightPageUrl} = require('./customize')

{PROJECT_UPGRADES} = require('smc-util/schema')

STUDENT_COURSE_PRICE = require('smc-util/upgrade-spec').upgrades.subscription.student_course.price.month4

PaymentMethods = rclass
    displayName : 'PaymentMethods'

    propTypes :
        redux   : rtypes.object.isRequired
        sources : rtypes.object # could be undefined, if it is a customer and all sources are removed
        default : rtypes.string

    getInitialState: ->
        state : 'view'   #  'delete' <--> 'view' <--> 'add_new'
        error : ''

    add_payment_method: ->
        @setState(state:'add_new')

    render_add_payment_method: ->
        if @state.state == 'add_new'
            <AddPaymentMethod redux={@props.redux} on_close={=>@setState(state:'view')} />

    render_add_payment_method_button: ->
        <Button disabled={@state.state != 'view'} onClick={@add_payment_method} bsStyle='primary' className='pull-right'>
            <Icon name='plus-circle' /> Add Payment Method...
        </Button>

    render_header: ->
        <Row>
            <Col sm={6}>
                <Icon name='credit-card' /> Payment methods
            </Col>
            <Col sm={6}>
                {@render_add_payment_method_button()}
            </Col>
        </Row>

    set_as_default: (id) ->
        @props.redux.getActions('billing').set_as_default_payment_method(id)

    delete_method: (id) ->
        @props.redux.getActions('billing').delete_payment_method(id)

    render_payment_method: (source) ->
        <PaymentMethod
            key            = {source.id}
            source         = {source}
            default        = {source.id==@props.default}
            set_as_default = {=>@set_as_default(source.id)}
            delete_method  = {=>@delete_method(source.id)}
        />

    render_payment_methods: ->
        # this happens, when it is a customer but all credit cards are deleted!
        return null if not @props.sources?
        # Always sort sources in the same order.  This way when you select
        # a default source, they don't get reordered, which is really confusing.
        @props.sources.data.sort((a,b) -> misc.cmp(a.id,b.id))
        for source in @props.sources.data
            @render_payment_method(source)

    render_error: ->
        if @state.error
            <ErrorDisplay error={@state.error} onClose={=>@setState(error:'')} />

    render: ->
        <Panel header={@render_header()}>
            {@render_error()}
            {@render_add_payment_method() if @state.state in ['add_new']}
            {@render_payment_methods()}
        </Panel>

exports.PaymentMethods = PaymentMethods

exports.ProjectQuotaBoundsTable = ProjectQuotaBoundsTable = rclass
    render_project_quota: (name, value) ->
        data = PROJECT_UPGRADES.params[name]
        amount = value * data.pricing_factor
        unit = data.pricing_unit
        if unit == "day" and amount < 2
            amount = 24 * amount
            unit = "hour"
        <div key={name} style={marginBottom:'5px', marginLeft:'10px'}>
            <Tip title={data.display} tip={data.desc}>
                <span style={fontWeight:'bold',color:'#666'}>
                    {misc.round1(amount)} {misc.plural(amount, unit)}
                </span><Space/>
                <span style={color:'#999'}>
                    {data.display}
                </span>
            </Tip>
        </div>

    render: ->
        max = PROJECT_UPGRADES.max_per_project
        <Panel
            header = {<span>Maximum possible quotas <strong>per project</strong></span>}
        >
            {@render_project_quota(name, max[name]) for name in PROJECT_UPGRADES.field_order when max[name]}
        </Panel>

exports.ProjectQuotaFreeTable = ProjectQuotaFreeTable = rclass
    render_project_quota: (name, value) ->
        # SMELL: is this a code dup from above?
        data = PROJECT_UPGRADES.params[name]
        amount = value * data.pricing_factor
        unit = data.pricing_unit
        if unit == "day" and amount < 2
            amount = 24 * amount
            unit = "hour"
        <div key={name} style={marginBottom:'5px', marginLeft:'10px'}>
            <Tip title={data.display} tip={data.desc}>
                <span style={fontWeight:'bold',color:'#666'}>
                    {misc.round1(amount)} {misc.plural(amount, unit)}
                </span> <Space/>
                <span style={color:'#999'}>
                    {data.display}
                </span>
            </Tip>
        </div>

    render_header: ->
        <div style={paddingLeft:"10px"}>
            <Icon name='battery-empty' />{' '}
            <span style={fontWeight:'bold'}>Free plan</span>
        </div>

    render: ->
        free = require('smc-util/schema').DEFAULT_QUOTAS
        <Panel
            header  = {@render_header()}
            bsStyle = 'info'
        >
            <Space/>
            <div style={marginBottom:'5px', marginLeft:'10px'}>
                <Tip title="Free servers" tip="Many free projects are cramped together inside weaker compute machines, competing for CPU, RAM and I/O.">
                    <span style={fontWeight:'bold',color:'#666'}>low-grade</span><Space/>
                    <span style={color:'#999'}>Server hosting</span>
                </Tip>
            </div>
            <div style={marginBottom:'5px', marginLeft:'10px'}>
                <Tip title="Internet access" tip="Despite working inside a web-browser, free projects are not allowed to directly access the internet due to security/abuse reasons.">
                    <span style={fontWeight:'bold',color:'#666'}>no</span><Space/>
                    <span style={color:'#999'}>Internet access</span>
                </Tip>
            </div>
            {@render_project_quota(name, free[name]) for name in PROJECT_UPGRADES.field_order when free[name]}
            <Space/>
            <div style={textAlign : 'center', marginTop:'10px'}>
                <h3 style={textAlign:'left'}>
                    <span style={fontSize:'16px', verticalAlign:'super'}>$</span><Space/>
                    <span style={fontSize:'30px'}>0</span>
                </h3>
            </div>
        </Panel>

PlanInfo = rclass
    displayName : 'PlanInfo'

    propTypes :
        plan     : rtypes.string.isRequired
        period   : rtypes.string.isRequired  # 'week', 'month', 'year', or 'month year'
        selected : rtypes.bool
        on_click : rtypes.func

    getDefaultProps: ->
        selected : false

    render_plan_info_line: (name, value, data) ->
        <div key={name} style={marginBottom:'5px', marginLeft:'10px'}>
            <Tip title={data.display} tip={data.desc}>
                <span style={fontWeight:'bold',color:'#444'}>
                    {value * data.pricing_factor} {misc.plural(value * data.pricing_factor, data.pricing_unit)}
                </span>
                <Space/>
                <span style={color:'#666'}>
                    {data.display}
                </span>
            </Tip>
        </div>

    render_cost: (price, period) ->
        period = PROJECT_UPGRADES.period_names[period] ? period
        <span key={period} style={whiteSpace:'nowrap'}>
            <span style={fontSize:'16px', verticalAlign:'super'}>$</span><Space/>
            <span style={fontSize:'30px'}>{price}</span>
            <span style={fontSize:'14px'}> / {period}</span>
        </span>

    render_price: (prices, periods) ->
        if @props.on_click?
            # note: in non-static, there is always just *one* price (several only on "static" pages)
            for i in [0...prices.length]
                <Button key={i} bsStyle={if @props.selected then 'primary'}>
                    {@render_cost(prices[i], periods[i])}
                </Button>
        else
            <h3 style={textAlign:'left'}>
                {r_join((@render_cost(prices[i], periods[i]) for i in [0...prices.length]), <br/>)}
            </h3>

    render_plan_name: (plan_data) ->
        if plan_data.desc?
            name = plan_data.desc
            if name.indexOf('\n') != -1
                v = name.split('\n')
                name = <span>{v[0].trim()}<br/>{v[1].trim()}</span>
        else
            name = misc.capitalize(@props.plan).replace(/_/g,' ') + ' plan'
        <div style={paddingLeft:"10px"}>
            <Icon name={plan_data.icon} /> <span style={fontWeight:'bold'}>{name}</span>
        </div>

    render: ->
        plan_data = PROJECT_UPGRADES.subscription[@props.plan]
        if not plan_data?
            return <div>Unknown plan type: {@props.plan}</div>

        params   = PROJECT_UPGRADES.params
        periods  = misc.split(@props.period)
        prices   = (plan_data.price[period] for period in periods)
        benefits = plan_data.benefits

        style =
            cursor : if @props.on_click? then 'pointer'

        <Panel
            style     = {style}
            header    = {@render_plan_name(plan_data)}
            bsStyle   = {if @props.selected then 'primary' else 'info'}
            onClick   = {=>@props.on_click?()}
        >
            <Space/>
            {@render_plan_info_line(name, benefits[name] ? 0, params[name]) for name in PROJECT_UPGRADES.field_order when benefits[name]}
            <Space/>

            <div style={textAlign : 'center', marginTop:'10px'}>
                {@render_price(prices, periods)}
            </div>

        </Panel>

AddSubscription = rclass
    displayName : 'AddSubscription'

    propTypes :
        on_close        : rtypes.func.isRequired
        selected_plan   : rtypes.string
        actions         : rtypes.object.isRequired
        applied_coupons : rtypes.immutable.Map
        coupon_error    : rtypes.string

    getDefaultProps: ->
        selected_plan : ''

    getInitialState: ->
        selected_button : 'month'

    is_recurring: ->
        not PROJECT_UPGRADES.subscription[@props.selected_plan.split('-')[0]].cancel_at_period_end

    submit_create_subscription: ->
        plan = @props.selected_plan
        @props.actions.create_subscription(plan)

    set_button_and_deselect_plans: (button) ->
        if @state.selected_button isnt button
            set_selected_plan('')
            @setState(selected_button : button)

    render_period_selection_buttons: ->
        <div>
            <ButtonGroup bsSize='large' style={marginBottom:'20px', display:'flex'}>
                <Button
                    bsStyle = {if @state.selected_button is 'month' then 'primary'}
                    onClick = {=>@set_button_and_deselect_plans('month')}
                >
                    Monthly Subscriptions
                </Button>
                <Button
                    bsStyle = {if @state.selected_button is 'year' then 'primary'}
                    onClick = {=>@set_button_and_deselect_plans('year')}
                >
                    Yearly Subscriptions
                </Button>
                <Button
                    bsStyle = {if @state.selected_button is 'week' then 'primary'}
                    onClick = {=>@set_button_and_deselect_plans('week')}
                >
                    1-Week Workshops
                </Button>
                <Button
                    bsStyle = {if @state.selected_button is 'month4' then 'primary'}
                    onClick = {=>@set_button_and_deselect_plans('month4')}
                >
                    4-Month Courses
                </Button>
                <Button
                    bsStyle = {if @state.selected_button is 'year1' then 'primary'}
                    onClick = {=>@set_button_and_deselect_plans('year1')}
                >
                    Yearly Courses
                </Button>
            </ButtonGroup>
        </div>

    render_renewal_info: ->
        if @props.selected_plan
            renews = not PROJECT_UPGRADES.subscription[@props.selected_plan.split('-')[0]].cancel_at_period_end
            length = PROJECT_UPGRADES.period_names[@state.selected_button]
            <p style={marginBottom:'1ex', marginTop:'1ex'}>
                {<span>This subscription will <b>automatically renew</b> every {length}.  You can cancel automatic renewal at any time.</span> if renews}
                {<span>You will be <b>charged only once</b> for the course package, which lasts {if length == 'year' then 'a '}{length}.  It does <b>not automatically renew</b>.</span> if not renews}
            </p>

    render_subscription_grid: ->
        <SubscriptionGrid period={@state.selected_button} selected_plan={@props.selected_plan} />

    render_dedicated_resources: ->
        <div style={marginBottom:'15px'}>
            <ExplainResources type='dedicated'/>
        </div>

    render_create_subscription_options: ->
        # <h3><Icon name='list-alt'/> Sign up for a Subscription</h3>
        <div>
            <div style={textAlign:'center'}>
                {@render_period_selection_buttons()}
            </div>
            {@render_subscription_grid()}
        </div>
        ###
            if @state.selected_button is 'month' or @state.selected_button is 'year'}
            {@render_dedicated_resources() if @state.selected_button is 'dedicated_resources'}
        ###

    render_create_subscription_confirm: (plan_data) ->
        if @is_recurring()
            subscription = " and you will be signed up for a recurring subscription"
        name = plan_data.desc ? misc.capitalize(@props.selected_plan).replace(/_/g,' ') + ' plan'
        <Alert>
            <h4><Icon name='check' /> Confirm your selection </h4>
            <p>You have selected a <span style={fontWeight:'bold'}>{name} subscription</span>.</p>
            {@render_renewal_info()}
            <p>By clicking 'Add Subscription or Course Package' below, your payment card will be immediately charged{subscription}.</p>
        </Alert>

    render_create_subscription_buttons: ->
        <Row>
            <Col sm={4}>
                {powered_by_stripe()}
            </Col>
            <Col sm={8}>
                <ButtonToolbar className='pull-right'>
                    <Button
                        bsStyle  = 'primary'
                        bsSize   = 'large'
                        onClick  = {=>(@submit_create_subscription();@props.on_close())}
                        disabled = {@props.selected_plan is ''} >
                        <Icon name='check' /> Add Subscription or Course Package
                    </Button>
                    <Button
                        onClick  = {@props.on_close}
                        bsSize   = 'large'
                        >
                        Cancel
                    </Button>
                </ButtonToolbar>
            </Col>
        </Row>

    render: ->
        plan_data = PROJECT_UPGRADES.subscription[@props.selected_plan.split('-')[0]]
        <Row>
            <Col sm={10} smOffset={1}>
                <Well style={boxShadow:'5px 5px 5px lightgray', zIndex:1}>
                    {@render_create_subscription_options()}
                    {@render_create_subscription_confirm(plan_data) if @props.selected_plan isnt ''}
                    {<ConfirmPaymentMethod
                        is_recurring = {@is_recurring()}
                        on_close = {@props.on_close}
                    /> if @props.selected_plan isnt ''}
                    {@render_create_subscription_buttons()}
                    <Row style={paddingTop:'15px'}>
                        <Col sm={5} smOffset={7}>
                            <CouponAdder applied_coupons={@props.applied_coupons} coupon_error={@props.coupon_error} />
                        </Col>
                    </Row>
                </Well>
                <ExplainResources type='shared'/>
            </Col>
        </Row>

ConfirmPaymentMethod = rclass
    reduxProps :
        billing :
            customer : rtypes.object

    propTypes :
        is_recurring : rtypes.bool
        on_close : rtypes.func

    render_single_payment_confirmation: ->
        <span>
            <p>Payment will be processed with the card below.</p>
            <p>To change payment methods, please change your default card above.</p>
        </span>


    render_recurring_payment_confirmation: ->
        <span>
            <p>The initial payment will be processed with the card below.
            Future payments will be made with whichever card you have set as your default<Space/>
            <b>at the time of renewal</b>.</p>
        </span>

    render: ->
        if not @props.customer
            return <AddPaymentMethod redux={redux} />
        default_card = undefined
        for card_data in @props.customer.sources.data
            if card_data.id == @props.customer.default_source
                default_card = card_data
        if not default_card?
            #  Should not happen (there should always be a default), but
            # it did: https://github.com/sagemathinc/cocalc/issues/3468
            # We try again with whatever the first card is.
            for card_data in @props.customer.sources.data
                default_card = card_data
                break
            # Still no card -- just ask them for one first.
            if not default_card?
                return <AddPaymentMethod redux={redux} />

        <Alert>
            <h4><Icon name='check' /> Confirm your payment card</h4>
            {@render_single_payment_confirmation() if not @props.is_recurring}
            {@render_recurring_payment_confirmation() if @props.is_recurring}
            <Well>
                <PaymentMethod
                    source = {default_card}
                />
            </Well>
        </Alert>

CouponAdder = rclass
    displayName : 'CouponAdder'

    propTypes:
        applied_coupons : rtypes.immutable.Map
        coupon_error    : rtypes.string

    getInitialState: ->
        coupon_id : ''

    # Remove typed coupon if it got successfully added to the list
    componentWillReceiveProps: (next_props) ->
        if next_props.applied_coupons.has(@state.coupon_id)
            @setState(coupon_id : '')

    key_down: (e) ->
        if e.keyCode == 13
            @submit()

    submit: (e) ->
        e?.preventDefault()
        @actions('billing').apply_coupon(@state.coupon_id) if @state.coupon_id

    render_well_header: ->
        if @props.applied_coupons?.size > 0
            <h5 style={color:'green'}><Icon name='check' /> Coupon added!</h5>
        else
            <h5 style={color:'#666'}><Icon name='plus' /> Add a coupon?</h5>

    render: ->

        # TODO: (Here or elsewhere) Your final cost is:
        #       $2 for the first month
        #       $7/mo after the first
        if @props.applied_coupons?.size > 0
            placeholder_text = 'Enter another code?'
        else
            placeholder_text = 'Enter your code here...'

        if @state.coupon_id == ''
            bsStyle = undefined
        else
            bsStyle = 'primary'

        <Well>
            {@render_well_header()}
            {<CouponList applied_coupons={@props.applied_coupons} /> if @props.applied_coupons?.size > 0}
            {<FormGroup style={marginTop:'5px'}>
                <InputGroup>
                    <FormControl
                        value       = {@state.coupon_id}
                        ref         = 'coupon_adder'
                        type        = 'text'
                        size        = '7'
                        placeholder = {placeholder_text}
                        onChange    = {(e) => @setState(coupon_id : e.target.value)}
                        onKeyDown   = {@key_down}
                        onBlur      = {@submit}
                    />
                    <InputGroup.Button>
                        <Button onClick={@submit} disabled={@state.coupon_id == ''} bsStyle={bsStyle} >
                            Apply
                        </Button>
                    </InputGroup.Button>
                </InputGroup>
            </FormGroup> if @props.applied_coupons?.size == 0}
            {<SkinnyError error_text={@props.coupon_error} on_close={@actions('billing').clear_coupon_error} /> if @props.coupon_error}
        </Well>

CouponList = rclass
    displayName : 'CouponList'

    propTypes:
        applied_coupons : rtypes.immutable.Map

    render: ->
        # TODO: Support multiple coupons
        coupon = @props.applied_coupons.first()
        <CouponInfo coupon={coupon}/>

CouponInfo = rclass
    displayName : 'CouponInfo'

    propTypes:
        coupon : rtypes.object

    render: ->
        console.log("coupon = ", @props.coupon)
        <Row>
            <Col md={4}>
                {@props.coupon.id}
            </Col>
            <Col md={8}>
                {@props.coupon.metadata.description}
                <CloseX on_close={=>@actions('billing').remove_coupon(@props.coupon.id)} />
            </Col>
        </Row>


exports.SubscriptionGrid = SubscriptionGrid = rclass
    displayName : 'SubscriptionGrid'

    propTypes :
        period        : rtypes.string.isRequired  # see docs for PlanInfo
        selected_plan : rtypes.string
        is_static     : rtypes.bool    # used for display mode

    getDefaultProps: ->
        is_static : false

    is_selected: (plan, period) ->
        if @props.period?.slice(0, 4) is 'year'
            return @props.selected_plan is "#{plan}-year"
        else if @props.period?.slice(0, 4) is 'week'
            return @props.selected_plan is "#{plan}-week"
        else
            return @props.selected_plan is plan

    render_plan_info: (plan, period) ->
        <PlanInfo
            plan     = {plan}
            period   = {period}
            selected = {@is_selected(plan, period)}
            on_click = {if not @props.is_static then ->set_selected_plan(plan, period)} />

    render_cols: (row, ncols) ->
        width = 12/ncols
        for plan in row
            <Col sm={width} key={plan}>
                {@render_plan_info(plan, @props.period)}
            </Col>

    render_rows: (live_subscriptions, ncols) ->
        for i, row of live_subscriptions
            <Row key={i}>
                {@render_cols(row, ncols)}
            </Row>

    render: ->
        live_subscriptions = []
        periods = misc.split(@props.period)
        for row in PROJECT_UPGRADES.live_subscriptions
            v = []
            for x in row
                price_keys = _.keys(PROJECT_UPGRADES.subscription[x].price)
                if _.intersection(periods, price_keys).length > 0
                    v.push(x)
            if v.length > 0
                live_subscriptions.push(v)
        # Compute the maximum number of columns in any row
        ncols = Math.max((row.length for row in live_subscriptions)...)
        # Round up to nearest divisor of 12
        if ncols == 5
            ncols = 6
        else if ncols >= 7
            ncols = 12
        <div>
            {@render_rows(live_subscriptions, ncols)}
        </div>


exports.ExplainResources = ExplainResources = rclass
    propTypes :
        type : rtypes.string.isRequired    # 'shared', 'dedicated'
        is_static : rtypes.bool

    getDefaultProps: ->
        is_static : false

    render_toc: ->
        return if not @props.is_static
        <React.Fragment>
            <h4>Table of content</h4>
            <ul>
                <li><b><a href="#subscriptions">Personal subscriptions</a></b>:{' '}
                    upgrade your projects
                </li>
                <li><b><a href="#courses">Course packages</a></b>:{' '}
                    upgrade student projects for teaching a course
                </li>
                <li><b><a href="#dedicated">Dedicated VMs</a></b>:{' '}
                    a node in the cluster for large workloads
                </li>
                <li><b><a href="#faq">FAQ</a></b>: frequently asked questions</li>
            </ul>
            <Space/>
        </React.Fragment>

    render_shared: ->
        <div>
            <Row>
                <Col md={8} sm={12}>
                    <h4>Questions</h4>
                    <div style={fontSize:'12pt'}>
                        Please immediately email us at <HelpEmailLink/>,{' '}
                        {if not @props.is_static then <span> click the Help button above or read our <a target='_blank' href="#{PolicyPricingPageUrl}#faq" rel="noopener">pricing FAQ</a> </span>}
                        if anything is unclear to you, or you just have a quick question and do not want to wade through all the text below.
                    </div>
                    <Space/>

                    {@render_toc()}

                    <a name="projects"></a>
                    <h4>Projects</h4>
                    <div>
                    Your work on <SiteName/> happens inside <em>projects</em>.
                    You may create any number of independent projects.
                    They form your personal workspaces,
                    where you privately store your files, computational worksheets, and data.
                    You typically run computations through a web browser,
                    either via a worksheet, notebook, or by executing a program in a terminal
                    (you can also ssh into any project).
                    You can also invite collaborators to work with you inside a project,
                    and you can explicitly make files or directories publicly available
                    to everybody.
                    </div>
                    <Space/>

                    <h4>Shared Resources</h4>
                    <div>
                    Each project runs on a server, where it shares disk space, CPU, and RAM with other projects.
                    Initially, projects run with default quotas on heavily used machines that are rebooted frequently.
                    You can upgrade any quota on any project on which you collaborate, and you can move projects
                    to faster very stable <em>members-only computers</em>,
                    where there is much less competition for resources.
                    </div>
                    <Space/>

                    <h4>Quota upgrades</h4>
                    <div>
                    By purchasing one or more of our subscriptions,
                    you receive a certain amount of <em>quota upgrades</em>.
                    <ul style={paddingLeft:"20px"}>
                    <li>You can upgrade the quotas on any of your projects
                        up to the total amount given by your subscription(s)
                        and the upper limits per project.
                    </li>
                    <li>Project collaborators can collectively contribute to the same project,
                        in order to increase the quotas of their common project
                        &mdash; these contributions add together to benefit all project collaborators equally.</li>
                    <li>You can remove your contributions to any project at any time.</li>
                    <li>You may also purchase multiple plans more than once,
                        in order to increase the total amount of upgrades available to you.</li>
                    </ul>
                    </div>
                    <Space/>

                </Col>
                <Col md={4} sm={12}>
                    <Row>
                        <Col md={12} sm={6}>
                            <ProjectQuotaFreeTable/>
                        </Col>
                        <Col md={12} sm={6}>
                            <ProjectQuotaBoundsTable/>
                        </Col>
                    </Row>
                </Col>
            </Row>
        </div>

    render_dedicated: ->
        <div>
            <h4>Dedicated resources</h4>
            You may also rent dedicated computers.
            Projects on such a machine of your choice get full use of the hard disk, CPU and RAM,
            and do <em>not</em> have to compete with other users for resources.
            We have not fully automated purchase of dedicated computers yet,
            so please contact us at <HelpEmailLink/> if you need a dedicated machine.
        </div>

    render: ->
        switch @props.type
            when 'shared'
                return @render_shared()
            when 'dedicated'
                return @render_dedicated()
            else
                throw Error("unknown type #{@props.type}")

exports.ExplainPlan = ExplainPlan = rclass
    propTypes :
        type : rtypes.string.isRequired    # 'personal', 'course'

    render_personal: ->
        <div style={marginBottom:"10px"}>
            <a name="subscriptions"></a>
            <h3>Personal subscriptions</h3>
            <div>
                We offer several subscriptions that let you upgrade the default free quotas on projects.
                You can distribute these upgrades to your own projects or any projects where you are a collaborator &mdash;
                everyone participating in such a collective project benefits and can easily change their allocations at any time!
                You can get higher-quality hosting on members-only machines and enable access to the internet from projects.
                You can also increase quotas for CPU and RAM, so that you can work on larger problems and
                do more computations simultaneously.
            </div>
            <br/>
            <div>
                For highly intensive workloads you can also get a <a href="#dedicated">Dedicated VM</a>.
            </div>
            <br/>
        </div>

    render_course: ->
        <div style={marginBottom:"10px"}>
            <a name="courses"></a>
            <h3>Course packages</h3>
            <div>
                <p>
                We offer course packages to support teaching using <SiteName/>.
                They start right after purchase and last for the indicated period and do <b>not auto-renew</b>.
                Follow the <a href="https://doc.cocalc.com/teaching-instructors.html" target="_blank" rel="noopener">instructor guide</a> to create a course file for your new course.
                Each time you add a student to your course, a project will be automatically created for that student.
                You can create and distribute assignments,
                students work on assignments inside their project (where you can see their progress
                in realtime and answer their questions),
                and you later collect and grade their assignments, then return them.
                </p>

                <p>
                Payment is required. This will ensure that your students have a better
                experience, network access, and receive priority support.  The cost
                is <b>between $4 and ${STUDENT_COURSE_PRICE} per student</b>, depending on class size and whether
                you or your students pay.  <b>Start right now:</b> <i>you can fully set up your class
                and add students immediately before you pay us anything!</i>

                </p>

                <h4>You or your institution pays</h4>
                You or your institution may pay for one of the course plans.
                You then use your plan to upgrade all projects in the course in the settings tab of the course file.

                <h4>Students pay</h4>
                In the settings tab of your course, you require that all students
                pay a one-time ${STUDENT_COURSE_PRICE} fee to move their
                projects to members only hosts and enable full internet access.

                <br/>

                <h4>Basic or Standard?</h4>
                Our basic plans work well for cases where you are only doing
                small computations or just need internet access and better hosting uptime.

                However, we find that many data science and computational science courses
                run much smoother with the additional RAM and CPU found in the standard plan.

                <h4>Custom Course Plans</h4>
                In addition to the plans listed on this page, we can offer the following on a custom basis:
                    <ul>
                        <li>start on a specified date after payment</li>
                        <li>customized duration</li>
                        <li>customized number of students</li>
                        <li>bundle several courses with different start dates</li>
                        <li>transfer upgrades from purchasing account to course administrator account</li>
                    </ul>
                To learn more about these options, email us at <HelpEmailLink/> with a description
                of your specific requirements.
                <br/>

                <br/>

            </div>
        </div>

    render: ->
        switch @props.type
            when 'personal'
                return @render_personal()
            when 'course'
                return @render_course()
            else
                throw Error("unknown plan type #{@props.type}")


exports.DedicatedVM = DedicatedVM = rclass
    render_intro: ->
        <div style={marginBottom:"10px"}>
            <a name="dedicated"></a>
            <h3>Dedicated VMs<sup><i>beta</i></sup></h3>
            <div style={marginBottom:"10px"}>
                A <b>Dedicated VM</b> is a specific node in the cluster,{' '}
                which solely hosts one or more of your projects.
                This allows you to run much larger workloads with a consistent performance,{' '}
                because no resources are shared with other projects.
                The usual quota limitations do not apply and
                you also get additional disk space attached to individual projects.
            </div>
            <div>
                To get started, please contact us at <HelpEmailLink/>.
                We will work out the actual requirements with you and set everything up.
                It is also possible to deviate from the given options,{' '}
                in order to accommodate exactly for the expected resource usage.
            </div>
        </div>

    render_dedicated_plans: ->
        for i, plan of PROJECT_UPGRADES.dedicated_vms
            <Col key={i} sm={4}>
                <PlanInfo
                    plan = {plan}
                    period = {'month'}
                />
            </Col>

    render_dedicated: ->
        <div style={marginBottom:"10px"}>

            <Row>
                {@render_dedicated_plans()}
            </Row>
        </div>

    render: ->
        <React.Fragment>
            {@render_intro()}
            {@render_dedicated()}
        </React.Fragment>

Subscription = rclass
    displayName : 'Subscription'

    propTypes :
        redux        : rtypes.object.isRequired
        subscription : rtypes.object.isRequired

    getInitialState: ->
        confirm_cancel : false

    cancel_subscription: ->
        @props.redux.getActions('billing').cancel_subscription(@props.subscription.id)

    quantity: ->
        q = @props.subscription.quantity
        if q > 1
            return "#{q} × "

    render_cancel_at_end: ->
        if @props.subscription.cancel_at_period_end
            <span style={marginLeft:'15px'}>Will cancel at period end.</span>

    render_info: ->
        sub = @props.subscription
        cancellable = not (sub.cancel_at_period_end or @state.cancelling or @state.confirm_cancel)
        <Row style={paddingBottom: '5px', paddingTop:'5px'}>
            <Col md={4}>
                {@quantity()} {sub.plan.name} ({misc.stripe_amount(sub.plan.amount, sub.plan.currency)} for {plan_interval(sub.plan)})
            </Col>
            <Col md={2}>
                {misc.capitalize(sub.status)}
            </Col>
            <Col md={4} style={color:'#666'}>
                {misc.stripe_date(sub.current_period_start)} – {misc.stripe_date(sub.current_period_end)} (start: {misc.stripe_date(sub.start)})
                {@render_cancel_at_end()}
            </Col>
            <Col md={2}>
                {<Button style={float:'right'} onClick={=>@setState(confirm_cancel:true)}>Cancel...</Button> if cancellable}
            </Col>
        </Row>

    render_confirm: ->
        if not @state.confirm_cancel
            return
        ###
        TODO: these buttons do not seem consistent with other button language, but makes sense because of the use of "Cancel" a subscription
        ###
        <Alert bsStyle='warning'>
            <Row style={borderBottom:'1px solid #999', paddingBottom:'15px', paddingTop:'15px'}>
                <Col md={6}>
                    Are you sure you want to cancel this subscription?  If you cancel your subscription, it will run to the end of the subscription period, but will not be renewed when the current (already paid for) period ends; any upgrades provided by this subscription will be disabled.    If you need further clarification or need a refund, please email  <HelpEmailLink/>.
                </Col>
                <Col md={6}>
                    <Button onClick={=>@setState(confirm_cancel:false)}>Make No Change</Button>
                    <div style={float:'right'}>
                        <Button bsStyle='danger' onClick={=>@setState(confirm_cancel:false);@cancel_subscription()}>Yes, please cancel and do not auto-renew my subscription</Button>
                    </div>
                </Col>
            </Row>
        </Alert>


    render: ->
        <div style={borderBottom:'1px solid #999',  paddingTop: '5px', paddingBottom: '5px'}>
            {@render_info()}
            {@render_confirm() if @state.confirm_cancel}
        </div>

Subscriptions = rclass
    displayName : 'Subscriptions'

    propTypes :
        subscriptions   : rtypes.object
        sources         : rtypes.object # could be undefined, if it is a customer but all cards are removed
        selected_plan   : rtypes.string
        redux           : rtypes.object.isRequired
        applied_coupons : rtypes.immutable.Map
        coupon_error    : rtypes.string

    getInitialState: ->
        state : 'view'    # view -> add_new ->         # FUTURE: ??

    close_add_subscription: ->
        @setState(state : 'view')
        set_selected_plan('')
        @actions('billing').remove_all_coupons()

    render_add_subscription_button: ->
        <Button
            bsStyle   = 'primary'
            disabled  = {@state.state isnt 'view' or (@props.sources?.total_count ? 0) is 0}
            onClick   = {=>@setState(state : 'add_new')}
            className = 'pull-right' >
            <Icon name='plus-circle' /> Add Subscription or Course Package...
        </Button>

    render_add_subscription: ->
        <AddSubscription
            on_close        = {@close_add_subscription}
            selected_plan   = {@props.selected_plan}
            actions         = {@props.redux.getActions('billing')}
            applied_coupons = {@props.applied_coupons}
            coupon_error    = {@props.coupon_error} />

    render_header: ->
        <Row>
            <Col sm={6}>
                <Icon name='list-alt' /> Subscriptions and course packages
            </Col>
            <Col sm={6}>
                {@render_add_subscription_button()}
            </Col>
        </Row>

    render_subscriptions: ->
        return null if not @props.subscriptions?
        for sub in @props.subscriptions.data
            <Subscription key={sub.id} subscription={sub} redux={@props.redux} />

    render: ->
        <Panel header={@render_header()}>
            {@render_add_subscription() if @state.state is 'add_new'}
            {@render_subscriptions()}
        </Panel>

Invoice = rclass
    displayName : "Invoice"

    propTypes :
        invoice : rtypes.object.isRequired
        redux   : rtypes.object.isRequired

    getInitialState: ->
        hide_line_items : true

    download_invoice: (e) ->
        e.preventDefault()
        invoice = @props.invoice
        username = @props.redux.getStore('account').get_username()
        misc_page = require('./misc_page')  # do NOT require at top level, since code in billing.cjsx may be used on backend
        misc_page.download_file("#{window.app_base_url}/invoice/cocalc-#{username}-receipt-#{new Date(invoice.date*1000).toISOString().slice(0,10)}-#{invoice.id}.pdf")

    render_paid_status: ->
        if @props.invoice.paid
            return <span>PAID</span>
        else
            return <span style={color:'red'}>UNPAID</span>

    render_description: ->
        if @props.invoice.description
            return <span>{@props.invoice.description}</span>

    render_line_description: (line) ->
        v = []
        if line.quantity > 1
            v.push("#{line.quantity} × ")
        if line.description?
            v.push(line.description)
        if line.plan?
            v.push(line.plan.name)
            v.push(" (start: #{misc.stripe_date(line.period.start)})")
        return v

    render_line_item: (line, n) ->
        <Row key={line.id} style={borderBottom:'1px solid #aaa'}>
            <Col sm={1}>
                {n}.
            </Col>
            <Col sm={9}>
                {@render_line_description(line)}
            </Col>
            <Col sm={2}>
                {render_amount(line.amount, @props.invoice.currency)}
            </Col>
        </Row>

    render_tax: ->
        <Row key='tax' style={borderBottom:'1px solid #aaa'}>
            <Col sm={1}>
            </Col>
            <Col sm={9}>
                WA State Sales Tax ({@props.invoice.tax_percent}%)
            </Col>
            <Col sm={2}>
                {render_amount(@props.invoice.tax, @props.invoice.currency)}
            </Col>
        </Row>

    render_line_items: ->
        if @props.invoice.lines
            if @state.hide_line_items
                <a href='' onClick={(e)=>e.preventDefault();@setState(hide_line_items:false)}>(details)</a>
            else
                v = []
                v.push <a key='hide' href='' onClick={(e)=>e.preventDefault();@setState(hide_line_items:true)}>(hide details)</a>
                n = 1
                for line in @props.invoice.lines.data
                    v.push @render_line_item(line, n)
                    n += 1
                if @props.invoice.tax
                    v.push @render_tax()
                return v

    render: ->
        <Row style={borderBottom:'1px solid #999'}>
            <Col md={1}>
                {render_amount(@props.invoice.amount_due, @props.invoice.currency)}
            </Col>
            <Col md={1}>
                {@render_paid_status()}
            </Col>
            <Col md={3}>
                {misc.stripe_date(@props.invoice.date)}
            </Col>
            <Col md={6}>
                {@render_description()}
                {@render_line_items()}
            </Col>
            <Col md={1}>
                <a onClick={@download_invoice} href=""><Icon name="cloud-download" /></a>
            </Col>
        </Row>

InvoiceHistory = rclass
    displayName : "InvoiceHistory"

    propTypes :
        redux    : rtypes.object.isRequired
        invoices : rtypes.object

    render_header: ->
        <span>
            <Icon name="list-alt" /> Invoices and receipts
        </span>

    render_invoices: ->
        if not @props.invoices?
            return
        for invoice in @props.invoices.data
            <Invoice key={invoice.id} invoice={invoice} redux={@props.redux} />

    render: ->
        <Panel header={@render_header()}>
            {@render_invoices()}
        </Panel>

exports.PayCourseFee = PayCourseFee = rclass
    reduxProps :
        billing :
            applied_coupons : rtypes.immutable.Map
            coupon_error    : rtypes.string

    propTypes :
        project_id : rtypes.string.isRequired
        redux      : rtypes.object.isRequired

    getInitialState: ->
        confirm : false

    buy_subscription: ->
        if @props.redux.getStore('billing').get('course_pay').has(@props.project_id)
            # already buying.
            return
        actions = @props.redux.getActions('billing')
        # Set semething in billing store that says currently doing
        actions.set_is_paying_for_course(this.props.project_id, true)
        # Purchase 1 course subscription
        try
            await actions.create_subscription('student_course')
        catch err
            actions.set_is_paying_for_course(this.props.project_id, false)
            return
        # Wait until a members-only upgrade and network upgrade are available, due to buying it
        @setState(confirm:false)
        @props.redux.getStore('account').wait
            until   : (store) =>
                upgrades = store.get_total_upgrades()
                # NOTE! If you make one available due to changing what is allocated it won't cause this function
                # we're in here to update, since we *ONLY* listen to changes on the account store.
                applied = @props.redux.getStore('projects').get_total_upgrades_you_have_applied()
                return (upgrades.member_host ? 0) - (applied?.member_host ? 0) > 0 and (upgrades.network ? 0) - (applied?.network ? 0) > 0
            timeout : 30  # wait up to 30 seconds
            cb      : (err) =>
                if err
                    actions.setState(error:"Error purchasing course subscription: #{err}")
                else
                    # Upgrades now available -- apply a network and members only upgrades to the course project.
                    upgrades = {member_host: 1, network: 1}
                    @props.redux.getActions('projects').apply_upgrades_to_project(@props.project_id, upgrades)
                # Set in billing that done
                actions.set_is_paying_for_course(this.props.project_id, false);

    render_buy_button: ->
        if @props.redux.getStore('billing').get('course_pay').has(@props.project_id)
            <Button bsStyle='primary' disabled={true}>
                <Icon name="cc-icon-cocalc-ring" spin /> Currently paying the one-time ${STUDENT_COURSE_PRICE} fee for this course...
            </Button>
        else
            <Button onClick={=>@setState(confirm:true)} disabled={@state.confirm} bsStyle='primary'>
                Pay the one-time ${STUDENT_COURSE_PRICE} fee for this course...
            </Button>

    render_confirm_button: ->
        if @state.confirm
            if @props.redux.getStore('account').get_total_upgrades().network > 0
                network = " and full internet access enabled"
            <Well style={marginTop:'1em'}>
                You will be charged a one-time ${STUDENT_COURSE_PRICE} fee to move your project to a
                members-only server and enable full internet access.
                <br/><br/>
                <ButtonToolbar>
                    <Button onClick={@buy_subscription} bsStyle='primary'>
                        Pay ${STUDENT_COURSE_PRICE} Fee
                    </Button>
                    <Button onClick={=>@setState(confirm:false)}>Cancel</Button>
                </ButtonToolbar>
            </Well>

    render: ->
        <span>
            <Row>
                <Col sm={5}>
                    <CouponAdder applied_coupons={@props.applied_coupons} coupon_error={@props.coupon_error} />
                </Col>
            </Row>
            {@render_buy_button()}
            {@render_confirm_button()}
        </span>

MoveCourse = rclass
    propTypes :
        project_id : rtypes.string.isRequired
        redux      : rtypes.object.isRequired

    getInitialState: ->
        confirm : false

    upgrade: ->
        available = @props.redux.getStore('account').get_total_upgrades()
        upgrades = {member_host: 1}
        if available.network > 0
            upgrades.network = 1
        @props.redux.getActions('projects').apply_upgrades_to_project(@props.project_id, upgrades)
        @setState(confirm:false)

    render_move_button: ->
        <Button onClick={=>@setState(confirm:true)} bsStyle='primary' disabled={@state.confirm}>
            Move this project to a members only server...
        </Button>

    render_confirm_button: ->
        if @state.confirm
            if @props.redux.getStore('account').get_total_upgrades().network > 0
                network = " and full internet access enabled"
            <Well style={marginTop:'1em'}>
                Your project will be moved to a members only server{network} using
                upgrades included in your current subscription (no additional charge).
                <br/><br/>
                <ButtonToolbar>
                    <Button onClick={@upgrade} bsStyle='primary'>
                        Move Project
                    </Button>
                    <Button onClick={=>@setState(confirm:false)}>Cancel</Button>
                </ButtonToolbar>
            </Well>

    render: ->
        <span>
            {@render_move_button()}
            {@render_confirm_button()}
        </span>


BillingPage = rclass
    displayName : 'BillingPage'

    reduxProps :
        billing :
            customer        : rtypes.object
            invoices        : rtypes.object
            error           : rtypes.oneOfType([rtypes.string, rtypes.object])
            action          : rtypes.string
            loaded          : rtypes.bool
            no_stripe       : rtypes.bool     # if true, stripe definitely isn't configured on the server
            selected_plan   : rtypes.string
            applied_coupons : rtypes.immutable.Map
            coupon_error    : rtypes.string
            continue_first_purchase: rtypes.bool
        projects :
            project_map : rtypes.immutable # used, e.g., for course project payments; also computing available upgrades
        account :
            stripe_customer : rtypes.immutable  # to get total upgrades user has available

    propTypes :
        redux         : rtypes.object
        is_simplified : rtypes.bool
        for_course    : rtypes.bool

    render_action: ->
        if @props.action
            <ActivityDisplay style={position:'fixed', right:'45px', top:'85px'} activity ={[@props.action]} on_clear={=>@props.redux.getActions('billing').clear_action()} />

    render_error: ->
        if @props.error
            <ErrorDisplay
                error   = {@props.error}
                onClose = {=>@props.redux.getActions('billing').clear_error()} />

    # the space in "Contact us" below is a Unicode no-break space, UTF-8: C2 A0. "&nbsp;" didn't work there [hal]
    render_help_suggestion: ->
        <span>
            <Space/> If you have any questions at all, read the{' '}
            <a
                href={"https://doc.cocalc.com/billing.html"}
                target={"_blank"}
                rel={"noopener"}
            >Billing{"/"}Upgrades FAQ</a> or {' '}
            email <HelpEmailLink /> immediately.
            <b>
                <Space/>
                <HelpEmailLink text={"Contact us"} />{' '}
                if you are considering purchasing a course subscription and need a short trial
                to test things out first.
                <Space/>
            </b>
            <b>
                <Space/> Customized course plans are available.<Space/>
            </b>
            If you do not see a plan that fits your needs,
            email <HelpEmailLink/> with a description of your specific requirements.
        </span>

    render_suggested_next_step: ->
        cards    = @props.customer?.sources?.total_count ? 0
        subs     = @props.customer?.subscriptions?.total_count ? 0
        invoices = @props.invoices?.data?.length ? 0
        help     = @render_help_suggestion()

        if cards == 0
            if subs == 0
                # no payment sources yet; no subscriptions either: a new user (probably)
                <span>
                    If you are {' '}
                    <a
                      href={"https://doc.cocalc.com/teaching-instructors.html"}
                      target={"_blank"}
                      rel={"noopener"}
                    >teaching a course</a>, choose one of the course packages.
                    If you need to upgrade your personal projects, choose a recurring subscription.
                    You will <b>not be charged</b> until you explicitly click
                    "Add Subscription or Course Package".
                    {help}
                </span>
            else
                # subscriptions but they deleted their card.
                <span>
                    Click "Add Payment Method..." to add a credit card so you can
                    purchase or renew your subscriptions.  Without a credit card
                    any current subscriptions will run to completion, but will not renew.
                    If you have any questions about subscriptions or billing (e.g., about
                    using PayPal or wire transfers for non-recurring subscriptions above $50,
                    please email <HelpEmailLink /> immediately.
                </span>

        else if subs == 0
            # have a payment source, but no subscriptions
            <span>
                Click "Add Subscription or Course Package...".
                If you are{' '}
                <a
                  href={"https://doc.cocalc.com/teaching-instructors.html"}
                  target={"_blank"}
                  rel={"noopener"}
                >teaching a course</a>, choose one of the course packages.
                If you need to upgrade your personal projects, choose a recurring subscription.
                You will be charged only after you select a specific subscription and click
                "Add Subscription or Course Package".
                {help}
            </span>
        else if invoices == 0
            # have payment source, subscription, but no invoices yet
            <span>
                Sign up for the same subscription package more than
                once to increase the number of upgrades that you can use.
                {help}
            </span>
        else
            # have payment source, subscription, and at least one invoice
            <span>
                You may sign up for the same subscription package more than
                once to increase the number of upgrades that you can use.
                Past invoices and receipts are available below.
                {help}
            </span>

    render_info_link: ->
        <div style={marginTop:'1em', marginBottom:'1em', color:"#666"}>
            We offer many <a href={PolicyPricingPageUrl} target='_blank' rel="noopener"> pricing and subscription options</a>.
            <Space/>
            {@render_suggested_next_step()}
        </div>

    get_panel_header: (icon, header) ->
        <div style={cursor:'pointer'} >
            <Icon name={icon} fixedWidth /> {header}
        </div>

    render_subscriptions: ->
        <Subscriptions
            subscriptions   = {@props.customer.subscriptions}
            applied_coupons = {@props.applied_coupons}
            coupon_error    = {@props.coupon_error}
            sources         = {@props.customer.sources}
            selected_plan   = {@props.selected_plan}
            redux           = {@props.redux} />

    finish_first_subscription: ->
        set_selected_plan('')
        @actions('billing').remove_all_coupons();
        @actions('billing').setState({continue_first_purchase: false})

    render_page: ->
        cards    = @props.customer?.sources?.total_count ? 0
        subs     = @props.customer?.subscriptions?.total_count ? 0
        if not @props.loaded
            # nothing loaded yet from backend
            <Loading />
        else if not @props.customer? and @props.for_course
            # user not initialized yet -- only thing to do is add a card.
            <div>
                <PaymentMethods redux={@props.redux} sources={data:[]} default='' />
            </div>
        else if not @props.for_course and (not @props.customer? or @props.continue_first_purchase)
            <div>
                <AddSubscription
                    on_close        = {@finish_first_subscription}
                    selected_plan   = {@props.selected_plan}
                    actions         = {@props.redux.getActions('billing')}
                    applied_coupons = {@props.applied_coupons}
                    coupon_error    = {@props.coupon_error} />
            </div>
        else
            # data loaded and customer exists
            if @props.is_simplified and subs > 0
                <div>
                    <PaymentMethods redux={@props.redux} sources={@props.customer.sources} default={@props.customer.default_source} />
                    {<Panel header={@get_panel_header('list-alt', 'Subscriptions and Course Packages')} eventKey='2'>
                        {@render_subscriptions()}
                    </Panel> if not @props.for_course}
                </div>
            else if @props.is_simplified
                <div>
                    <PaymentMethods redux={@props.redux} sources={@props.customer.sources} default={@props.customer.default_source} />
                    {@render_subscriptions() if not @props.for_course}
                </div>
            else
                <div>
                    <PaymentMethods redux={@props.redux} sources={@props.customer.sources} default={@props.customer.default_source} />
                    {@render_subscriptions() if not @props.for_course}
                    <InvoiceHistory invoices={@props.invoices} redux={@props.redux} />
                </div>

    render: ->
        <div>
            <div>
                {@render_info_link() if not @props.for_course}
                {@render_action() if not @props.no_stripe}
                {@render_error()}
                {@render_page() if not @props.no_stripe}
            </div>
            {<Footer/> if not @props.is_simplified}
        </div>

exports.BillingPageRedux = rclass
    displayName : 'BillingPage-redux'

    render: ->
        <BillingPage is_simplified={false} redux={redux} />

exports.BillingPageSimplifiedRedux = rclass
    displayName : 'BillingPage-redux'

    render: ->
        <BillingPage is_simplified={true} redux={redux} />

exports.BillingPageForCourseRedux = rclass
    displayName : 'BillingPage-redux'

    render: ->
        <BillingPage is_simplified={true} for_course={true} redux={redux} />

render_amount = (amount, currency) ->
    <div style={float:'right'}>{misc.stripe_amount(amount, currency)}</div>

brand_to_icon = (brand) ->
    return if brand in ['discover', 'mastercard', 'visa'] then "fab fa-cc-#{brand}" else "fa-credit-card"


# FUTURE: make this an action and a getter in the BILLING store
set_selected_plan = (plan, period) ->
    if period?.slice(0,4) == 'year'
        plan = plan + "-year"
    if period?.slice(0,4) == 'week'
        plan = plan + "-week"
    redux.getActions('billing').setState(selected_plan : plan)

exports.render_static_pricing_page = () ->
    <div>
        <ExplainResources type='shared' is_static={true}/>
        <hr/>
        <ExplainPlan type='personal'/>
        <SubscriptionGrid period='month year' is_static={true}/>
        <hr/>
        <ExplainPlan type='course'/>
        <SubscriptionGrid period='week month4 year1' is_static={true}/>
        <hr/>
        <DedicatedVM />
        <hr/>
        <FAQ/>
    </div>

exports.visit_billing_page = ->
    require('./history').load_target('settings/billing')

exports.BillingPageLink = (opts) ->
    {text} = opts
    if not text
        text = "billing page"
    return <a onClick={exports.visit_billing_page} style={cursor:'pointer'}>{text}</a>

plan_interval = (plan) ->
    n = plan.interval_count
    return "#{plan.interval_count} #{misc.plural(n, plan.interval)}"