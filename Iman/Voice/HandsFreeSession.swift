import Foundation
import Combine

/// Opt-in, foreground-only recognition. Never records while the Mac is answering.
@MainActor final class HandsFreeSession:ObservableObject {
 @Published private(set) var enabled=false
 @Published private(set) var status=""
 private weak var voice:VoiceInput?
 private weak var mac:MacConnection?
 private var foreground=true
 private var gate=WakePhrase()
 private var silence:Task<Void,Never>?
 private var restart:Task<Void,Never>?
 private var generation=0
 func configure(voice:VoiceInput,mac:MacConnection){self.voice=voice;self.mac=mac}
 func setEnabled(_ value:Bool){
  generation+=1;silence?.cancel();restart?.cancel();gate.reset();voice?.stop()
  enabled=value
  status=value ? "Say ‘Hi Iman’ followed by your request":"Hands-free off"
  if value{resume()}
 }
 func setForeground(_ active:Bool){foreground=active;if !active{setEnabled(false)}}
 func busyChanged(){
  if mac?.busy==true{silence?.cancel();gate.reset();voice?.stop()}
  else{resume()}
 }
 func heard(_ text:String){
  guard enabled,foreground,mac?.paired==true,mac?.busy==false else{return}
  silence?.cancel();gate.update(text)
  guard gate.pending != nil else{return}
  status="Heard you…"
  let current=generation
  silence=Task{[weak self] in
   do{try await Task.sleep(nanoseconds:1_400_000_000)}catch{return}
   guard let self=self,self.generation==current,self.enabled,self.foreground,self.mac?.busy==false,let command=self.gate.consume() else{return}
   self.status="Sending: "+command;self.voice?.stop();self.mac?.send(command)
  }
 }
 func listeningChanged(_ listening:Bool){
  guard enabled,!listening else{return}
  if let error=voice?.error,!error.isEmpty{setEnabled(false);status=error;return}
  if gate.pending==nil{resume()}
 }
 func resume(){
  guard enabled,foreground,mac?.paired==true,mac?.busy==false,voice?.listening==false,voice?.preparing==false else{return}
  restart?.cancel();let current=generation
  restart=Task{[weak self] in
   do{try await Task.sleep(nanoseconds:500_000_000)}catch{return}
   guard let self=self,self.generation==current,self.enabled,self.foreground,self.mac?.busy==false,self.mac?.paired==true else{return}
   self.gate.reset();self.status="Listening for ‘Hi Iman’…";await self.voice?.start()
   if let error=self.voice?.error,!error.isEmpty{self.setEnabled(false);self.status=error}
  }
 }
 deinit{silence?.cancel();restart?.cancel()}
}
