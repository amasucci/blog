+++
date = "2022-01-13T17:10:34+01:00"
draft = false
title = "APIs Backwards Compatibility - How to avoid breaking changes"
description = "Successful APIs are adopted and used by thousands of clients, how can we manage changes without breaking them?"
image = "/img/2022/01/13/api-backwards-compatibility.jpg"
imagemin = "/img/2022/01/13/api-backwards-compatibility-min.jpg"
tags = ["APIs", "ReST", "Software Design"]
categories = ["tutorials"]
type = "post"
featured = "api-backwards-compatibility.jpg"
featuredalt = "api backwards compatibility"
featuredpath = "img/2022/01/13/"
+++

# APIs - Backwards Compatibility

Designing APIs is non-trivial, especially because, at design time we have limited information about their use and consumption.

Today we are going to discuss about APIs, Backwards and Forwards Compatibility... and how to version an API in case there is a need for it.

## Practical example

Let’s start with an example, lets say we have an API, something similar to Twitter, with an endpoint that returns a payload like this:

```go
[
	{
		"username": "PeterMcKinnon",
		"tweet": "Happy New Year!!!",
		"date": "2022-01-01T08:15:00Z"
	},{
		"username": "Programmer",
		"tweet": "I ❤️ GoLang" ,
		"date": "2022-01-01T08:14:00Z"
	},{
		"username": "DancingPanda",
		"tweet": "Exhausted after dancing for 4 hours!!!",
		"date": "2022-01-01T08:13:00Z"
	},{
		"username": "GingerBread",
		"tweet": "I hate 🥛",
		"date": "2022-01-01T08:12:00Z"
	}
]
```

## The Service

This service in GoLang returns exactly this:

```go
package main

import (
	"encoding/json"
	"net/http"
)

type Tweet struct {
	Username string `json:"username"`
	Tweet    string `json:"tweet"`
	Date     string `json:"date"`
}

func main() {
	http.HandleFunc("/feed", twitterFeed)
	http.ListenAndServe(":3000", nil)
}

func twitterFeed(w http.ResponseWriter, r *http.Request) {
	tweets := fetchTweets()
	js, err := json.Marshal(tweets)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(js)
}

func fetchTweets() []Tweet {
	return []Tweet{
		{"PeterMcKinnon", "Happy New Year 🎆", "2022-01-01T08:15:00Z"},
		{"Programmer", "I ❤️ GoLang", "2022-01-01T08:14:00Z"},
		{"DancingPanda", "I Love 💃🏼 Dancing", "2022-01-01T08:13:00Z"},
		{"GingerBread", "I hate 🥛", "2022-01-01T08:12:00Z"},
	}
}
```

This API is consumed by clients written in many different languages, let’s create a simple test to emulate the client consuming it.

## The Client

For simplicity and conciseness I created a test in Javascript using Mocha:

```go
let chai = require('chai');
let chaiHttp = require('chai-http');
chai.should();

chai.use(chaiHttp);
describe('Tweets', () => {
  
  describe('/GET feed', () => {
    it('it should be an array of tweets', (done) => {
      chai.request('http://localhost:3000')
          .get('/feed')
          .end((err, res) => {
            res.should.have.status(200);
            res.body.should.be.a('array');
            res.should.have.header("content-type", "application/json");
            res.body[0].should.be.a('object');
            res.body[0].should.have.property('username');
            res.body[0].should.have.property('tweet');
            res.body[0].should.have.property('date');
            done();
          });
    });
  });
});
```

If I execute this test I get:

```scala
> mocha
Tweets
    /GET feed
      ✔ it should be an array of tweets

  1 passing (23ms)
```

🎉  We have a “Client” compatible with our API that can consume it.

### Fast forward a couple of months

Now we have our API serving millions of customers, and hundreds of developers around the world developed clients and applications to interact with it.

This is amazing 🤩  and at the same time terrifying 😱  because now any change to the API can have an impact on our clients and on our business.

So, if we change our API, we can risk breaking all our customers, let’s see now how this can be avoided.

## Backwards and Forwards Compatibility

Back to the code... we need new implement new features, we want to add the number of 👍🏻  **likes** we received for each tweet.

```go
type Tweet struct {
	Username string `json:"username"`
	Tweet    string `json:"tweet"`
	Date     string `json:"date"`
	Likes    int    `json:"likes"`
}
```

We have added a new property to our payload and haven’t touched anything else, and when we run our tests:

```scala
> mocha
Tweets
    /GET feed
      ✔ it should be an array of tweets

  1 passing (23ms)
```

All good, nothing broke!!! Customers and business are happy.

The change we have just done is a non-breaking change and falls into the category of backwards-compatible changes.

### Backwards-Compatible changes

A backwards-compatible change to an API is a change that when applied doesn’t have any impact on clients created for a previous version of that API.

In general, the following are Backwards Compatible changes:

- Adding a new method/endpoint to an API
- Adding new fields to request/response messages
- Adding new query parameters

Instead, these are common **Backwards-incompatible** changes:

- Renaming an API method/endpoint
- Renaming fields in request/response
- Changing types for fields in request/response
- Changing the status codes
- Changing headers (”content-type” etc...)

It is advisable when possible to implement **backwards-compatible** changes, but is not always possible.

{{< rawhtml >}}
<figure style="white-space:pre-wrap;display:flex;background: rgba(241, 241, 239, 1);border-radius: 3px;padding: 1rem;" id="f9fabd1f-5b46-4239-bedd-c622fa8f6eb5"><div style="font-size:1.5em"><span class="icon">💡</span></div><div style="width:100%">Forwards-Compatible changes:
We said that: an API is Backwards-Compatible when changes won’t break the previous version of the client. Instead, an API is Forwards-Compatible when clients designed for a more recent version can also work with previous versions of that API. An API is forward compatible when it is less strict (more liberal) with the requests received.</span></div></figure>
{{< /rawhtml >}}

## Backwards Incompatibility

**Backwards-Compatible** changes should be the preferred way but as we said it’s not always possible. Sometimes we don’t have alternatives and we have to introduce a breaking change.

When this happens we have two options, we could use an approach called ***expand and contract*** or we could ***“bump”*** the version of the API.

### Expand and Contract

Essentially, in the case of renaming request/response fields (a breaking change), instead of directly modifying the request/response we **“expand”** the request/response by adding a field (a non-breaking change).

{{< rawhtml >}}
<figure style="white-space:pre-wrap;display:flex;background: rgba(241, 241, 239, 1);border-radius: 3px;padding: 1rem;" id="f9fabd1f-5b46-4239-bedd-c622fa8f6eb5"><div style="font-size:1.5em"><span class="icon">💡</span></div><div style="width:100%">In some cases adding a new field is not practical and may be necessary to create a new method that can operate with the updated request/response.</span></div></figure>
{{< /rawhtml >}}

Back to our code, we want to rename the filed `tweet` → `body`. So, we ***“expand”*** our response with a new field

```go
package main

import (
	"encoding/json"
	"net/http"
)

type Tweet struct {
	Username string `json:"username"`
	Tweet    string `json:"tweet"`
  Body     string `json:"body"` //ADDING NEW FIELD INSTEAD OF RENAMING TWEET
	Date     string `json:"date"`
}

func main() {
	http.HandleFunc("/feed", twitterFeed)
	http.ListenAndServe(":3000", nil)
}

func twitterFeed(w http.ResponseWriter, r *http.Request) {
	tweets := fetchTweets()
	js, err := json.Marshal(tweets)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(js)
}

func fetchTweets() []Tweet {
	return []Tweet{
    //RETURN BOTH FIELDS UNTIL CLIENTS MIGRATE TO NEW CONTRACT
		{"PeterMcKinnon", "Happy New Year 🎆", "Happy New Year 🎆", "2022-01-01T08:15:00Z"},
		{"Programmer", "I ❤️ GoLang", "I ❤️ GoLang", "2022-01-01T08:14:00Z"},
		{"DancingPanda", "I Love 💃🏼 Dancing", "I Love 💃🏼 Dancing","2022-01-01T08:13:00Z"},
		{"GingerBread", "I hate 🥛", "I hate 🥛","2022-01-01T08:12:00Z"},
	}
}
```

So, now we have to wait for clients to migrate to the new field name, and then **we can execute the contract phase** where we decommission the deprecated field. 

This approach allows to temporarily preserve Backwards and Forwards Compatibility.

{{< rawhtml >}}
<figure style="white-space:pre-wrap;display:flex;background: rgba(241, 241, 239, 1);border-radius: 3px;padding: 1rem;" id="f9fabd1f-5b46-4239-bedd-c622fa8f6eb5"><div style="font-size:1.5em"><span class="icon">💡</span></div><div style="width:100%">It is encouraged for private APIs, where you have full control over the clients using it, and not recommended for public APIs where will be impossible to migrate 100% of the clients and execute the contract phase.</span></div></figure>
{{< /rawhtml >}}

### Version “bump”

Bumping the version of an API is another way to introduce changes to an API without impacting clients.

Two common ways of versioning APIs are:

- Path-based versioning (or URL versioning)
- Header based versioning

**Path-based versioning -** when the version of the api is defined as part of the path:

```bash
/**v1**/feed
/**v2**/feed
```

**Header based versioning** - can be done using custom headers:

```bash
Accepted-version: v1
Accepted-version: v2
```

or standard headers:

```bash
Accept: application/vnd.tweets+json;version=1.0
Accept: application/vnd.tweets+json;version=2.0
```

With version bumping you can create a new API version without affecting the clients of the old version. 

Version bumping and “expand and contract” will both require a deprecation period, during this period

{{< rawhtml >}}
<figure style="white-space:pre-wrap;display:flex;background: rgba(241, 241, 239, 1);border-radius: 3px;padding: 1rem;" id="f9fabd1f-5b46-4239-bedd-c622fa8f6eb5"><div style="font-size:1.5em"><span class="icon">💡</span></div><div style="width:100%">I<span style="border-bottom:0.05em solid">t is important to collect stats on usage of versions, to decommission the deprecated methods/versions.</span></div></figure>
{{< /rawhtml >}}


## Conclusions

Designing APIs is hard, nailing it at the first attempt is even harder. So we have to accept the fact that our APIs will change and that changes can affect both clients and business.

As software engineers, our job is to minimise the risks of changes and today we went through some of the most common techniques to do that.

{{< rawhtml >}}
<figure style="white-space:pre-wrap;display:flex;background: rgba(241, 241, 239, 1);border-radius: 3px;padding: 1rem;"><div style="font-size:1.5em"><span class="icon">🌯</span></div><div style="width:100%"> The takeaway: backward compatible changes are obviously preferred but not always possible. If a breaking change is needed, consider Expand and Contract for situations where you can execute the contract phase, and “bump” the version otherwise.</span></div></figure>
{{< /rawhtml >}}

Have Fun!!!