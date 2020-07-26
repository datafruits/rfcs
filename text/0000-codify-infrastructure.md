- Start Date: 2020-07-25
- RFC PR:

# Codify Infrastructure

<!-- toc -->

- [Summary 📖](#summary-%F0%9F%93%96)
- [Motivation 🏃🏻‍♀️](#motivation-%F0%9F%8F%83%F0%9F%8F%BB%E2%80%8D%E2%99%80%EF%B8%8F)
- [Detailed design 🔎](#detailed-design-%F0%9F%94%8E)
  * [What exactly _is_ the datafruits stack? 🤔](#what-exactly-_is_-the-datafruits-stack-%F0%9F%A4%94)
    + [Client Site (datafruits.fm) 🍉](#client-site-datafruitsfm-%F0%9F%8D%89)
    + [Admin Site (streampusher.com) 🚂](#admin-site-streampushercom-%F0%9F%9A%82)
    + [Static Assets 🗂](#static-assets-%F0%9F%97%82)
    + [Podcasts 🎙](#podcasts-%F0%9F%8E%99)
    + [Database 🛢](#database-%F0%9F%9B%A2)
    + [API 🚏](#api-%F0%9F%9A%8F)
    + [Audio streaming 🔊](#audio-streaming-%F0%9F%94%8A)
    + [Video Streaming 📹](#video-streaming-%F0%9F%93%B9)
    + [Chat 💬](#chat-%F0%9F%92%AC)
  * [Intro to Kubernetes ☁️](#intro-to-kubernetes-%E2%98%81%EF%B8%8F)
    + [Containers 📦](#containers-%F0%9F%93%A6)
      - [What's a container? 🧐](#whats-a-container-%F0%9F%A7%90)
      - [How do I make one? 🛠](#how-do-i-make-one-%F0%9F%9B%A0)
      - [Why should I make one? 🤷🏻‍♀️](#why-should-i-make-one-%F0%9F%A4%B7%F0%9F%8F%BB%E2%80%8D%E2%99%80%EF%B8%8F)
    + [Pods 🐟](#pods-%F0%9F%90%9F)
    + [Services 🚃](#services-%F0%9F%9A%83)
    + [Ingress 🚪](#ingress-%F0%9F%9A%AA)
    + [Nodes 🧱](#nodes-%F0%9F%A7%B1)
  * [Proposed Cluster Architecture 🏗](#proposed-cluster-architecture-%F0%9F%8F%97)
    + [Listeners (fruitcakes) 🎧](#listeners-fruitcakes-%F0%9F%8E%A7)
    + [DJs and VJs 💽](#djs-and-vjs-%F0%9F%92%BD)
    + [Developers 👩🏻‍💻](#developers-%F0%9F%91%A9%F0%9F%8F%BB%E2%80%8D%F0%9F%92%BB)
    + [Management 🤵🏻](#management-%F0%9F%A4%B5%F0%9F%8F%BB)
  * [Path to Production 👷🏻‍♀️](#path-to-production-%F0%9F%91%B7%F0%9F%8F%BB%E2%80%8D%E2%99%80%EF%B8%8F)
- [Drawbacks 😬](#drawbacks-%F0%9F%98%AC)
- [Alternatives ⚖️](#alternatives-%E2%9A%96%EF%B8%8F)
- [Unresolved questions ❓](#unresolved-questions-%E2%9D%93)

<!-- tocstop -->

## Summary 📖

Right now, the infrastructure for datafruits is really ad-hoc. As best as I can tell, some stuff is running on [Heroku](https://www.heroku.com/) and some stuff is running on [DigitalOcean](https://www.digitalocean.com/). This RFC has two goals:

1. Codify the infrastructure for the datafruits site so that it's easily understandable where everything lives.
2. Cloud-ify the existing infrastructure so that each component is individually scalable.

## Motivation 🏃🏻‍♀️

As stated above, one reason to do this is to make it more clear where everything lives -- it allows someone (like me ☺️) to take a look and understand how all the pieces fit together.

Another reason to keep the infrastructure as code is that it makes the infra versionable, meaning rollbacks are literally as easy as `git revert`. [More on the benefits of IoC](https://docs.microsoft.com/en-us/azure/devops/learn/what-is-infrastructure-as-code)

This also allows us to move from treating the services (streampusher, datafruits) like pets to treating them like cattle, which means less messy ssh-ing and more codified changes. [More reading on this terminology](https://medium.com/@Joachim8675309/devops-concepts-pets-vs-cattle-2380b5aab313)

Additionally, by moving to a [Kubernetes (K8s)](https://kubernetes.io/) based infrastructure, it allows us a lot more (horizontal) scalability, and the ability to scale out each chunk of the stack individually -- if there are 30,000,000 users in the chat, it makes sense to scale up the chat server, but maybe not also the [rmtp(s)](https://en.wikipedia.org/wiki/Real-Time_Messaging_Protocol) server, which only has the one person running viz connected to it.

Fourth, we now have the opportunity to actually do logging. Logging! Imagine, datafruits goes down and we don't have to spend eight hours figuring out why. We have an idea for a new feature, and we can actually figure out if people use it. Metrics! God, the metrics. Plus we can avoid G\*\*\*\*\* A\*\*\*\*\*\*\*\* and run our [own analytics platform](https://github.com/zgoat/goatcounter) that's privacy friendly.

Lastly, there are also cost savings associated with moving to a containerized architecture. We move from running a few digital ocean droplets, a couple heroku dynos, and whatever else we have to running 3 droplets on digital ocean. Additionally, those droplets will be a lot more efficient about their resource usage than they currently are, since their only purpose will be to run docker images.

## Detailed design 🔎

I wrote this out in the order that makes sense to me, but feel free to skip around. I'll go over my understanding of what comprises the "datafruits stack", a brief overview of just the critical things you need to understand Kubernetes ("just enough to be dangerous"), a look at how I think we should structure the infrastructure both inside and outside the cluster, and a gradual adoption plan to transition datafruits over to the new ecosystem.

### What exactly _is_ the datafruits stack? 🤔

Basically, to run on kubernetes, you need to make all of your applications (like, code that executes and runs things) [containerizable](https://opensource.com/resources/what-docker), and you need to keep your data elsewhere. We'll get into why this is the case later, but for now I'll go into these talking about the current way datafruits runs things and how we'll fit them into the new model.

As near as I can tell, this is an overview of the entire tech stack that goes into making datafruits tick. I'm suuuuper shaky on this, so feedback is highly appreciated -- I'm almost certainly missing things 🙃

#### Client Site (datafruits.fm) 🍉

The most important (arguably) part of the whole thing is the website. The repo lives at [datafruits/datafruits](https://github.com/datafruits/datafruits). It's built on [ember.js](https://emberjs.com/), and importantly with [ember-cli-fastboot](https://github.com/ember-fastboot/ember-cli-fastboot). This means that the web server is a [super lightweight Node.js process](https://github.com/ember-fastboot/fastboot-app-server#ember-fastboot-app-server), which is trivial to containerize. More on containerization later.

#### Admin Site (streampusher.com) 🚂

This is the place you go where if you're Tony, you can look at all the DJs and their information, or if you're a DJ you can manage your own stuff and upload sets and things like that. I'm not _super_ sure how it works, because I'm not a DJ and I don't have access to it, and I've never been invested enough to really dig through the code.

That said, it has its entire own codebase, which lives in [streampusher/frontend](https://github.com/streampusher/frontend). This, too, is an Ember app, which does NOT use ember-cli-fastboot. It currently lives on [netlify](https://www.netlify.com/), which is like a [serverless](https://aws.amazon.com/serverless/) [static site](https://en.wikipedia.org/wiki/Static_web_page) hosting platform, kind of like [GitHub Pages](https://pages.github.com/). I think. I've never used netlify, although I certainly have seen people sing its praises.

At least, I think it lives on netfliy. There's a netlify config in the [`ember-cli-build.js`](https://github.com/streampusher/frontend/blob/master/ember-cli-build.js). Either way, it should be similarly easy to containerize this app the same way we'd containerize the client site.

#### Static Assets 🗂

Another important thing for UX is the static assets -- who doesn't love the pulsating 𝕕𝕒𝕥𝕒𝕗𝕣𝕦𝕚𝕥𝕤 logo? Currently...I'm not sure how these are served. Some of them are checked in to the client site repo, but some of them aren't. With this RFC, I propose we move all of the static assets to dedicated object hosting (like [DigitalOcean Spaces](https://www.digitalocean.com/products/spaces/)). [More on object storage](https://blog.westerndigital.com/why-object-storage/)

We could minimize the pain of uploading assets separately and harcoding urls by editing the config for [`broccoli-asset-rev`](https://github.com/rickharrison/broccoli-asset-rev) (the tooling ember uses to process static assets) to prepend a url to the assets in production, and then just check everything in to the client site repo under `src/assets/`.

The coding for this _should_ be pretty easy, and would just involve adding something like the following to `ember-cli-build.js`:

```js
/* eslint-env node */
"use strict";
const EmberApp = require("ember-cli/lib/broccoli/ember-app");

module.exports = function (defaults) {
  let app = new EmberApp(defaults, {
    fingerprint: {
      prepend: app.env === "production" ? "https://static.datafruits.fm/" : "",
    },
    // more config...
  });

  //...
  return app.toTree();
};
```

..and then adding something to CI to upload any static assets we want that aren't served by fastboot to our object storage.

Note: It's worth looking into how fastboot handles assets, because some things (css, fonts?) are rendered server-side, but some things probably aren't. Either way, all the assets should live in one place. C'mon, now.

#### Podcasts 🎙

The podcasts, past broadcasts, and all that audio has to live somewhere. We could use a very similar (or even the same!) type of object storage to keep these handy. DigitalOcean Spaces is [S3](https://aws.amazon.com/s3/) compatible, meaning we could use existing tooling to manage all of thise stuff. Plus the pricing [isn't bad](https://www.digitalocean.com/pricing/#spaces-object-storage).

Realistically, what we do is when a new podcast is uploaded we add a row to our SQL database (more on that in the next paragraph) that contains the link to the object so we can keep track of them all in an organized way. That additional overhead is pretty much the reason I'm listing these as separate from static assets like JS, CSS, etc.

#### Database 🛢

Currently, datafruits is running [PostgreSQL](https://www.postgresql.org/), a variant of [SQL](https://www.infoworld.com/article/3219795/what-is-sql-the-first-language-of-data-analysis.html) ([more on relational vs. non-relational databases](https://www.pluralsight.com/blog/software-development/relational-non-relational-databases)). Cool. It's basically just a managed SQL database, meaning we don't have to worry about [scaling](https://www.freecodecamp.org/news/understanding-database-scaling-patterns/), [sharding](https://blog.yugabyte.com/how-data-sharding-works-in-a-distributed-sql-database/), or any of the other hassle that comes with standing up your own SQL instances in the cloud. This is going to live _outside_ of our Kubernetes cluster, so it's wonderful that it's already handled for us.

This database probably contains things like which DJs there are, what the links are to the podcasts, and that sort of thing. Basically, any persistent data involved with datafruits. There should be literally no change in this when we migrate to Kubernetes. I am not a database administrator, nor do I want to be. That sounds like hell.

#### API 🚏

You can't just write SQL queries in the frontend, because that's [gross and also a huge security vulnerability](https://stackoverflow.com/a/60332563). So you need a layer in between, where the datafruits website can go "hey show me all the podcasts tagged "house"" and then the API (the layer in between) can turn around and go `SELECT * FROM podcasts WHERE tags INCLUDES "house"` and then go "hey datafruits dot fm client site, here is the information you wanted".

Currently, the API lives in [streampusher/api](https://github.com/streampusher/api) ([look, here are the model classes](https://github.com/streampusher/api/tree/master/app/models)) and is written in [Ruby](https://www.ruby-lang.org/en/). The API is what's called [RESTful](https://restfulapi.net/), which means that it supports operations like `GET`, which retrieves data, `POST`, which creates new data, `PUT`, which is like `POST` but also updates data, `DELETE`, which is exactly what it sounds like, and `PATCH` which is like `PUT` but semantically different.

REST is pretty good, and certainly better than [SOAP](https://restfulapi.net/soap-vs-rest-apis/), but it has this issue where every particular type of data needs its own endpoint. This means you wind up getting super long and specific URLs like `api.datafruits.fm/artists/ovenrake/podcasts`. It also means that it's hard to change existing endpoints -- like if you wanted to restructure to `api.datafruits.fm/podcasts?dj=ovenrake`, then you'd have to deprecate the old endpoint, update all of your client code, yadda yadda yadda.

Another issue with REST is that it always returns all of the data it has. Even if all you want is the `title` and `link` to a podcast, you'll also get the `tags` and the `image` and the `bandcamp_link` or whatever other fields it has.

The solution to this is the new shiny thing called [GraphQL](https://graphql.org/), which aims to solve the problems that REST has. Refactoring the existing API into GraphQL is gonna probably warrant its own RFC, but I wanted to mention it here so I didn't forget about it.

In terms of containerization, the API literally [already has a Dockerfile](https://github.com/streampusher/api/blob/master/Dockerfile) so this should be ok with only minor tweaks.

#### Audio streaming 🔊

This is probably the second most important part of the ᴅᴀᴛᴀғʀᴜɪᴛs ᴇxᴘᴇʀɪᴇɴᴄᴇ, behind the site itself. The code that handles this stuff lives in [streampusher/radio](https://github.com/streampusher/radio). The audio streaming is built on [icecast](https://icecast.org), which is what broadcasts the audio, and [liquidsoap](https://www.liquidsoap.info/), which provides icecast with the audio to stream.

There's something to be said about rebuilding this setup to be less fragile, and there will likely be some issues trying to move this into Kubernetes. Kubernetes relies on its containers being mostly stateless, and so there may potentially be issues with having containers die in the middle of a stream.

I mean, there shouldn't be, but there might be. Kubernetes is like that sometimes.

Anyway, there are already docker images for both components of this setup, so wiring it up to Kubernetes should be mostly YAML configuring and not a lot of code editing.

#### Video Streaming 📹

Another cool think datafruits has is video streaming. The code for this lives (confusingly separate from streampusher) in [datafruits/viz](https://github.com/datafruits/viz). Currently, it's built on [`nginx-rtmp-module`](https://www.nginx.com/products/nginx/modules/rtmp-media-streaming/), which is a laughably simple way to set up video streaming. The repo reflects this, having literally two files.

This should also be pretty easy to containerize, given that the [README](https://github.com/datafruits/viz/blob/master/README.md) is basically already a [Dockerfile](https://docs.docker.com/engine/reference/builder/).

#### Chat 💬

I take it all back - THIS is the most important part of datafruits. The code for the chat server lives in [datafruits/hotdog_lounge](https://github.com/datafruits/hotdog_lounge), because this is datafruits and none of these names can be normal. It's written in [Elixir](https://elixir-lang.org/), and built using [Phoenix](https://phoenixframework.org/). Which seems fine, I mean I have literally no experience using functional programming languages (is Javascript functional? No?) but apparently Elixir is [really good at concurrency](https://medium.com/flatiron-labs/elixir-and-the-beam-how-concurrency-really-works-3cc151cddd61), which makes it a no-brainer for a chat app.

This is the bit I'm most concerned about moving to Kubernetes. Currently we just have the one single chat server running, which is fine if we're using the pet model, but moooving to the cattle model means that we could potentially have two or three or a gazillion instances of the server running. Obviously, they can't all receive and post messages, because we'd get duplicates and whatnot.

Luckily, this seems to be something that the [Erlang VM](https://blog.lelonek.me/elixir-on-erlang-vm-demystified-320557d09e1f) has built-in. There are [some guides](https://www.poeticoding.com/distributed-phoenix-chat-with-pubsub-pg2-adapter/) out there for this specific thing, actually. Basically, we would either set up something like the [Pub/Sub model](https://www.ably.io/concepts/pub-sub) where we have something like [Apache Kafka](http://kafka.apache.org/) sit in front of our chat servers and make sure everything gets chatted exactly once ([turns out this is a big problem, actually](https://www.youtube.com/watch?v=IP-rGJKSZ3s)), _or_ we use [pg2](https://erlang.org/doc/man/pg2.html) (ignore the deprecation warning 🤫), which is built-in to Erlang, to distribute work over multiple instances of the chat server.

Wow, would you look at that. Someone made a nice tutorial on [exactly this](https://www.poeticoding.com/connecting-elixir-nodes-with-libcluster-locally-and-on-kubernetes/) scenario. Neat! I choose the approach that doesn't need a separate message broker and also it has a tutorial.

Basically, this is the part of the datafruits stack that is going to take the most work to get Kubernetes ready. It's not impossible, and in fact this is probably the easiest possible make-my-chat-server-distributed thing you could possibly do, but it's still work. Which, y'know.

### Intro to Kubernetes ☁️

Like I mentioned above, the end-goal is to have the entire datafruits stack living inside a single Kubernetes cluster. So let's talk about Kubernetes.

[Kubernetes](https://kubernetes.io/docs/concepts/overview/what-is-kubernetes/) is, at its core, a container orchestration system. In simpler terms, it's a way to coordinate workloads across different containers, and it handles scaling, routing, and all that type of stuff. The link at the start of this paragraph is pretty good for an (extremely thorough) in-depth look at the what and how and why of Kubernetes, and here I'll just write up a quick and dirty overview off the top of my head.

#### Containers 📦

I've talked a lot about "containerizing" apps. You'll also hear this called "Dockerizing." [Docker](https://opensource.com/resources/what-docker) is the industry-standard tool for containerization, although [alternatives do exist](https://containerjournal.com/topics/container-ecosystems/5-container-alternatives-to-docker/). Kubernetes is built on containers, so it's important to have a basic understanding of what a container is, how it works, and why they're so widely used. Here's a crash course overview.

##### What's a container? 🧐

Containers are basically the next step in virtualization technology, up from VMs. The easiest way to think about what this means is probably something like this:

|                  | Bare-Metal Computer | Virtual Machine | Container |
| ---------------- | ------------------- | --------------- | --------- |
| Software         | Real                | Real            | Real      |
| Operating System | Real                | Real            | Emulated  |
| Hardware         | Real                | Emulated        | Emulated  |

Basically, while a VM provides an entire operating system to its end-users and emulates the hardware, containers provide a sandboxed environment within the host's operating system to its end-users and emulates the OS.

This means that now instead of needing to set up and configure entire VMs, you only need to configure the application and its dependencies. This is done declaratively, through the use of something like a [Dockerfile](https://rollout.io/blog/what-is-a-dockerfile/), which tend to look something like this:

```dockerfile
# Start with a "base image"
FROM ubuntu:bionic
# This doesn't *have* to be just an operating system,
# and many images exist with some software pre-installed.
# For example, NodeJS, Golang, Ruby, and Python all have
# official base images which contain tooling for their
# respective languages. In fact, any docker image
# can be used as the base image for any other docker image.

# Copy files from some directory on the host machine into the image
COPY ./dist ./static

# Install whatever software dependencies you need
RUN sudo apt update && sudo apt upgrade
RUN sudo apt install -y install npm nodejs

# Install whatever software libraries you need
RUN npm install -g http-server

# Instruct docker on what to do when someone runs your image
CMD http-server ./static --port 6969 --ssl
```

This file doesn't represent the container itself -- it's more of a set of instructions on how to build the image. Actual docker images are stored, like VM images, in a [registry](https://blogs.vmware.com/cloudnative/2017/06/21/what-is-a-container-registry/). When you instruct docker to run a container, it'll pull the image from the registry, build it into a live container, and then run that built container.

##### How do I make one? 🛠

Containers are basically just an application packaged together with all of its depenencies. In order to containerize your app, you just need to specify a base image, install all of the depencies it needs, copy over whatever code (or compiled binary) you need to run, and give it a command to execute.

The [docker engine](https://docs.docker.com/engine/) takes care of all the hard stuff like isolating containers from each other, networking containers to the host operating system, attaching volumes, and that sort of thing. I mean, you have to specify the networking and storage parts, but the really tricky stuff is taken care of for you.

##### Why should I make one? 🤷🏻‍♀️

They start up fast. Like, [really fast](https://arxiv.org/pdf/1807.01842.pdf#subsection.4.3). They usually take just a second or two to boot, which is one or two orders of magnitude faster than a VM. This is a good thing because it means that as there's in increase in workload, it's much super easy to respond by spinning up some new containers instead of needing to provision some new VM's.

Using containers also allows for increased resource efficiency -- the same way you'd like to use several VM's to fully utilize the resources of a single bare-metal computer, it's nice to use several containers to fully utilize the resources of a single VM. This increase in efficiency also leads to a decrease in cost as you scale up your workloads.

#### Pods 🐟

Taken from the [Kubernetes documentation](https://kubernetes.io/docs/concepts/workloads/pods/pod/):

> _Pods_ are the smallest deployable units of computing that can be created and managed in Kubernetes [...] In terms of Docker constructs, a Pod is modelled as a group of Docker containers with shared namespaces and shared filesystem volumes.

Basically, a Pod is like an application, and it consists of one or more docker containers. Containers in a pod are both namespaced to the same `localhost`, and they are also able to access the same "filesystem volumes", which you can kind of imagine as like an external HDD for a docker container -- meaning that both containers can read from and write to the same external filesystem at the same time.

The idea is that each docker image in a pod does one single job ([something from my intro to java class is poking at my subconscious](https://en.wikipedia.org/wiki/Single-responsibility_principle)), and that each pod is a logical...i guess "application unit." Here's a diagram from the docs:

![](https://d33wubrfki0l68.cloudfront.net/aecab1f649bc640ebef1f05581bfcc91a48038c4/728d6/images/docs/pod.svg)

As you can see, even though there is one container used to pull remote files, and container used to serve the website, they are grouped together into one pod, which acts as a logical grouping of functionality needed to serve the website. In addition of "communicating" via the filesystem, these containers could also communicate over localhost.

Knowing whether or not to group multiple containers into a single pod often comes down to scaling. The advantages gained in ease of [IPC](https://en.wikipedia.org/wiki/Inter-process_communication) can often be outweighed if you often need to scale one container much more than the other.

For example, we wouldn't want to put our Icecast (audio out) and Liquidsoap (audio in) containers in the same pod, because there is at most one person ever streaming audio in, while there can be dozens of people streaming audio out -- scaling the two containers together would result in unnecessary idle Icecast instances. We _would_ however want to group a container that fetches the latest assets for the datafruits site and the container running the webserver for datafruits.fm because that functionality makes sense to encapsulate within a single pod.

Deciding what should and shouldn't be a pod is often a game of trade-offs, and is one of the talking points worth discussing before we go ahead to implementation of this RFC.

#### Services 🚃

One important thing I've glossed over here is the lifecycle of Pods within a Kubernetes cluster. In keeping with the pets-vs-cattle analogy, Pods are very cattle-ish. They are born, and they die, and we should try really hard not to care about them. Pods aren't like traditional servers, where if one goes down the app crashes. They're designed to be ephemeral, with pods spinning up and down in response to increases and decreases in workloads.

This is a feature of Kubernetes, but it also introduces a problem: how do we communicate to an application that doesn't have a definitive location? The answer is to use Services.

If a Pod is a unit of computing, a Service is a way to designate one or more types of Pods as _serving_ (lol) a certain purpose. Pods are the way you deploy applications on Kubernetes, and _Services_ are the way you link your applications together. From [the docs](https://kubernetes.io/docs/concepts/services-networking/service/#service-resource):

> In Kubernetes, a Service is an abstraction which defines a logical set of Pods and a policy by which to access them [...]

Let's take a simple example, with a webserver pod communicating with an API pod via a Service:

```
 -----------                                -----
| webserver | <----> [ apiService ] <----> | API |
 -----------                                -----
```

This may seem overly complicated -- why do we need a separate Service entity to facilitate communication between Pods? The answer is that Services allow complete decoupling of Pods from each other -- multiple different Pods can comprise a Service, and Pods belonging to a different Service don't need to (and shouldn't!) be aware of this.

Here's a more complex example to demonstrate what I mean:

<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAxcAAADxCAYAAAC51Uo+AAAGcHRFWHRteGZpbGUAJTNDbXhmaWxlJTIwaG9zdCUzRCUyMmFwcC5kaWFncmFtcy5uZXQlMjIlMjBtb2RpZmllZCUzRCUyMjIwMjAtMDctMjVUMTklM0EwNCUzQTE3LjE5M1olMjIlMjBhZ2VudCUzRCUyMjUuMCUyMChNYWNpbnRvc2gpJTIyJTIwZXRhZyUzRCUyMnlYT0J6cDBDSXhGVHg2QzZ6WDFxJTIyJTIwdmVyc2lvbiUzRCUyMjEzLjUuMyUyMiUzRSUzQ2RpYWdyYW0lMjBpZCUzRCUyMjF5WnRBQmtpMVVkbUxHT2Uwa1NQJTIyJTIwbmFtZSUzRCUyMlBhZ2UtMSUyMiUzRTdWcGJjNkl3RlA0MXpqNjFBMEd3UGxidHRwM1puZW1zRDlzJTJCcGlSZ2RnTnhRdkN5djM0VENNck5hcTBvdGI0d3lja056dmVkQ3djNjFqQlkzSE00bmZ4a0NOTU9NTkNpWTQwNkFQU052cndxd1RJVk9BNUlCVDRuS0JXWmE4R1klMkZNTmFhR2hwVEJDT0NoTUZZMVNRYVZIb3NqREVyaWpJSU9kc1hwem1NVm84ZFFwOVhCR01YVWlyMHQ4RWlVa3F2YkdOdGZ3QkUzJTJCU25Xd2FlaVNBMldRdGlDWVFzWGxPWk4xMXJDRm5US1N0WURIRVZPa3UwMHU2N3Z1RzBkV05jUnlLWFJZczRUVCUyQjRUMzBubCUyRnV1VEJSJTJGJTJCb1BIbDNwWFdhUXh2cUJPOENoY3I4QklqUFo5RlZ6U0lrNkF4aGpJbkEyTGclMkZLVGFsWk5jWjhSdHpWJTJGRmRlbmx2ZUlWR1NXR2FhNXl3T0VWWTNiOHJoJTJCVVNlUFo1Q1Y0M09KZFdrYkNJQ3FvZjFZMkF1OEdLamZzeVYxaVZiTVF1dzRFczVKVnZRczlNbG1xa2d3M2klMkJ4bjJGN2lTSGVUWVBhcXI1cTYzWGFNaUdCdVFkNElCZHdFRlFRSSUyRkhSRVRYWHJBek9KR0FyMUxSVXVFNVNEOEFrWEVVaUN5ckNKSHAxRUFFYWlCeW1vS28yeWhFUGduOXo0NFI2Tm9ueHNodURxTmJPV09nd2dxR0l1YTclMkIwYUJJM0VHMkZyV3FlM1BxY0cycENRY29sdVZDTWllUzJFVUViZW9GJTJGbnNmUG1zZFpoMFhsVG4yczY2bzBWJTJCY0xUVXZmUWdqQ3I1UTBtYk1tR0IzTWRpV3hTdWFqMm5WZnVOdU1NeGhZTE1pcmRScDJsOXdoTWpTVFRYb0haTDlwcUZ3V3lIaU1YY3hYcFJQcjhvNzFNbUJ5aUJucXFoc2xHQyUyQiUyQnFwOTZkQ3IwS0Z4OUJsUVdwbWdrUFBrOGlyN0ZGbG8wVnJMekZHR29nb2NpUVNuUDNGUTBZWmw1S1FoWExtd0NPVWxrU1FFajlVUkpNVXdGSSUyQlVPWkdaRFo1cXdjQ2dwQTZwdFpZaSUyQlo4Q0h2ZElhUHAxakNyak56QnpEWEw2dDl0cnpJWWN2RzJHUyUyQkllTTYxWHpLamxlMjFCYXRPWnNETkczNXFPdHZUNzYwT0FwelNRVmczSmNQdWxlanhXVHlFV2ZlMjB5RDdVaWFkQSUyRiUyQjZGJTJGNGRnbjkxTDNUTjhjODhGJTJGYlpGJTJGWWRnbjFXRGZ1cWJ6UlBqMmRiNGJITnRyMmFtblgxZ3dONWhGcjdOcmRZOXo1eDdJQWV3ZDdSSTZSY3ZyaUVqN3FFdXRKSWslMkZUYkhsNU9UTUR1aFlCSEplQyUyQjladTlDZGh1JTJCb0VMJTJGWTVLdjJyTmFQVmhKRW1FTmlZc3g2bTNPdjIyZmU4d2IlMkJvMHByOVR0RkZsTGNqeCUyQmhXVkpZcVNWampuU2ZYZklLRzglMkZJb2paUnF2MklWeGxFakZ0MGdwTTU1aW1Wa2JIa3pHWVlqVWxVYXFqdWt5Umx1bjh0TiUyRkZjZ08lMkJ4Smx4bE5GQVdkVGRmbTlVYURpNWZySGpRTGdhNVVGVzhPWGZUODBWVng4ZWFPbSUyQlFLT3lwZlRsdkhhd2hiTE9KQjNzY3BSWjIlMkIyeU83Njc2MTAlMkJ2b1hPT3Z1UHclM0QlM0QlM0MlMkZkaWFncmFtJTNFJTNDJTJGbXhmaWxlJTNFQG28bQAAIABJREFUeJzs3Xt0VPd5L/xv7OC0dncSO81+XXveXCa2sqqequvViXJYZzotdatyWDosLQ4HyuFFrzlw7MoUKJcmwo7AyMiYBhMol/iG8WvjU1zZVijmdQ5HQUQYggmXBgtjRchCAoRA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" />

As you can see, incoming traffic has no idea which specific Pod it's connecting to, only that whatever Pod it connects to belongs to the "Client Site" Service. Similarly, when any of the "Client Site" Pods need to make an API call, they have no idea which specific "API" Pod they're connecting to, only that the Pod belongs to the "Client Site" Service.

This model makes things like [rolling upgrades](https://searchitoperations.techtarget.com/definition/rolling-deployment), [A/B testing](A/B testing), and feature deployments trivial to implement, and they'll all be documented as code! You can also specify granular rules for each Service on how to direct traffic to allow for [canary](https://octopus.com/docs/deployment-patterns/canary-deployments) or [blue-green](https://docs.cloudfoundry.org/devguide/deploy-apps/blue-green.html) deployment strategies.

#### Ingress 🚪

Ingress is a Kubernetes Object, just like Pods and Services, and is basically a [reverse proxy](https://www.cloudflare.com/learning/cdn/glossary/reverse-proxy/) -- a router that directs incoming requests to the cluster to specific services. From [the docs](https://kubernetes.io/docs/concepts/services-networking/ingress/#what-is-ingress):

> [Ingress](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/#ingress-v1beta1-networking-k8s-io) exposes HTTP and HTTPS routes from outside the cluster to [services](https://kubernetes.io/docs/concepts/services-networking/service/) within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

This means that if your DNS is pointing requests to _https://\*.datafruits.fm_ to the IP address of the [Ingress Controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) (controllers are kind of beyond the scope of this RFC, which is already super long), then the Ingress rules will translate requests to URLs to Services.

For example, we could map _datafruits.fm_ to the "Client Site" Service, _static.datafruits.fm_ to the "Static Files" Service, and _dj.datafruits.fm_ to the "Audio Stream Input" Service.

#### Nodes 🧱

This one is really simple, I actually almost forgot to throw it in here. A [node](https://kubernetes.io/docs/concepts/architecture/nodes/) is just whatever host machine Kubernetes can run Pods on. This is usually a VM (in our case a Droplet), but can be anything that has the ability to run Container images and a couple Kubernetes-specific daemons.

If we wind up running out of resources with our cluster, we just need to add more nodes to our cluster and [DigitalOcean managed Kubernetes](https://www.digitalocean.com/products/kubernetes/) will automatically use them. In fact, we could configure DO to auto-magically scale our cluster whenever we need it. For the purposes of this RFC, we don't really need to think about nodes too much.

### Proposed Cluster Architecture 🏗

For these diagrams, I'm going to operate on the Service level. Remember, Services are how different aspects of the cluster communicate with each other, so it makes sense to think about our cluster in terms of Services instead of Pods or Containers. Because we're operating at datafruits scale, and not G\*\*\*\*e or A\*\*\*\*n scale, most of these Services will likely contain just one type of Pod anyway.

So [here's](diagrams/full.png) the proposed new architecture!

The full master plan is...hard to look at. So let's break it down by use- 🤢 user st- 🤢 user stories 🤢🤢🤮🤮

#### Listeners (fruitcakes) 🎧

Let's pretend you're a simple, lowly datafruits fan. You just saw Tony retweet "[someone] going live on datafruits" for the twenty millionth time, and you gave in and clicked the link. What kind of architecture do we need to build to provide you with the \~\~datafruits experience\~\~?

You should be able to

- View the site (in all its static glory)
- Tune in to the livestream (video & audio)
- Chat with other fruitcakes (this is now the official term btw)
- Find information on the wonderful DJs
- Listen to past broadcasts

![listener](diagrams/listener.png)

Here, we can see that there needs to be an Services for audio & video streaming, the API (for finding information about DJs), and for accessing the client site.

You'll also notice that the static files are served from outside the cluster -- many storage services, including DigitalOcean Spaces, automatically use their global CDNs to move the files closer to the end user, so it doesn't make sense to force the request into our cluster only to route it back out again.

#### DJs and VJs 💽

What about the backbone of the datafruits community, the incredible folks who actually put together music (sometimes visuals) for datafruits? Keep in mind that DJs & VJs also can do everything listeners can do, it's just that these are the things that _uniquely_ DJs and VJs can do. They need to:

- Stream audio to datafruits
- Stream video to datafruits
- Upload past broadcasts
- Schedule their shows
- Generally manage their profile

![djvj](diagrams/djvj.png)

#### Developers 👩🏻‍💻

Of course, we can't forget about people like me! There should be a way for me (or anyone involved with the coding...or anyone at all, if you like) to check on the status of the various datafruits services. I want to:

- See the current status of each component of the datafruits stack
- See a rolling window summary of various metrics (e.g. API calls, CPU usage, etc.)
- Recieve an alert (e.g. via Discord) when something goes down
- Put together queries to search through logs

![dev](diagrams/dev.png)

Holy f\*\*\* that's a lot of arrows. Essentially what it's saying though, is that we just need some kind of Service that acts like a logging aggregator so that we can keep track of all the metrics we need, and then we need some kind of dashboard to be able to look at them. And believe it or not, even _this_ diagram is oversimplified. Turns out logging in distributed systems is kind of a bitch.

#### Management 🤵🏻

As far as I know, management has basically the same needs as [DJs](#djs-and-vjs) and [Developers](#developers), except maybe more API permissions so they can do stuff like ban users from chat or add new DJs to the database. From an infrastructure point of view, though, that's kind of a moot point.

### Path to Production 👷🏻‍♀️

Whew! That was a lot. In fact, it's so much, how are we ever going to get it done?

Well, this isn't _exactly_ a greenfield project, but in some ways it is. Migrating infrastructure is always scary, so I think the best thing to do is incrementally move parts of the stack over until eventually the whole site is on Kubernetes. I currently own the domain name [swag.lgbt](https://whois.net/), so we can test things there until we're ready to roll the official datafruits.fm domain name over.

It'll cost me a few bucks a month to run the cluster, which _should_ be no problem but I might ask for some funding from the datafruits patreon to cover expenses. Or add Tony to the Digital Ocean project. We'll see.

This is the general roadmap that I think makes the most sense as a plan for gradual adoption:

1. Create the cluster
   - Spin up a blank cluster on DigitalOcean
   - Duplicate the existing datafruits.fm assets
   - Duplicate the existing datafruits.fm database
   - Create a CI/CD pipeline to automate updates to the infrastructure (Infrastructure-as-Code)
2. Set up the logging and monitoring infrastructure
3. Set up the client site (datafruits.fm)
4. Set up the chat server
5. Set up audio streaming
6. Set up video streaming
7. Set up the API
8. Set up the admin site (streampusher.com)

Because this is something that's mission critical to test thoroughly before we deploy, I plan to take a [TDD](https://www.agilealliance.org/glossary/tdd/) approach and run load tests, unit tests, and integration tests on each part of the infrastructure at every step. These will be integrated into our CI/CD so that most breaking changes are caught before we go to production. We can also set up a staging environment, and all that good stuff.

## Drawbacks 😬

This is obviously a lot of work. And there's a chance it won't really offer that much benefit over the existing infrastructure. This is great for scaling and monitoring and analytics-ing but...do we need that stuff? Do we need any part of this RFC?

Additionally, the natural next step after moving both the Streampusher and Datafruits stacks is to combine the two, bringing Streampusher under the Datafruits umbrella. This doesn't mean we can't continue to point `streampusher.com` to our cluster, and configure the Ingress to point that to the streampusher site, but it seems...excessive.

A workaround for this is that we can distribute Streampusher on its own via something like a [Helm chart](https://helm.sh/), which would allow anyone with a Kubernetes cluster to get their own version up and running with only a couple of commands. In fact, it'd probably be easier to distribute Streampusher this way.

## Alternatives ⚖️

We could go even more all-in and move everything to cloud-specific things, like [FaaS](https://medium.com/@BoweiHan/an-introduction-to-serverless-and-faas-functions-as-a-service-fb5cec0417b2) and [managed pub/sub](https://cloud.google.com/pubsub/docs/overview). The downside to this is that we tend to get locked in to specific cloud providers, and all the corporations who offer the things we need to build the site with this tooling are evil.

Alternatively, we could just...not do this. It's not like the current architecture is broken, it's more like...scattered. And not scalable. And undocumented. And unmonitored.

## Unresolved questions ❓

- I'm probably missing some parts of the functionality of the site. What (if any) am I missing?
- I tried to keep the scope of this RFC strictly focused on migration of infrastructure, and not at all on actually modifying any of the components. That being said, this is a good opportunity to test out new stuff, since we're basically gonna have a fresh playground to mess around in. Is it worth trying out anything new (e.g. modifying the liquidsoap setup, changing how the assets are stored, etc.)?
