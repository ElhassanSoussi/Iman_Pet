import AVFoundation
import Speech
import Combine

@MainActor final class VoiceInput:ObservableObject {
 @Published var text=""
 @Published private(set) var listening=false
 @Published private(set) var preparing=false
 @Published private(set) var finalizing=false
 @Published private(set) var isFinal=false
 @Published private(set) var alternatives=[String]()
 @Published var error=""
 var active:Bool{listening || preparing || finalizing}
 private let engine=AVAudioEngine()
 private let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"en-US"))
 private var buffer:SFSpeechAudioBufferRecognitionRequest?
 private var recognition:SFSpeechRecognitionTask?
 private var timeout:Task<Void,Never>?
 private var tapped=false
 private var generation=0
 func start()async {
  guard !active else{return}
  generation+=1;let current=generation;preparing=true;error=""
  defer{if generation==current{preparing=false}}
  let speech=await withCheckedContinuation{continuation in SFSpeechRecognizer.requestAuthorization{continuation.resume(returning:$0)}}
  let microphone=await withCheckedContinuation{continuation in AVAudioSession.sharedInstance().requestRecordPermission{continuation.resume(returning:$0)}}
  guard generation==current else{return}
  guard speech == .authorized,microphone else{error="Allow microphone and speech access in Settings for Iman.";return}
  guard let recognizer=recognizer,recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else{error="Offline English speech is unavailable. Enable English Dictation in iPhone settings, or type below.";return}
  do {
   let audio=AVAudioSession.sharedInstance()
   try audio.setCategory(.record,mode:.measurement);try audio.setActive(true)
   let request=SFSpeechAudioBufferRecognitionRequest();request.requiresOnDeviceRecognition=true;request.shouldReportPartialResults=true
   request.taskHint = .dictation
   request.contextualStrings=["Iman","Hi Iman","ChatGPT","Calculator","Terminal","Notes"]
   request.addsPunctuation=true
   buffer=request;isFinal=false;alternatives=[];text=""
   let input=engine.inputNode,format=input.outputFormat(forBus:0)
   guard format.sampleRate>0,format.channelCount>0 else{throw ConnectionError.server("No microphone input available.")}
   input.installTap(onBus:0,bufferSize:1024,format:format){buffer,_ in request.append(buffer)};tapped=true
   recognition=recognizer.recognitionTask(with:request){[weak self] result,failure in
    Task{@MainActor in
     guard let self=self,self.generation==current else{return}
     if let result=result{
      self.text=String(result.bestTranscription.formattedString.prefix(600));self.isFinal=result.isFinal
      self.alternatives=TranscriptOptions.unique(result.transcriptions.map{$0.formattedString},excluding:self.text)
     }
     if result?.isFinal==true || failure != nil{self.stop();if failure != nil && self.text.isEmpty{self.error="I didn’t catch that. Try again or type."}}
    }
   }
   engine.prepare();try engine.start();listening=true
   timeout=Task{try? await Task.sleep(nanoseconds:30_000_000_000);if !Task.isCancelled{finish()}}
  }catch{self.error=error.localizedDescription;stop()}
 }
 func finish(){
  guard listening else{return}
  finalizing=true
  engine.stop();if tapped{engine.inputNode.removeTap(onBus:0);tapped=false}
  buffer?.endAudio();listening=false
  timeout?.cancel();timeout=Task{try? await Task.sleep(nanoseconds:3_000_000_000);if !Task.isCancelled{stop()}}
 }
 func stop(){
  generation+=1;preparing=false;listening=false;finalizing=false;timeout?.cancel();timeout=nil
  engine.stop();if tapped{engine.inputNode.removeTap(onBus:0);tapped=false}
  buffer?.endAudio();recognition?.cancel();recognition=nil;buffer=nil
  try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
 }
}
