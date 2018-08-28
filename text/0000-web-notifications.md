- Start Date: 08282018
- RFC PR: (leave this empty)

# Desktop Notifications

## Summary

Opt-in to desktop notifications whenever someone goes live on Datafruits. Also
perhaps when new podcasts are uploaded.

## Motivation

Listeners might not have datafruits open all the time, but they want to know
when someone goes live on air. They might not realize a show is live if they are
not paying attention to twitter, etc.

## Detailed design

When a DJ connects, send out a notification something like "DJ xxx is live
now!", clicking on the notification opens datafruits.fm in a new tab.

This is fairly easy to implement with the notifications API.
https://developer.mozilla.org/en-US/docs/Web/API/notification

## Drawbacks

It might annoy some users, even if they are opt-in. I know I personally get a
bit annoyed anytime a website has a pop-up asking to enable notifications the
first time I visit it. Is there a less intrusive way to ask the user for notifications to
be enabled?

Also this is mainly useful because there are only 1-2 shows a day right now, if
the timetable becomes more full in the future it could become even more
intrusive.

## Alternatives

Email notifications?

## Unresolved questions

Would this be nice for notifying new podcasts have been uploaded as well?
