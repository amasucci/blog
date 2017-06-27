+++
date = "2017-06-27T09:44:28+01:00"
draft = false
title = "The 5+1 forgotten rules of microservices, which will make you think"
image = "/img/bees-min.jpg"
tags = ["microservices", "best practices"]
categories = ["considerations"]

+++
![Bees](/img/bees-min.jpg)

If I would have to summarise in a single attribute what microservice adoption can give you, I would probably say, that the benefit number one of microservices is *agility*. Agility today is the number one priority for business who want to stay ahead of their competitors.

Never forget that the software you write everyday is fuelling your company's business, microservices should simply help your company to make more money. So ask yourself why my company is investing in this microservices, just to make hipsters happy?

Forgotten rules:

## Keep it small
How big should your microservice be? I would say, do not try to measure its size, measure the time it would take to rewrite it. Remember microservices are hard to get right the first time, they are also likely to degrade because it's very common to add functionalities and turn them in macroservice. This means that you will constantly expand your microservices boundaries and soon or later you will need to shrink it back by splitting it in multiple microservices. Another reason for keeping microservices small is that you will make them easier to understand.
Rule of thumb:
Keep it small enough to be read and understood in one working day
Keep it small enough to be rewritten in 2-4 weeks by a single dev

## Uncoupled and autonomous
Don't forget that when you worked on a monolithic layered system, your biggest problem was code coupling and teams interdepencies. Don't share code between services and teams, if you need to share something then put it in a microservice ;-). Example

## Deploy independently and automatically
Many microservices deployed simultaneously? It's a very common mistake, if you do this you are still in the monolithic age. Microservices are hard to release, so any manual step should be automated.


## Load and performance test
Make sure your service can handle the load and measure the performance. How much load? I generally take the peak traffic and multiply by 2 or 3.
Run this tests as part of your pipeline but you also monitor the overall performance and capacity left in production environment.

## Reiterate
Software constantly moves, you need to do the same, keep improving your microservice, adopt new technologies, remove tech debts.

More importantly don't blindly follow someone's rules, always, always, always consider your options and your constraints. Software design is, at the same time, art and science and there are no recipes to follow for being an artist or a scientist, it's hard work. So, work hard and always ask yourself _why?_ as many time as you can.
Microservices are cool but remember what was cool yesterday is considered ~shit~ antipattern today, so just think and be an engineer.
