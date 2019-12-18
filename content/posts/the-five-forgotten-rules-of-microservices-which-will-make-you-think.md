+++
date = "2017-06-26T22:44:28+01:00"
draft = false
title = "The 5+1 forgotten rules of microservices, that will make you think"
description = "Are you really getting the benefits or just the burden of a microservices-based architecture?"
image = "/img/bees.jpg"
imagemin = "/img/bees-min.jpg"
tags = ["microservices", "best practices"]
categories = ["considerations"]
type = "post"
featured = "/bees-min.jpg"
featuredalt = "bees"
featuredpath = "img"
+++

If I would have to summarise in a single attribute what microservice adoption can give you, I would probably say, that the most important benefit of microservices is *agility*. Agility today is the number one priority for business who want to stay ahead of their competitors. That's why businesses are investing on microservices, not just to have happy hipsters around ;-).

So if implemented properly microservices are a competitive advantage, they should allow to quickly react to requirement changes and as consequence they should simply help your company to make more money.

Here is a list of rules that in my opinion deserve more attention and consideration:


## Keep it small
*How big should your microservice be?* I would say, do not try to measure its size, measure the time it would take to rewrite it. Remember microservices are hard to get right the first time, they are also likely to degrade because it's very common to add functionalities and turn them in *macro-services*. This means that you will constantly expand your microservices boundaries and soon or later you will need to shrink it back by splitting it in multiple microservices. Another reason for keeping microservices small is that you will make them easier to understand.
Rule of thumb:
*- Keep it small enough to be read and understood in one working day*
*- Keep it small enough to be rewritten in 2-4 weeks by a single dev*

## Uncoupled and autonomous
Don't forget that when you worked on a monolithic layered system, your biggest problem was code coupling and teams interdependencies. Don't share code between services and teams, if you need to share something then put it in a microservice ;-).

## Deploy independently and automatically
Do you have many microservices deployed simultaneously? It's a very common mistake, if you do this you are still in the *monolithic age*. If you need to release 2 services at the same time you are doing it wrong. Don't get me wrong you can release all your services, the important thing is that you do it sequentially and between each step you have always a working system.
*You can always release a functionality in multiple steps* and if your change is not backwards compatible you still have versioning, *bump your API version*.
VERY IMPORTANT: *Deployment should be automated* (don't I need to explain this).

## Load and performance test
Make sure your service can handle the load and measure the performance. How much load? I generally take the peak traffic and multiply by 2 or 3, but different consideration may apply. Run load and performance tests as part of your pipeline but also monitor the overall performance and capacity left in production boxes. Don't forget to configure thresholds and alerts if you want to have an effective monitoring.

## Reiterate
Software constantly moves, you need to do the same, keep improving your microservice, adopt new technologies, remove tech debts. Sounds obvious right?

More importantly don't blindly follow someone's rules, always, always, always consider your options and your constraints. Software design is, at the same time, art and science and there are no recipes to follow for being an artist or a scientist, it's hard work. So, work hard and always ask yourself _why?_ as many time as you can.
Microservices are cool but remember what was cool yesterday is considered ~~shit~~ antipattern today, so just think and be an engineer.
