Botkit = require('botkit')
stats = require('measured').createCollection()
heartbeats = require('heartbeats')


HEART_REGISTER_COUNT = 4
HEART_MISSED_BEAT_ALERT_AFTER=3
###
check out http://davestevens.github.io/slack-message-builder/
###

# Expect a SLACK_TOKEN environment variable
slackToken = process.env.SLACK_TOKEN

if !slackToken
  console.error 'SLACK_TOKEN is required!'
  process.exit 1

controller = Botkit.slackbot()
bot = controller.spawn
  token: slackToken
  debug: true

bot.startRTM (err, bot, payload) -> if err then throw new Error('Could not connect to Slack')

controller.on 'bot_channel_join', (bot, message) -> bot.reply message, 'I\'m here!'

controller.hears '.*beat (.*)', ['ambient', 'mention', 'direct_message', 'direct_mention'], (bot, message) ->
  beat = message.match[1]
  if beat of heartbeats.hearts is true
    pulse = heartbeats.hearts[beat].pulse('beat')
    pulse.beat()
  else if beat of stats.toJSON() is false
    bot.reply message, '<@' + message.user + '> thnx for checking in your first beat of ' + beat
  else if stats.toJSON()[beat].count is HEART_REGISTER_COUNT
    rate = register_beat beat, stats.toJSON()[beat]
    bot.reply message, '<@' + message.user + '> time to create heartbeat for ' + beat + ' with rate ' + rate
  #else
  #  bot.reply message, 'debug: doing nothing'
  stats.meter(beat).mark();

controller.hears 'stats', ['direct_message', 'direct_mention'], (bot, message) ->
  bot.reply message, "your stats: " + JSON.stringify(stats.toJSON(), null, 4)

controller.hears 'help', ['direct_message', 'direct_mention'], (bot, message) ->
  help = 'I will respond to the following messages: \n' + '`beat` <name>\n' + '`stats` to see some internal stats\n' + '`bot help` to see this again.'
  bot.reply message, help


controller.hears '.*', ['direct_message', 'direct_mention'], (bot, message) ->
  bot.reply message, 'Sorry <@' + message.user + '>, I don\'t understand. \n'
  return

register_beat = (name, stat) ->
  rate = Math.ceil(1/stat.mean)
  console.log "going to register autobeat ", name, rate, "rate?",
  beat = heartbeats.createHeart(rate * 1000, name)
  beat.createPulse('beat')
  beat.createEvent 1, (heartbeat, last) ->
    #console.log "event heartbeat", heartbeat, this.heart
    console.log "missed beats?", this.heart.pulse('beat').missedBeats, "lag", this.heart.pulse('beat').lag
    if this.heart.pulse('beat').missedBeats > HEART_MISSED_BEAT_ALERT_AFTER
      bot.say
        text: '<!channel> HUSTON, we are missing beats (' + this.heart.pulse('beat').missedBeats + ') for ' + name
        channel: 'C0P5UTCFN'
      # reset stuff
      this.heart.kill()
      delete heartbeats.hearts[name]
      stats.meter(name).end() #.unref() #FIXME: this is a hack
      delete stats._metrics[name]

  rate

#
# controller.hears [ 'attachment' ], ['direct_message', 'direct_mention'], (bot, message) ->
#   text = 'Beep Beep Boop is a ridiculously simple hosting platform for your Slackbots.'
#   attachments = [ {
#     fallback: text
#     pretext: 'We bring bots to life. :sunglasses: :thumbsup:'
#     title: 'Host, deploy and share your bot in seconds.'
#     image_url: 'https://storage.googleapis.com/beepboophq/_assets/bot-1.22f6fb.png'
#     title_link: 'https://beepboophq.com/'
#     text: text
#     color: '#7CD197'
#   } ]
#   bot.reply message, { attachments: attachments }, (err, resp) ->
#     console.log err, resp
