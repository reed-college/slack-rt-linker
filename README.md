# slack-rt-linker
A scrip to post and update Slack messages linked to BestPractical RT tickets.


## Installation & Config
### Slack App
1. Create a Slack App: https://api.slack.com/apps 
  1. From Scratch
  2. Add features and functionality
    * Permissions > Scopes > Bot Token Scopes: channels:read, chat:write
    * Permissions > Scopes > OAuth Tokens for Your Workspace > Install to Workspace
    * Bots > Messages Tab
  3. Install your app



### RT Scrip & CF
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
  set your $slackURL, rtURL, $token
  find the slack channel IDs and configure queue -> channel mapping
    In slack, right click the channel, copy link, past it somewhere.  The id is at the end.  Looks something like this: "C011AAXXXX"
4. Apply the scrip to the desired RT queues.
5. Invite your Slack App to the desired channels.

