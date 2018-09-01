- Start Date: 2018-09-01
- RFC PR: (leave this empty)

# Studio phone

## Summary

Add a button on the site to call the 'studio phone'. This in-browser phone call
can be routed to the current DJs phone, or just leave a voice message if no one
picks up.

## Motivation

Provide another way for listeners to interact with the DJ.

## Detailed design

Use a twilio number to receive calls.

DJs can register their phone number on Streampusher, and the number will
redirect calls to the DJ's phone automatically if they are currently streaming
live.

If there is no live DJ playing, the call will go to a voice mailbox that
everyone can listen to via an interface on Streampusher.

## Drawbacks

Twilio is quite expensive and the bill can add up quite fast, as I've learned
from using it on the Datafruits coast 2 coast show before.

## Alternatives

TBD

## Unresolved questions

TBD
