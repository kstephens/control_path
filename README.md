# control_path

Idea
====

* Clients will HTTP GET /controlpath/api/client/#{env}/#{app}/#{host}/#{instance}.
* For each HTTP GET, save /controlpath/api/status/#{env}/#{app}/#{host}/#{instance} with some data about the client (e.g: time of request, ip address, hostname, ...).
* If /controlpath/api/control/#{env}/#{app}/#{host}/#{instance} does not exist, it is created with a blank file.
* On HTTP POST /controlpath/api/control//..., we create a control entry.

