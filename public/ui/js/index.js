var diff_time = function(a, b) {
  return a && b && ((a - b) / 1000);
};
var diff_time_str = function(dt) {
  if ( ! dt ) return dt;
  var dta = dt < 0 ? - dt : dt;
  if ( dta < 90 )
    return "" + (dt).toFixed(2) + " sec";
  if ( dta < 3 * 60 * 60)
    return "" + (dt / 60).toFixed(2) + " min";
  if ( dta < 3 * 24 * 60 * 60 )
    return "" + (dt / (60 * 60)).toFixed(2) + " hr";
  return "" + (dt / (24 * 60 * 60)).tofixed(2) + " day";
};

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
    return <span ref="elem">{this.props.content}</span>
  }
});

var KeyVal = React.createClass({
  render: function() {
    return (
      <span className="key_val">
        <a href="#" className="display_on_hover">
          <span className="v"><span className={this.props.v_class}><FlashOnChange content={this.props.v}>{this.props.v}</FlashOnChange></span></span>
          <span className="display_on_hover"> : <span className="k"><FlashOnChange content={this.props.k}>{this.props.k}</FlashOnChange></span>
          </span>
        </a>
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

var Status = React.createClass({
  render: function() {
    var top_level = this.props.top_level;
    var now = top_level.now_date;
    var data = this.props.data;
    var status = data.status;
    var control = data.control;
    var controls = data.controls.map(function(item) {
       return (
       <div key={item.path}>
         <Control top_level={top_level} data={item} key={item.path} />
       </div>
       );
    });
    var seen_current_version = status.seen_version && status.seen_current_version === true;
    var version_class = seen_current_version ? "current_version" : "not_current_version";

    var control_time = Date.parse(control.time);
    var status_time  = Date.parse(status.time);
    var version_age  = seen_current_version ? "" : diff_time_str(diff_time(control_time, status_time));

    var status_interval = status.interval;
    var status_age = diff_time(now, status_time);
    var status_age_class =
      ! status_interval ||
      status_age > status_interval ?
        "unresponsive" : "responsive";

    return (
      <div className="status">
        <div>
          <KeyVal k={"path"} v={data.path} v_class={"path"} />
          <KeyVal k={status.host ? status.client_ip : "client_ip"} v={status.host || status.client_ip} />
          <KeyVal k={status.time} v={diff_time_str(diff_time(now, status_time))} v_class={status_age_class} />
          <KeyVal k={"status_interval"} v={status_interval && ((status_age_class == "unresponsive" ? "> " : "< ") + (status_interval || '???') + " sec")} />
        </div>
        <div>
          <table>
          <tbody>
            <tr>
              <td><span className="dim">Status:</span></td>
              <td><KeyVal k={"seen_version"} v={status.seen_version || '???'} v_class={version_class} /></td>
              <td><KeyVal k={"version_age"} v={version_age} v_class={version_class}/></td>
            </tr>
            <tr>
              <td><span className="dim">Data:</span></td>
              <td colSpan="2">
                <pre className="code">{JSON.stringify(status.data, null, 2)}</pre>
              </td>
            </tr>
            <tr>
              <td><span className="dim">Control:</span></td>
              <td><KeyVal k={"version"} v={control.version} v_class={version_class} /></td>
              <td><KeyVal k={"time"}    v={control.time} /></td>
            </tr>
            <tr>
              <td><span className="dim">Data:</span></td>
              <td colSpan="2">
                <pre className="code">{JSON.stringify(control.data, null, 2)}</pre>
              </td>
            </tr>
            <tr>
              <td />
              <td colSpan="2"><div className="status-controls">{controls}</div></td>
            </tr>
          </tbody>
          </table>
        </div>
      </div>
    );
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
      <div className="statusList">
        {statuses}
      </div>
    );
  }
});

var StatusBox = React.createClass({
  loadStatussFromServer: function() {
    $.ajax({
      url: this.props.url,
      dataType: 'json',
      cache: false,
      success: function(data) {
        data.now_date = Date.parse(data.now);
        this.setState({data: data});
      }.bind(this),
      error: function(xhr, status, err) {
        var now = new Date();
        var url = this.props.url;
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
    this.loadStatussFromServer();
    setInterval(this.loadStatussFromServer, this.props.pollInterval);
  },
  render: function() {
    var data = this.state.data;
    return (
      <div className="statusBox">
        <div>
          <KeyVal k="path" v={data.path} v_class="path" />
          <KeyVal k="host" v={data.host} />
          <KeyVal k="now"  v={data.now} />
          <span className="error">{data.error}</span>
          <span className="right">
          <KeyVal k="api_name"     v={data.api_name} />
          <KeyVal k="api_version"  v={data.api_version} />
          </span>
        </div>
        <div className="statusList">
          <StatusList top_level={data} data={data.status} />
        </div>
      </div>
    );
  }
});

ReactDOM.render(
  <StatusBox url="/api/status/" pollInterval={5000} />,
  document.getElementById('content')
);
