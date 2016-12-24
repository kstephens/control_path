# control_path

Idea
====

* On HTTP POST /api/control/PATH, create a control data object associated with PATH.
* On HTTP GET /api/control/PATH, return the control data object associated with PATH.
* On HTTP GET /api/client/PATH
** Return a control data object merged from all found controls from top of PATH.
** Save /api/status/PATH with data about the client's request. (e.g: time of request, ip address, hostname, ...).
* On HTTP GET /api/client/PATH
** Return the status(es) under PATH.

The PATH provides a heirarchy that allows inherited behavior to be visible.

A typical PATH might look something like /#{env}/#{application}/#{instance} or /#{env}/#{host}.

Example
=======

Start Service
-------------

```
 $ bundle exec rackup -s thin -p 9090
```

Start Client
-------------

```
$ bundle exec ruby  -I lib -r control_path/client/agent \
  -e 'ControlPath::Client::Agent.new(http: ControlPath::Http.new, uri: "http://localhost:9090/api/client/foo/bar", interval: (2 .. 4)).test!.run!'
```

Start UI
-------------
```
$ open http://localhost:9090/ui
```

PUT Inherited Control Data
----------------------

```
 $ curl -X PUT -d '{"status":"foo"}' http://localhost:9090/api/control/foo
```

PUT Immediate Control Data
----------------------

```
 $ curl -X PUT -d '{"status":"foo-bar"}' http://localhost:9090/api/control/foo/bar
```

DELETE Control Data
----------------------

```
 $ curl -X DELETE http://localhost:9090/api/control/foo
```
