# slack-rt-linker
A scrip to post and update Slack messages linked to BestPractical RT tickets.
New tickets with their Requestor, ID, and Subject, no Owner:
![slack-rt-take](https://user-images.githubusercontent.com/20231630/139367223-015785e2-b74a-498c-915b-3c33f0daf23a.jpg)

Ticket is updated when Taken.  If ticket is moved to another queue a new message is posted in the new queue.
![slack-rt-steal](https://user-images.githubusercontent.com/20231630/139367251-23d625f4-e906-48fe-bc64-9975d342621c.jpg)

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

