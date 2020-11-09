- Start Date: (fill me in with today's date, 2018-08-28)
- RFC PR: (leave this empty)

# Use a gif service instead of parsing image urls

## Summary

Use a gif service (like GIPHY,etc.) to display gifs. Users can search by term
and select a gif to post to the chat.

## Motivation

Have more control over what images will be displayed in chat, prevent disturbing
gifs or images from being sent.

## Detailed design

You can search gifs with a term, click on one and it will be sent to the chat.
Image URLs will not automatically display an image anywhere. The 'images on/off'
button can either be removed, or replaced with 'gifs on/off.

## Drawbacks

It won't be possible to display any arbitrary image in the chat anymore.

## Alternatives

TBD

## Unresolved questions

Which gif service is best? Should we roll our own?
