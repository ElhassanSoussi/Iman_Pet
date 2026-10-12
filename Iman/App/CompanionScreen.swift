import SwiftUI

struct CompanionScreen:View {
 @StateObject private var mac=MacConnection()
 @StateObject private var voice=VoiceInput()
 @Environment(\.scenePhase) private var phase
 @State private var connection=false
 @State private var keyboard=false
 @State private var draft=""
 @State private var awake=false
 var body:some View {
  GeometryReader { geometry in
   VStack(spacing:8){
    HStack {
     Text("Iman").font(.system(.headline,design:.rounded));Spacer()
     Button{connection=true}label:{Image(systemName:mac.paired ? "link.circle.fill":"link.circle").font(.title2)}.accessibilityLabel("Connect to Mac")
    }.padding(.horizontal,24)
    Spacer(minLength:0)
    ImanFace(emotion:voice.listening ? "listening":mac.reaction).frame(maxHeight:geometry.size.height*0.62)
     .contentShape(Rectangle()).onTapGesture{microphone()}
    Text(voice.listening ? "Listening…":mac.status).font(.system(.title3,design:.rounded)).multilineTextAlignment(.center).lineLimit(4).padding(.horizontal,24)
    if !voice.error.isEmpty{Text(voice.error).font(.caption).foregroundStyle(.orange).padding(.horizontal,24)}
    Spacer(minLength:0)
    if keyboard || !draft.isEmpty {
     HStack(alignment:.bottom){
      TextField("Say or type something…",text:$draft,axis:.vertical).lineLimit(1...3).textFieldStyle(.plain)
       .onChange(of:draft){value in if value.count>600{draft=String(value.prefix(600))}}
      Button{voice.stop();mac.send(draft);draft=""}label:{Image(systemName:"arrow.up.circle.fill").font(.title)}
       .disabled(!mac.paired || mac.busy || voice.listening || voice.preparing || draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
     }.padding(16).background(.white.opacity(0.07),in:RoundedRectangle(cornerRadius:22)).padding(.horizontal,20)
    }
    HStack(spacing:30){
     Button{keyboard.toggle()}label:{Image(systemName:"keyboard").font(.title2)}.accessibilityLabel("Type a message")
     Button(action:microphone){Image(systemName:voice.listening ? "stop.circle.fill":"mic.circle.fill").font(.system(size:62))}.accessibilityLabel(voice.listening ? "Finish listening":"Talk to Iman").disabled(mac.busy || voice.preparing)
     if mac.busy{Button{mac.stop()}label:{Image(systemName:"stop.fill").font(.title2)}.accessibilityLabel("Stop request")}
     else{Button{awake.toggle();updateAwake()}label:{Image(systemName:awake ? "sun.max.fill":"moon").font(.title2)}.accessibilityLabel(awake ? "Allow screen sleep":"Keep screen awake")}
    }.padding(.bottom,12)
    Text(mac.busy ? "Working on your Mac" : "Tap to talk · Review your words · Send").font(.caption2).foregroundStyle(.secondary)
   }.padding(.vertical,12)
  }.background(LinearGradient(colors:[Color(red:0.02,green:0.04,blue:0.09),Color(red:0.02,green:0.12,blue:0.20)],startPoint:.top,endPoint:.bottom).ignoresSafeArea())
   .foregroundStyle(.white).tint(.cyan).preferredColorScheme(.dark)
   .sheet(isPresented:$connection){ConnectionScreen(mac:mac)}
   .onChange(of:voice.text){draft=$0}
   .onChange(of:phase){value in if value != .active{voice.stop()};updateAwake()}
   .onDisappear{voice.stop();UIApplication.shared.isIdleTimerDisabled=false}
 }
 private func microphone(){
  guard mac.paired else{connection=true;return}
  if voice.listening{voice.finish()}else{Task{await voice.start()}}
 }
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
