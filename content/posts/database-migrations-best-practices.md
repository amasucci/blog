+++
date = "2022-01-23T22:10:34+01:00"
draft = false
title = "Database Schema Migrations - Best Practices"
description = "How to migrate DB schemas without breaking"
image = "/img/2022/01/23/db-migrations.jpg"
imagemin = "/img/2022/01/23/db-migrations-min.jpg"
tags = ["Database", "Postgres", "Liquibase", "Software Design"]
categories = ["tutorials"]
type = "post"
featured = "db-migrations.jpg"
featuredalt = "Database Schema Migrations - Best Practices"
featuredpath = "img/2022/01/23/"
+++

# Database Schema Migrations

Updating your application from time to time requires deeper changes that may affect the data layer. When you have to touch the data and your database, it’s always important to consider the impact of changes and how to minimise the risks.

For what we are going to talk today, code is not strictly necessary but it can help, plus I wanted to play a bit with Kotlin.

If you want you can watch the video I mead on youtube [Database Migrations Best Practices - Using Liquibase Kotlin Spring Boot](https://www.youtube.com/watch?v=4N2MvU0m8LM)

Ok so let me show you the code first, I created a service using Kotlin and Spring Boot.

The service is a simple ReST µservice that accepts and stores events in a database, the database structure is managed with `Liquibase`.

Let’s start with the ReST controller:

```java
package com.outofdevops.analytics

import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.net.URI
import java.util.*

@RestController
class ReSTController(val service: EventService) {

    @PostMapping("/v1.0/events")
    fun post(@RequestBody event: Event): ResponseEntity<Event> {
        val location: URI = URI.create(String.format("/v1.0/events/%s", service.create(event).id))

        return ResponseEntity.created(location).build()
    }

    @GetMapping("/v1.0/events")
    fun index(): MutableIterable<Event> = service.allEvents()

    @GetMapping("/v1.0/events/{id}")
    fun get(@PathVariable id: String): Event {
        try {
            UUID.fromString(id)
        } catch (ex: IllegalArgumentException ) {
            throw ResponseStatusException(HttpStatus.NOT_FOUND, "Event ID Not Found", ex)
        }

        return service.findEvent(id).orElseThrow { ResponseStatusException(HttpStatus.NOT_FOUND, "Event ID Not Found") }
    }

}
```

It accepts `POST` and `GET` requests to create and retrieve Events. These Events are then passed to a Service Class:

```java
package com.outofdevops.analytics

import org.springframework.stereotype.Service
import java.util.*

@Service
class EventService(val db: EventRepository) {

    fun allEvents(): MutableIterable<Event> = db.findAll()

    fun findEvent(id: String): Optional<Event> = db.findById(id)

    fun create(event: Event): Event {
        return db.save(event)
    }
}
```

and persisted using this `EventRepository` interface:

```java
package com.outofdevops.analytics

import org.springframework.data.repository.CrudRepository

interface EventRepository : CrudRepository<Event, String>{}
```

`EventRepository` is an interface for the `Event` [Data Class](https://kotlinlang.org/docs/data-classes.html):

```java
package com.outofdevops.analytics

import org.springframework.data.annotation.Id
import java.util.*

data class Event(
        @Id
        val id: UUID?,
        val name: String
)
```

The full working example can be found on GitHub [here](https://github.com/outofdevops/db-migrations). Let me know if you want me to make a video about Spring/Kotlin/JPA etc.

## Database migrations (Liquibase)

Let’s see how we manage the Database changes, the database structure is defined using Liquibase, liquibase is a library used to track and version DB changes.

Now if we go under `/resources/db/changelog/db.changelog-master.yaml`

```yaml
databaseChangeLog:
  - include:
      file: db/changelog/db.changelog-1.0.yaml
```

This file contains the list of changes applied to the database, we only have one here `db.changelog-1.0.yaml` 

```yaml
databaseChangeLog:
  - changeSet:
      id: 189456789728-4
      author: anto
      changes:
        - createTable:
            columns:
              - column:
                  defaultValueComputed: "gen_random_uuid()"
                  constraints:
                    primaryKey: true
                    primaryKeyName: event_pkey
                  name: id
                  type: uuid
              - column:
                  name: name
                  type: VARCHAR(255)
            tableName: event
```

In this file we create a table named `event`with two columns `id` and `name`.

As you can imagine you can use this to create multiple tables, and structure the database in the way you prefer.

Now this quick intro was needed to give you some context, in the previous article [API Design - Backwards and Forwards Compatibility](https://amasucci.com/posts/api-backwards-compatibility/) (you can also watch the [video on YouTube](https://www.youtube.com/watch?v=EpC6s2tisNY&t=4s)), I discussed `backward` and `forward` compatibility when designing APIs. So now we want to see how changes that affect the data layer can be handled. As for the API changes to databases can be Backwards-compatible or Backwards-incompatible.

## Backwards Compatible changes

Some backwards-compatible changes in DBs are:

- Creating a new tables
- Adding columns (except columns with a NOT_NULL constraint, in that case add a default value)
- Removing unused column

in the `db.changelog` folder there are two files that are not referenced by `db.changelog-master.yaml` one with backward compatible change:

```yaml
databaseChangeLog:
  - changeSet:
      id: 189456789728-5
      author: anto
      changes:
        - addColumn:
            tableName: event
            columns:
              - column:
                  name: created
                  type: timestamp
                  constraints:
                    nullable: false
                  defaultValueComputed: "now()"
```

in this file we are telling `Liquibase` to add a column to the table event. The column is of type `timestamp` and has a default value. Without the default value, the migration would fail because of the constraint.

When we apply this change nothing breaks and even if our service won’t return the new field it can still operate without requiring code changes.

## Backwards Incompatible changes

Classic examples of backwards-incompatible changes are:

- Rename a column
- Rename of a table

`db.changelog-1.2.yaml` contains a change that is not backward compatible:

```yaml
databaseChangeLog:
  - changeSet:
      id: 189456789728-6
      author: anto
      changes:
        - renameColumn:
            tableName: event
            newColumnName: type
            oldColumnName: name
```

When we apply this change, Liquibase doesn’t fail but our service will fail as soon we start hitting it with requests. This happens because our service doesn't know anything about the new column name and when it tries to read or write events from/to the database it fails.

## How do we apply this type of changes?

A common way is to create a multistep change:

1. Create column with a new name
2. Change the code to handle the new and old column
3. Backfill the new column
4. Change the code to only use the new column name
5. Drop the old column

This is just an example and steps may differ depending on your specific use case and technologies. So, instead of focussing on specific example I think there is more value in understanding the principles. Here are some best practices that are more generic.

## Best practices for database migrations

Here are some best practices for database migrations:

- **Rollout schema changes independently from code changes**, don’t bundle Schema changes and code changes in the same release. I also prefer to use different release processes to rollout DB changes, for two reasons:
    - **permissions:** privileges required for Schema changes are higher than the ones needed for normal operations
    - **better design:** bundled changes are impossible by design
- **Throttle the updates**, execute them in small batches as they can affect DB performance or even stop completely the access in case of locks on tables
- **Coordinate Database changes with backup schedules**, ideally we would like to execute the DB schema changes immediately after a backup
- **Wait before dropping**, make sure you have enough confidence in the change you just applied. Monitor performance and statistics before and then wait for the next backup and then drop.

Ok that’s it... 📝 Comment if you have questions, 👍🏻 like, ✍🏻 subscribe and 👋🏻 see you soon.
