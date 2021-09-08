---
date: 2021-09-07T21:20:00-07:00
title: Drone Running
slug: drone-runner
tags:
  - drone.io
  - continuous integration
  - programming
---

While self-hosting Git isn't *that* hard (all you need is a shell accessible through SSH), some tools make it easier.
One of them is [Gitea](https://gitea.io/), a nice, self-contained Go binary that provides you a [GitHub clone](https://docs.gitea.io/en-us/comparison/) without all the complexity and dependency hell of something like GitLab.
One of the things it does not provide is an integrated continuous integration/delivery (CI/CD) platform.
Instead, it implements the same basic patterns at GitHub allowing for pairing with a range of third-party services, cloud or hosted.

The most common CI paired with Gitea would be [Drone](https://www.drone.io/).
While there are many reasons I'm likely to discard it and try other options, I figure it's worthwhile to at least share my experience trying to make it work for me, most notably how it handles runners.

<!--more-->

## Gitea Integration Background

Before talking about how Drone functions, it's worthwhile to spend a few words to describe how's Gitea CI integration works.
On any number of repo events (new commits, pull requests, issues, etc.), Gitea can be configured with a [*webhook*](https://docs.gitea.io/en-us/webhooks/).
When any of these events occurs, Gitea will POST a JSON document to the configured URL.
In the case of a CI/CD engine, the recipient will respond by kicking off the validation process.

To gain access to the repos in question (as well as register the webhook), Drone is authenticated by [OAuth2](https://docs.gitea.io/en-us/oauth2-provider/) and runs against Gitea's [swagger-documented API](https://try.gitea.io/api/swagger).
Drone starts by posting a commit status (`/repos/{owner}/{repo}/statuses/{sha}`) to `pending` upon receipt of the webhook and will update it to a final status once the runner completes.

## Design of Drone

Drone operates on a server/runner dispatch model.
The central server receives a notification from Gitea, pulls the repo to parse the `.drone.yml` file to map out its requirements, and then enqueues it for the first available runner.

Very unlike classical solutions like Jenkins, Docker doesn't keep a list of configured pipelines or runners.
Instead, each runner will periodically query the server for work, reporting its type (e.g. `docker`, `exec`), platform (e.g. `amd64`, `linux`), and any "tags" that have been attached to the runner (e.g. special hardware or software available to the unit).

Increasing build resources or bringing new capabilities online is simply a matter of spinning up new runners and pointing them at the Drone server.
No configuration required.

## Matching Algorithm

The matching algorithm is entirely handled by the server, located in the module [`drone/scheduler/queue`](https://github.com/drone/drone/blob/v2.2.0/scheduler/queue/queue.go#L160).
First, the `kind` and `type` must match exactly, the defaults being `"pipeline"` and `"docker"`.
Second, the build's requested platform is matched against the runner's platform.
And finally, the labels are matched against each other.
If a runner matches all the requirements of a queue item, the task is dequeued and dispatched to the runner.

Looking at these steps in detail, we'll start with the platform since the kind/type-matching is exact and easy to understand.
If a runner provides an OS, architecture, CPU variant, or kernel version, it's considered a platform-specific runner.
If none of these are provided, it's considered a cross-platform runner.
Matching is all-or-nothing.
Once you specify any of them, the runner is going to be constrained on all of them.

The pipeline is always assumed to have a platform.
If it doesn't specify one, it's assumed to have an OS of `linux` and an architecture of `amd64`.
There is no way to override these defaults on a per-server or per-repo basis.
They are hardcoded into [`drone/trigger`](https://github.com/drone/drone/blob/v2.2.0/trigger/trigger.go#L406).
Once the runner has been identified as a platform-specific runner, the OS and architecture must match exactly.
Variant and kernel version are tested *only if specified by the pipeline*.
If the runner does not provide any platform information, these checks are simply skipped.

As for labels, it's dictionary equivalence.
In order for a pipeline to match up against a runner, both must have the exact same set of label names with associated values.
There is no mechanism for a runner to accept subsets or perform other forms of fuzzy matching.

Once a runner is matched to a queue item, it is *reserved* until the runner *accepts* it or the reservation times out.

## Limitations

There are a number of weaknesses I find in the Drone model as it informs my own usage:

- The architecture is very clearly focused on running everything through an off-the-shelf docker container, where the only consequential degree of freedom is *which* container to run.
  That might be acceptable for the average web app, but it's far too limiting for many applications.
- The server does not maintain registrations of its runners.
  It might accept a work item that has no matching runner and it will simply wait indefinitely instead of raising an error.
- There is no mechanism to restrict which runners are available to which repos.
  For example, the exec runner can be used by any repo able to post jobs to the associated Drone server, which will run arbitrary commands as specified in the repo's `.drone.yml` file.
  You can't even configure the runner to perform any pre-execution steps (like dropping privileges after reading its configuration so the build script can't simply spirit away the shared authentication key).
  - Drone allows one to digitally sign the `.drone.yml` file in order to permit tampering by anyone with write access to the repo.
    However, the security this provides ends once the individual has the ability to enable or disable CI on individual repos.
    The server/runner owner cannot place any restrictions.
- Platform selection is tightly controlled by the frontend.
  Under Drone, you need to specify exactly how the VM is going to be constructed with little-to-no input from the server operator.
  For comparison, GitHub actions have you just say `windows-latest` or `ubuntu-20.04` and not care *how* it is done.
- There is no way to split up the steps of a pipeline on multiple machines.
  In the embedded world, it's common for builds to be parallelized separately from the hardware-in-the-loop tests, which are constrained by the actual test hardware available to you.
- Drone does not automatically capture the build artifacts for review or deployment.

Really, where Drone fails for me is in how I would approach integration with embedded systems.
Maybe I simply lack imagination, but the older paradigm of statically configuring pipelines on the server seems more applicable.

## Hacks

On my server, I wanted fuzzier testing of the platform, especially since I run FreeBSD and not Linux.
Having to add `platform: os: freebsd` to every `.drone.yml` file would be a maintenance nightmare.

I decided to experiment with a modified copy of the drone server with loosened matching rules.
Most notably, if the pipeline does not specify an OS or architecture, then it does not care.
Ideally, the exec runner would be matched by name, which could be accomplished by adding a `name` label.

A basic diff applied against the `v2.2.0` release:

```diff
diff --git a/scheduler/queue/queue.go b/scheduler/queue/queue.go
index 8deab988..b9904623 100644
--- a/scheduler/queue/queue.go
+++ b/scheduler/queue/queue.go
@@ -164,10 +164,10 @@ func (q *queue) signal(ctx context.Context) error {
 			if w.os != "" || w.arch != "" || w.variant != "" || w.kernel != "" {
 				// the worker is platform-specific. check to ensure
 				// the queue item matches the worker platform.
-				if w.os != item.OS {
+				if item.os != "" && w.os != item.OS {
 					continue
 				}
-				if w.arch != item.Arch {
+				if item.arch != "" && w.arch != item.Arch {
 					continue
 				}
 				// if the pipeline defines a variant it must match
diff --git a/trigger/trigger.go b/trigger/trigger.go
index 18db04d0..1973306e 100644
--- a/trigger/trigger.go
+++ b/trigger/trigger.go
@@ -406,12 +406,6 @@ func (t *triggerer) Trigger(ctx context.Context, repo *core.Repository, base *co
 		if stage.Kind == "pipeline" && stage.Type == "" {
 			stage.Type = "docker"
 		}
-		if stage.OS == "" {
-			stage.OS = "linux"
-		}
-		if stage.Arch == "" {
-			stage.Arch = "amd64"
-		}
 
 		if stage.Name == "" {
 			stage.Name = "default"
```
