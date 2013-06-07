# PubNub
pubnub = PUBNUB.init
  publish_key: 'pub-c-e26bd37f-0e9b-49db-a2d0-3ce7dada8563'
  subscribe_key: 'sub-c-4860a7f8-ced1-11e2-b70f-02ee2ddab7fe'

uuid = pubnub.uuid()
console.log uuid

# Signaling channel
createSignalingChannel = () ->
  signaler = {}

  pubnub.subscribe
    channel: 'signaler'
    callback: (msg) ->
      msg = JSON.parse(msg)
      if msg.uuid != uuid
        signaler.onmessage msg unless not signaler.onmessage

  signaler.send = (msg) ->
    msg.uuid = uuid
    console.log "sending", msg
    msg = JSON.stringify(msg)
    pubnub.publish
      channel: 'signaler'
      message: msg

  return signaler

# Load up local get user media
selfView = document.querySelector '#local'
localStream = null
navigator.webkitGetUserMedia { audio: true, video: true }, (stream) ->
  selfView.src = URL.createObjectURL stream
  selfView.play()
  localStream = stream

# Make Peer Connection
signalingChannel = createSignalingChannel()
pc = null
dc = null
configuration = null
remoteView = document.querySelector '#remote'
iceCandidates = []

gotDescription = (desc) ->
  pc.setLocalDescription desc
  signalingChannel.send { "sdp": desc }

start = (isCaller) ->
  pc = new webkitRTCPeerConnection(configuration, {optional:[{RtpDataChannels:true}]})
  pc.addStream localStream
  dc = pc.createDataChannel "mylabel", { reliable: false }

  dc.onmessage = (event) ->
    console.log "Got message: #{event.data}"

  pc.onicecandidate = (evt) ->
    signalingChannel.send { "candidate": evt.candidate }

  pc.onaddstream = (evt) ->
    console.log "Got stream"
    remoteView.src = URL.createObjectURL evt.stream
    remoteView.play()

    sendMessage = () ->
      dc.send 'Hello World!'
    setTimeout sendMessage, 10000

  if isCaller
    pc.createOffer gotDescription

signalingChannel.onmessage = (evt) ->
  signal = evt
  wasPc = pc isnt null

  if !pc
    start(false)
  
  console.log signal
  if signal.sdp
    pc.setRemoteDescription new RTCSessionDescription(signal.sdp)

    for candidate in iceCandidates
      pc.addIceCandidate(new RTCIceCandidate(candidate))
      
    if not wasPc
      pc.createAnswer gotDescription
  else
    if pc.remoteDescription?
      pc.addIceCandidate(new RTCIceCandidate(signal.candidate))
    else
      iceCandidates.push signal.candidate

document.querySelector('#start').onclick = (evt) ->
  start(true)
