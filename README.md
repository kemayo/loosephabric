# LoosePhabric

This is a small, opinionated application that helps you copy/paste links from Wikimedia Phabricator and Wikimedia Gerrit into Slack, Google Docs, and other places that support paste from HTML/RTF.

## Why

As a reader, seeing something like https://phabricator.wikimedia.org/T366780 in a Google Doc or Slack adds cognitive load. Wouldn't it be nicer to see [T366780: Review Special:IPContributions from a Steward/functionary perspective](https://phabricator.wikimedia.org/T366780) instead, so you have more context about that the writer is referring to?

Similarly, for Gerrit, it's there is a lot more context in seeing [Add type rq_type column to renameuser_queue (mediawiki/extensions/CentralAuth~1042323)](https://gerrit.wikimedia.org/r/c/mediawiki/extensions/CentralAuth/+/1042323) in a Google Doc or Slack message as opposed to than https://gerrit.wikimedia.org/r/c/mediawiki/extensions/CentralAuth/+/1042323.

## How

Add `LoosePhabric` to the Applications directory and open it. In the menu bar, you can configure it to launch at login. You can also select if it should operate only on Phabricator links, Gerrit links, or both.

### Phabricator

If you copy text that looks like `T{some number}`, LoosePhabric will make a request to Phabricator to fetch the task title, and update your clipboard with a nicely formatted HTML link.

### Gerrit

If you copy the full Gerrit URL, LoosePhabric will make an API request to Gerrit to fetch the patch title, and update your clipboard with a nicely formatted HTML link.

