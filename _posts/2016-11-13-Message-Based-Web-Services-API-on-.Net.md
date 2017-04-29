---
layout: post
title: Message Based Web Services API on .NET
date: 2016-11-13T07:00:01.000Z
summary: "Does it worse for web services API to use message based approach?"
categories: DDD, REST, API, MessageBased
published: false
---

There are not so many resources/tools/discussions on creating message based APIs as we have for REST APIs. For REST you can find huge amount of articles/styleguides/awsomelists/builtin tools for popular frameworks for all languages. 

When you search about message based web services API you can find only individual attempts or one huge like Amazon's [AWS](https://aws.amazon.com/ru/documentation/). I don't mean here message queues/service buses, I only want to take a look on web services API from non-REST perspective. 

A decade ago we used a lot RPC over XML, then over JSON, SOAP. REST with it's incredibly simple rules and self-descriptive, meaningful API spread all over the world. With growth of system's complexity, invented new languages we've got new requirements for API design: 
 - it should be easy for systems to talk to each other, 
 - API should be self-discoverable (like JSON-API), 
 - documentation should be generated on the fly,
 - be closer to hardware

gRPC
https://habrahabr.ru/company/infopulse/blog/265805/

Criterias for public HTTP API:
- fast learning curve: you should predict API method based on what you need
- one simple language to rule them
- good tooling: for server developers - to write and test, for client developers - to create clients, extend, get diffs, validation

Criterias for loaded environments (chats/MMRPG/event based/real time):
- size: binary TCP/protobuf and CO
- batching
- offline

I'm going to take a look on my area only - on .NET.

## Message Based:
- CQRS
- dumb simple routing: single endpoint and action
- simple offline mode
- batch sending/batch processing - great advantage from actor model or Disruptor
- microservice oriented: simple dispatching to other service/servicebus
- like SQL journals: can be replayed - linked to CQRS/ES

 
## REST:
- Simple and readable URLs: easy to write/predict required url
- full use of routing/ http verbs
- style guides/community support
- incredible documentation support: swagger/RAML
- including builtin framework support (and for docs too)
- can be backed with message based
- resources as aggregate roots
- all verbs - from context /users/1/questions

http://www.slideshare.net/yuliafast/restful-api-net
Что читать? https://github.com/OData http://www.odata.org/ http://dontpanic.42.nl/2012/04/rest-and-ddd-incompatible.html http://www.dataart.ru/blog/2016/02/podhody-k-proektirovaniyu-restful-api/ https://msdn.microsoft.com/en-us/magazine/dn451439.aspx http://martinfowler.com/bliki/CQRS.html http://www.telerik.com/odata http://semver.org/ https://github.com/climax-media/climax-web-http 

Gygant using message based: amazon
service stack/ paramore/ boggard with MediatR/ Nelibur

https://github.com/ServiceStack/ServiceStack/wiki/Advantages-of-message-based-web-services#advantages-of-message-based-designs
http://docs.servicestack.net/redis-mq

what lacks: 
- tooling
- contract doesn't describe semantics

It's dumb simple to 
- expose samples API like postman, or even automatically export to POSTMAN,
- expose test API with contract validation enabled: override auth, register default handler
