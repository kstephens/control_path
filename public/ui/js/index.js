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
      <div className="control">
        <KeyVal k={"path"}    v={data.path} />
        <KeyVal k={"time"}    v={data.time} />
        <KeyVal k={"version"} v={data.version} v_class={version_class}/>
      </div>
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
         <Control top_level={top_level} data={item} key={item.path} />
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
        <hr />
        <KeyVal k={"path"} v={data.path} />
        <KeyVal k={"client_ip"} v={status.client_ip} />
        <KeyVal k={status.time} v={diff_time_str(now, status_time)} v_class={status_age_class} />
        <KeyVal k={"status_interval"} v={status_interval && ("< " + status_interval + " sec")} />
        <KeyVal k={"version"} v={status.seen_version || '???'} v_class={version_class} />
        <KeyVal k={"version_age"} v={version_age} v_class={version_class}/>
        <div>
          <Control top_level={top_level} data={control} version_class={version_class} />
          <div>
            <div className="status-controls">{controls}</div>
          </div>
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
        <Status top_level={top_level} data={item} key={item.path}/>
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
        this.setState({data: data});
      }.bind(this),
      error: function(xhr, status, err) {
        console.error(this.props.url, status, err.toString());
      }.bind(this)
    });
  },
  getInitialState: function() {
    return { data: { status: [ ]} };
  },
  componentDidMount: function() {
    this.loadStatussFromServer();
    setInterval(this.loadStatussFromServer, this.props.pollInterval);
  },
  render: function() {
    var data = this.state.data;
    data.now_date = Date.parse(data.now);
    return (
      <div className="statusBox">
        <h1>Status {data.path}</h1>
        <div>
          <KeyVal k={"path"} v={data.path} /> 
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
  <StatusBox url="/api/status/" pollInterval={2000} />,
  document.getElementById('content')
);
