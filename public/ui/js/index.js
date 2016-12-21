var KeyVal = React.createClass({
  render: function() {
    return (
      <span className="key_val">
        <a href="#" className="display_on_hover">
          <span className="v"><span className={this.props.v_class}>{this.props.v}</span></span>
          <span className="display_on_hover"> : <span className="k">{this.props.k}</span>
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
    })
    var seen_current_version = status.seen_version && status.seen_current_version === true;
    var version_class = seen_current_version ? "current_version" : "not_current_version";

    var diff_time = function(a, b) {
      return a && b && ((a - b) / 1000);
    };
    var diff_time_str = function(a, b) {
      var dt = diff_time(a, b);
      return dt && ("" + dt + " sec");
    };
   
    var control_time = Date.parse(control.time);
    var status_time  = Date.parse(status.time);
    var version_age  = seen_current_version ? "" : diff_time_str(control_time, status_time);

    var status_interval = status.interval;
    var status_age = diff_time(now, status_time);
    var status_age_class =
      ! status_interval ||
      status_age > status_interval ?
        "unresponsive" : "responsive";

    return (
      <div className="status">
        <KeyVal k={"path"} v={data.path} v_class={"path"} />
        <KeyVal k={status.host ? status.client_ip : "client_ip"} v={status.host || status.client_ip} />
        <KeyVal k={status.time} v={diff_time_str(now, status_time)} v_class={status_age_class} />
        <KeyVal k={"status_interval"} v={status_interval && ((status_age_class == "unresponsive" ? "> " : "< ") + (status_interval || '???') + " sec")} />
        <div>
          <table>
          <tbody>
            <tr>
              <td>Status:</td>
              <td><span>
                <KeyVal k={"version"} v={status.seen_version || '???'} v_class={version_class} />
                <KeyVal k={"version_age"} v={version_age} v_class={version_class}/>
              </span></td>
            </tr>
            <tr>
              <td>Control:</td>
              <td><Control top_level={top_level} data={control} version_class={version_class} /></td>
            </tr>
            <tr>
              <td />
              <td><div className="status-controls">{controls}</div></td>
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
        console.error(this.props.url, status, err.toString());
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
        <h1>Status {data.path}</h1>
        <div>
          <KeyVal k={"path"} v={data.path} v_class="path" />
          <KeyVal k={"host"} v={data.host} /> 
          <KeyVal k={"now"}  v={data.now} />
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