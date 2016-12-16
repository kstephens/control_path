# control_path

Idea
====

* Clients will HTTP GET /controlpath/api/client/#{env}/#{app}/#{host}/#{instance}.
* For each HTTP GET, save /controlpath/api/status/#{env}/#{app}/#{host}/#{instance} with some data about the client (e.g: time of request, ip address, hostname, ...).
* If /controlpath/api/control/#{env}/#{app}/#{host}/#{instance} does not exist, it is created with a blank file.
* On HTTP POST /controlpath/api/control//..., we create a control entry.

Example
=======

```
 $ bundle exec rackup -s thin -p 9090
```

```
 $ irb -I lib -r control_path/client/agent
2.1.1 :001 > ControlPath::Client::Agent.new(http: ControlPath::Http.new, uri: "http://localhost:9090/api/client/foo/bar", interval: (2 .. 4)).run!
```

```
 $ curl -X PUT -d '{"status":"restart"}' http://localhost:9090/api/control/foo

 $ curl -X DELETE http://localhost:9090/api/control/foo
```
