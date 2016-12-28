var ControlPath =
function (options) {

if ( ! options['interval'] )
  options['interval'] = 5000;
if ( options['interval'] < 5000 )
  options['interval'] = 5000;

var diff_time = function(a, b) {
  return a && b && ((a - b) / 1000);
};
var diff_time_str = function(dt) {
  if ( ! dt ) return dt;
  var dta = dt < 0 ? - dt : dt;
  if ( dta < 90 )
    return "" + (dt).toFixed(2) + " sec";
  if ( dta < 3 * 60 * 60 )
    return "" + (dt / 60).toFixed(2) + " min";
  if ( dta < 3 * 24 * 60 * 60 )
    return "" + (dt / (60 * 60)).toFixed(2) + " hr";
  return   "" + (dt / (24 * 60 * 60)).toFixed(2) + " day";
};
var parse_time = function(x) {
  if ( typeof x === 'string' )
    return Date.parse(x);
  else
    return x;
}

var FlashOnChange = React.createClass({
  componentDidUpdate: function(props, state) {
    if (this.props.content !== props.content) {
      var flash_class   = this.props.flash_class   || "flash";
      var flash_timeout = this.props.flash_timeout || 1000;
      var elem = this.refs.elem;
      elem.classList.add(flash_class);
      setTimeout(function() {
        elem.classList.remove(flash_class);
      }, flash_timeout);
    }
  },
  render: function() {
    return <span ref="elem">{this.props.children}</span>
  }
});

var ZoomOnHover = React.createClass({
  render: function() {
    return (
      <a href="#" className="zoom_on_hover"><span>{this.props.children}</span></a>
      );
  }
});

var KeyVal = React.createClass({
  render: function() {
    return (
      <span className="key_val">
        <a href="#" className="display_on_hover">
          <span className="v"><span  className={this.props.v_class}><FlashOnChange content={this.props.v}>{this.props.v}</FlashOnChange></span></span>
          <span className="display_on_hover"> : <span className="k"><FlashOnChange content={this.props.k}>{this.props.k}</FlashOnChange></span></span>
        </a>
      </span>
      );
  }
});

var Shorten = React.createClass({
  render: function() {
    var s   = (this.props.content || "").toString();
    var w_l = this.props.left_width || 8;
    var s_l = this.props.content_left  || s.substring(0, w_l);
    var s_r = this.props.content_right || s.substring(w_l, s.length);
    var c_l = this.props.left_class  || this.props.content_class;
    var c_r = this.props.right_class || this.props.content_class;
    return (
      <span className="shorten">
        <a href="#" className="display_on_hover">
          <span className="shorten_left"><span className={c_l}><FlashOnChange content={s_l}>{s_l}</FlashOnChange></span></span><span className="display_on_hover"><span className={c_r}><FlashOnChange content={s_r}>{s_r}</FlashOnChange></span></span>
        </a>
      </span>
      );
  }
});

var TimeAsAge = React.createClass({
  render: function() {
    var now  = parse_time(this.props.now);
    var time = parse_time(this.props.time);
    var age  = diff_time(now, time);
    return (
       <KeyVal k={this.props.time} v={diff_time_str(age)} v_class={this.props.v_class} />
    );
  }
});

var TimeShort = React.createClass({
  render: function() {
    var time = this.props.time;
    return (
      <FlashOnChange content={time}><Shorten content={time} left_width="10" content_class="{this.props.v_class}" /></FlashOnChange>
    );
  }
});

var ControlMini = React.createClass({
  render: function() {
    var top_level = this.props.top_level;
    var now = top_level.now_date;
    var data = this.props.data;
    var version_class = this.props.version_class;
    var k = data.version + " " + data.time;
    return (
      <span className="control_mini">
        <KeyVal k={k} v={data.path} v_class="path" />
      </span>
    );
  }
});

var Control = React.createClass({
  render: function() {
    var top_level = this.props.top_level;
    var now = top_level.now_date;
    var data = this.props.data;
    var version_class = this.props.version_class;
    return (
      <span className="control">
        <KeyVal k={"path"}    v={data.path} v_class="path" />
        <KeyVal k={"version"} v={data.version} v_class={version_class} />
        <KeyVal k={"time"}    v={data.time} />
        <div><pre className="code">{JSON.stringify(data.data, null, 2)}</pre></div>
      </span>
    );
  }
});

var ControlData = React.createClass({
  render: function() {
    return (
      <ZoomOnHover><pre className="code">{JSON.stringify(this.props.data, null, 2)}</pre></ZoomOnHover>
    );
  }
});

var Status = React.createClass({
  render: function() {
    var top_level = this.props.top_level;
    var now = top_level.now_date;
    var data = this.props.data;
    var status = data.status;
    var control = data.control;
    var controls = data.controls.map(function(item) {
       return (
       <span key={item.path}>
         <ControlMini top_level={top_level} data={item} key={item.path} />
       </span>
       );
    });
    var seen_current_control_version = status.seen_control_version && status.seen_current_control_version === true;
    var version_class = seen_current_control_version ? "current_version" : "not_current_version";

    var control_time = parse_time(control.time);
    var status_time  = parse_time(status.time);
    var version_age  = control.time ? (seen_current_control_version ? "" : diff_time_str(diff_time(status_time, control_time))) : "???";

    var status_interval = status.interval;
    var status_age = diff_time(now, status_time);
    var status_age_class;
    if ( status_interval ) {
      status_age_class = "responsive";
      if ( status_age > status_interval * 1.10 )
         status_age_class = "unresponsive";
      if ( status_age > status_interval * 2.20 )
         status_age_class = "very_unresponsive";
    }
 
    return (
      <div className="status">
        <div className="line">
          <KeyVal k="path" v={data.path} v_class={"path"} />
          <span className="h-margin-large">
            <KeyVal k={status.host ? status.client_ip : "client_ip"} v={status.host || status.client_ip} />
          </span>
          <span className="h-margin-large">
          <TimeAsAge time={status.time} now={now} v_class={status_age_class} />
          <KeyVal k="status_interval" v={status_interval && ((status_age_class == "unresponsive" ? "> " : "< ") + (status_interval || '???') + " sec")} />
          </span>
          <span className="h-margin-large">
          <span className="smaller"><Shorten content={status.agent_id} /></span>
          <KeyVal k="agent_tick" v={status.agent_tick} />
          </span>
        </div>
        <div className="line">
          <span className="lc"><span className="dim smaller right">status:</span></span>
          <span className="rc">
            <span className="version"><Shorten content={status.seen_control_version || '???'} content_class={version_class} /></span>
            <KeyVal k="status_version_age"  v={version_age} v_class={version_class} />
          </span>
        </div>
        <div className="line">
          <span className="lc"><span className="dim smaller right">data:</span></span>
          <span className="rc">
             <ControlData data={status.data} />
          </span>
        </div>
        <div className="line">
          <span className="lc"><span className="dim smaller right">control:</span></span>
          <span className="rc">
            <span className="version"><Shorten content={control.version} content_class={version_class} /></span>
            <TimeShort time={control.time} />
          </span>
        </div>
        <div className="line">
          <span className="lc"><span className="dim smaller right">data:</span></span>
          <span className="rc">
             <ControlData data={control.data} />
          </span>
        </div>
        <div className="line">
          <span className="lc"><span className="dim smaller right">controls:</span></span>
          <span className="rc"><span className="status-controls">{controls}</span></span>
        </div>
      </div>
    );
    /*
        <div className="line">
           <ZoomOnHover><pre className="code">{JSON.stringify(data, null, 2)}</pre></ZoomOnHover>
        </div>
        */
  }
});


var StatusList = React.createClass({
  render: function() {
    var top_level = this.props.top_level;
    var statuses = this.props.data.map(function(item) {
      return (
        <div key={item.path}>
          <hr />
          <Status top_level={top_level} data={item} key={item.path}/>
        </div>
      );
    });
    return (
      <div className="status_list">
        {statuses}
      </div>
    );
  }
});

var StatusBox = React.createClass({
  loadFromServer: function() {
    $.ajax({
      url: this.props.options.url,
      dataType: 'json',
      cache: false,
      success: function(data) {
        data.now_date = parse_time(data.now);
        this.setState({data: data});
      }.bind(this),
      error: function(xhr, status, err) {
        var now = new Date();
        var url = this.props.options.url;
        var data = {
          api_name:    this.state.data.api_name    || "???",
          api_version: this.state.data.api_version || "???",
          now: now.toISOString(),
          now_date: now,
          url: url,
          error_code: status.toString(),
          error: ("" + status + " : " + err + " : " + url),
          status: this.state.data.status || [ ]
        };
        console.error(JSON.stringify(data));
        console.error(JSON.stringify(xhr));
        this.setState({data: data});
      }.bind(this)
    });
  },
  getInitialState: function() {
    return { data: { now_date: new Date(), status: [ ]} };
  },
  componentDidMount: function() {
    this.loadFromServer();
    setInterval(this.loadFromServer, this.props.options.interval);
  },
  render: function() {
    var data = this.state.data;
    return (
      <div className="status_box">
        <div>
          <KeyVal k="path" v={data.path} v_class="path" />
          <span className="h-margin-large">
          <KeyVal k="host" v={data.host} />
          </span>
          <span className="h-margin-large">
          <KeyVal k="now"  v={data.now} />
          </span>
          <span className="error">{data.error}</span>
          <span className="right">
          <KeyVal k="api_name"     v={data.api_name} />
          <KeyVal k="api_version"  v={data.api_version} />
          </span>
        </div>
        <StatusList top_level={data} data={data.status} />
      </div>
    );
  }
});

ReactDOM.render(
  <StatusBox options={options} />,
  document.getElementById(options['mountpoint'])
);
};
