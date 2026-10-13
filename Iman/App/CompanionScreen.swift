import SwiftUI

struct CompanionScreen:View {
 @StateObject private var mac=MacConnection()
 @StateObject private var voice=VoiceInput()
 @StateObject private var handsFree=HandsFreeSession()
 @Environment(\.scenePhase) private var phase
 @State private var connection=false
 @State private var keyboard=false
 @State private var draft=""
 @State private var awake=false
 var body:some View {
  GeometryReader { geometry in
   ScrollView {
   VStack(spacing:8){
    HStack {
     Text("Iman").font(.system(.headline,design:.rounded));Spacer()
     Button{connection=true}label:{Image(systemName:mac.paired ? "link.circle.fill":"link.circle").font(.title2)}.accessibilityLabel("Connect to Mac")
    }.padding(.horizontal,24)
    Spacer(minLength:0)
    ImanFace(emotion:voice.listening ? "listening":mac.reaction).frame(height:max(100,geometry.size.height*(keyboard || !draft.isEmpty || voice.active ? 0.28:0.55)))
     .contentShape(Rectangle()).onTapGesture{microphone()}
    Text(voice.listening ? "Listening…":mac.status).font(.system(.title3,design:.rounded)).multilineTextAlignment(.center).lineLimit(4).padding(.horizontal,24)
    if !voice.error.isEmpty{Text(voice.error).font(.caption).foregroundStyle(.orange).padding(.horizontal,24)}
    Spacer(minLength:0)
    if keyboard || !draft.isEmpty || voice.active {
     TranscriptReview(draft:$draft,capturing:voice.active,finalizing:voice.finalizing,
      canSend:mac.paired && !mac.busy,alternatives:reviewAlternatives,send:sendDraft,retry:recordAgain,discard:discardDraft)
      .padding(.horizontal,20)
    }
    HStack(spacing:30){
     Button{handsFree.setEnabled(false);voice.stop();keyboard=true}label:{Image(systemName:"keyboard").font(.title2)}.accessibilityLabel("Type a message")
     Button(action:microphone){Image(systemName:voice.listening ? "stop.circle.fill":"mic.circle.fill").font(.system(size:62))}.accessibilityLabel(voice.listening ? "Finish listening":"Talk to Iman").disabled(mac.busy || voice.preparing || voice.finalizing)
     if mac.busy{Button{mac.stop()}label:{Image(systemName:"stop.fill").font(.title2)}.accessibilityLabel("Stop request")}
     else{Button{awake.toggle();updateAwake()}label:{Image(systemName:awake ? "sun.max.fill":"moon").font(.title2)}.accessibilityLabel(awake ? "Allow screen sleep":"Keep screen awake")}
    }.padding(.bottom,12)
    Toggle("Hands-free · Hi Iman",isOn:Binding(get:{handsFree.enabled},set:{handsFree.setEnabled($0)}))
     .disabled(!mac.paired).padding(.horizontal,24).accessibilityHint("Listens on this device while Iman is open, then pauses for you to review your words.")
    if handsFree.enabled {
     Toggle("Send automatically after a pause",isOn:$handsFree.sendAutomatically)
      .font(.caption).padding(.horizontal,24)
    }
    if handsFree.enabled || !handsFree.status.isEmpty{Text(handsFree.status).font(.caption).multilineTextAlignment(.center).padding(.horizontal,24)}
    Text(mac.busy ? "Working on your Mac" : handsFree.enabled ? (handsFree.sendAutomatically ? "Hi Iman + request · Automatic send on":"Hi Iman + request · Review before sending") : "Tap to talk · Review your words · Send").font(.caption2).foregroundStyle(.secondary)
   }.padding(.vertical,12).frame(minHeight:geometry.size.height)
   }.scrollDismissesKeyboard(.interactively)
  }.background(LinearGradient(colors:[Color(red:0.02,green:0.04,blue:0.09),Color(red:0.02,green:0.12,blue:0.20)],startPoint:.top,endPoint:.bottom).ignoresSafeArea())
   .foregroundStyle(.white).tint(.cyan).preferredColorScheme(.dark)
   .sheet(isPresented:$connection){ConnectionScreen(mac:mac)}
   .onAppear{handsFree.configure(voice:voice,mac:mac)}
   .onChange(of:voice.text){draft=$0;handsFree.heard($0)}
   .onChange(of:handsFree.review){if let text=$0{draft=text}}
   .onChange(of:voice.active){handsFree.captureChanged($0)}
   .onChange(of:mac.busy){busy in if busy && handsFree.enabled{draft=""};handsFree.busyChanged()}
   .onChange(of:mac.paired){paired in if !paired{handsFree.setEnabled(false)}}
   .onChange(of:phase){value in handsFree.setForeground(value == .active);if value != .active{voice.stop()};updateAwake()}
   .onDisappear{handsFree.setEnabled(false);voice.stop();UIApplication.shared.isIdleTimerDisabled=false}
 }
 private func microphone(){
  if handsFree.enabled{handsFree.setEnabled(false);return}
  guard mac.paired else{connection=true;return}
  if voice.listening{voice.finish()}else if !voice.active{Task{await voice.start()}}
 }
 private var reviewAlternatives:[String]{
  let options=voice.alternatives.map{value -> String in
   guard handsFree.review != nil else{return value}
   var gate=WakePhrase();gate.update(value);return gate.consume() ?? value
  }
  return TranscriptOptions.unique(options,excluding:draft)
 }
 private func sendDraft(){
  guard mac.paired,!mac.busy,!voice.active,!draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return}
  voice.stop();handsFree.dismissReview(resumeListening:false);mac.send(draft);draft=""
 }
 private func recordAgain(){
  guard !mac.busy,!voice.active else{return}
  draft=""
  if handsFree.enabled{handsFree.dismissReview()}else{Task{await voice.start()}}
 }
 private func discardDraft(){draft="";keyboard=false;handsFree.dismissReview()}
 private func updateAwake(){UIApplication.shared.isIdleTimerDisabled=awake && phase == .active}
}

private struct ConnectionScreen:View {
 @ObservedObject var mac:MacConnection
 @Environment(\.dismiss) private var dismiss
 @State private var code=""
 @State private var scanning=false
 var body:some View {
  NavigationStack {
   Form {
    Section("Your Mac"){
     Text("On the Mac, open Iman → Connect iPhone. Scan its code here. Both devices need the same Wi-Fi.")
     Button("Scan Mac code"){scanning=true}.disabled(mac.busy)
     SecureField("Or paste native pairing code",text:$code).textInputAutocapitalization(.never).autocorrectionDisabled()
     Button("Connect"){pair(code)}.disabled(code.isEmpty || mac.busy)
     Text(mac.status).font(.callout)
    }
    Section {
     Text("Your commands go directly to your Mac. Speech uses on-device English recognition when available. No model is downloaded to this phone.")
     Text("Pairing lasts up to 8 hours. Reopening the app or restarting the Mac connection requires a new code.")
     if mac.paired{Button("Disconnect",role:.destructive){Task{await mac.disconnect()}}.disabled(mac.busy)}
    }.font(.caption)
   }.navigationTitle("Connect Iman").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}
    .sheet(isPresented:$scanning){CodeScanner{value in scanning=false;pair(value)}.ignoresSafeArea()}
  }
 }
 private func pair(_ value:String){Task{await mac.pair(value);if mac.paired{dismiss()}}}
}
