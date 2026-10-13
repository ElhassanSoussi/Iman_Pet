import Foundation
import Combine

/// Foreground wake capture pauses for review by default. Automatic sending is opt-in.
@MainActor final class HandsFreeSession:ObservableObject {
 @Published private(set) var enabled=false
 @Published private(set) var status=""
 @Published private(set) var review:String?
 @Published var sendAutomatically=false
 private weak var voice:VoiceInput?
 private weak var mac:MacConnection?
 private var foreground=true
 private var capturing=false
 private var gate=WakePhrase()
 private var silence:Task<Void,Never>?
 private var restart:Task<Void,Never>?
 private var generation=0
 func configure(voice:VoiceInput,mac:MacConnection){self.voice=voice;self.mac=mac}
 func setEnabled(_ value:Bool){
  generation+=1;silence?.cancel();restart?.cancel();gate.reset();capturing=false;voice?.stop()
  enabled=value;review=nil
  status=value ? "Say ‘Hi Iman’ followed by your request":"Hands-free off"
  if value{resume()}
 }
 func setForeground(_ active:Bool){foreground=active;if !active{setEnabled(false)}}
 func busyChanged(){
  if mac?.busy==true{silence?.cancel();restart?.cancel();gate.reset();capturing=false;voice?.stop()}
  else{resume()}
 }
 func heard(_ text:String){
  guard enabled,capturing,foreground,review==nil,voice?.listening==true,mac?.paired==true,mac?.busy==false else{return}
  silence?.cancel();gate.update(text)
  guard gate.pending != nil else{return}
  status="Listening to your request…"
  let current=generation
  silence=Task{[weak self] in
   do{try await Task.sleep(nanoseconds:1_800_000_000)}catch{return}
   guard let self=self,self.generation==current,self.enabled,self.foreground,self.mac?.busy==false else{return}
   // End audio, but keep recognition alive for the final words. Never send a partial here.
   self.status="Finishing your words…";self.voice?.finish()
  }
 }
 func captureChanged(_ active:Bool){
  guard enabled,!active,capturing else{return}
  capturing=false;silence?.cancel()
  guard foreground,mac?.paired==true,mac?.busy==false else{return}
  if let error=voice?.error,!error.isEmpty{setEnabled(false);status=error;return}
  gate.update(voice?.text ?? "")
  guard let command=gate.consume() else{resume();return}
  if sendAutomatically,voice?.isFinal==true {
   status="Sending: "+command;mac?.send(command)
  }else{
   review=command;status="Check what I heard. Edit it, then tap Send to Mac."
  }
 }
 func dismissReview(resumeListening:Bool=true){
  review=nil;gate.reset()
  if resumeListening{resume()}
 }
 func resume(){
  guard enabled,foreground,review==nil,mac?.paired==true,mac?.busy==false,voice?.active==false,!capturing else{return}
  restart?.cancel();let current=generation
  restart=Task{[weak self] in
   do{try await Task.sleep(nanoseconds:500_000_000)}catch{return}
   guard let self=self,self.generation==current,self.enabled,self.foreground,self.review==nil,self.mac?.busy==false,self.mac?.paired==true,self.voice?.active==false else{return}
   self.gate.reset();self.capturing=true;self.status="Listening for ‘Hi Iman’…";await self.voice?.start()
   if let error=self.voice?.error,!error.isEmpty{self.setEnabled(false);self.status=error}
  }
 }
 deinit{silence?.cancel();restart?.cancel()}
}
