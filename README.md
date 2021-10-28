# slack-rt-linker
A scrip to post and update Slack messages linked to BestPractical RT tickets.


## Installation & Config
1. Create a "slack_timestamp" Custom Field in your RT instance.  Apply it whichever queues you will use with this scrip.
2. Create a scrip:
  * Basics
    * Condition: User Defined
    * Action: User Defined
    * Template: Blank
  * Custom condition: Paste code from the CustomCondition file.
  * Custom action preparation code: Paste code from the CustomActionPrep file.
  * Custom action commit: Paste code from CustomActionCommit file.
3. Configure it
  * set your $slackURL, rtURL, $token
  * find the slack channel IDs and configure queue -> channel mapping
    * In slack, right click the channel, copy link, past it somewhere.  The id is at the end.  Looks something like this: "C011AAXXXX"

