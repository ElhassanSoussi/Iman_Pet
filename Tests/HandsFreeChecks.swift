import Foundation
import Combine
@MainActor final class VoiceInput {
 var error="",text="",listening=false,preparing=false,finalizing=false,isFinal=false
 var active:Bool{listening || preparing || finalizing}
 var starts=0,stops=0,finishes=0
 func start() async{text="";isFinal=false;listening=true;starts+=1}
 func finish(){listening=false;finalizing=true;finishes+=1}
 func stop(){listening=false;finalizing=false;stops+=1}
 func result(_ text:String,final:Bool=true){self.text=text;isFinal=final;stop()}
}
@MainActor final class MacConnection {
 var paired=true,busy=false,sent=[String]()
 func send(_ text:String){sent.append(text);busy=true}
}
@main struct HandsFreeChecks {
 @MainActor static func pause(_ ms:UInt64)async{try? await Task.sleep(nanoseconds:ms*1_000_000)}
 @MainActor static func main() async {
  let voice=VoiceInput(),mac=MacConnection(),session=HandsFreeSession()
  session.configure(voice:voice,mac:mac);session.setEnabled(true)
  await pause(650);precondition(voice.listening && !session.sendAutomatically)
  voice.text="we should go for a walk";session.heard(voice.text)
  await pause(1900);precondition(mac.sent.isEmpty && voice.finishes==0)
  voice.text="Hi Iman explain run";session.heard(voice.text)
  await pause(1000)
  voice.text="Hi Iman explain run into";session.heard(voice.text)
  await pause(1000);precondition(voice.finishes==0)
  await pause(1000);precondition(voice.finishes==1 && voice.finalizing && mac.sent.isEmpty)
  voice.result("Hi Iman explain rain in two short sentences")
  session.captureChanged(false)
  precondition(session.review=="explain rain in two short sentences" && mac.sent.isEmpty)
  let starts=voice.starts;session.resume();await pause(650);precondition(voice.starts==starts)
  // Review remains paused until explicit dismissal; a corrected draft is sent by the view.
  session.dismissReview(resumeListening:false);mac.send("explain rain in two sentences please")
  session.busyChanged();precondition(!voice.active)
  session.heard("Hi Iman fly around");precondition(mac.sent.count==1)
  mac.busy=false;session.busyChanged();await pause(650);precondition(voice.listening)
  // Automatic send uses only the final transcript and cannot send twice.
  session.sendAutomatically=true
  voice.text="Hi Iman open Calendar";session.heard(voice.text)
  voice.result("Hi Iman open Calculator");session.captureChanged(false);session.captureChanged(false)
  precondition(mac.sent==["explain rain in two sentences please","open Calculator"])
  mac.busy=false;session.busyChanged();await pause(650)
  // Missing final result always requires review, even with automatic send enabled.
  voice.text="Hi Iman delete something";session.heard(voice.text)
  voice.result(voice.text,final:false);session.captureChanged(false)
  precondition(session.review=="delete something" && mac.sent.count==2)
  session.dismissReview();await pause(650)
  voice.text="Hi Iman run around";session.heard(voice.text);session.setForeground(false)
  voice.result("Hi Iman run around");session.captureChanged(false)
  await pause(1900);precondition(mac.sent.count==2 && !session.enabled && !voice.active)
  session.setForeground(true);await pause(650);precondition(!voice.listening)
  // Recognizer alternatives are bounded and deduplicated, never invented.
  precondition(TranscriptOptions.unique(["rain", "run", "run", "", "  rain  ","ran","train","extra"],excluding:"rain")==["run","ran","train"])
  precondition(TranscriptOptions.unique([String(repeating:"a",count:700)],excluding:"").first?.count==600)
  print("Voice review checks passed: final words, pause reset, review lock, explicit auto-send, partial fallback, busy/background cancellation, alternatives.")
 }
}
