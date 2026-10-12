import Foundation
import Combine

struct MacJob:Decodable {
 struct Result:Decodable{let text:String;let action:String?;let emotion:String?}
 let state:String
 let status:String?
 let error:String?
 let result:Result?
}

/// Sessions are memory-only. A restart or expiry asks for a new one-use Mac code.
@MainActor final class MacConnection:ObservableObject {
 @Published private(set) var paired=false
 @Published private(set) var busy=false
 @Published var status="Connect to your Mac"
 @Published var reaction="idle"
 private var session:URLSession?
 private var ticket:PairingTicket?
 private var request:Task<Void,Never>?
 private var jobID:String?
 private var wantsStop=false
 func pair(_ code:String)async {
  guard !busy else{return}
  busy=true;defer{busy=false}
  do {
   let next=try PairingTicket(code)
   session?.invalidateAndCancel();paired=false;ticket=next
   let configuration=URLSessionConfiguration.ephemeral
   configuration.timeoutIntervalForRequest=20;configuration.timeoutIntervalForResource=25
   session=URLSession(configuration:configuration,delegate:PinnedSession(ticket:next),delegateQueue:nil)
   _ = try await api("/api/pair",body:["code":next.code])
   paired=true;status="Connected 💙";reaction="happy"
  }catch{status=error.localizedDescription;reaction="concerned"}
 }
 private func api(_ path:String,body:[String:String]?=nil)async throws->Data {
  guard let session=session,let ticket=ticket,let url=URL(string:ticket.origin+path) else{throw ConnectionError.notPaired}
  var request=URLRequest(url:url)
  if let body=body {
   request.httpMethod="POST";request.setValue("application/json",forHTTPHeaderField:"Content-Type")
   request.setValue(ticket.origin,forHTTPHeaderField:"Origin");request.httpBody=try JSONEncoder().encode(body)
  }
  let (data,response)=try await session.data(for:request)
  guard data.count<=65536,let http=response as? HTTPURLResponse else{throw ConnectionError.server("Unexpected Mac response.")}
  if http.statusCode==401{paired=false}
  guard (200...299).contains(http.statusCode) else {
   let message=(try? JSONSerialization.jsonObject(with:data) as? [String:Any])?["error"] as? String
   throw ConnectionError.server(message ?? "The Mac could not complete that request.")
  }
  return data
 }
 func send(_ text:String){
  guard paired,!busy,!text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,text.count<=600 else{return}
  busy=true;wantsStop=false;reaction="thinking";status="On it ✨"
  request=Task {
   defer{busy=false;jobID=nil;request=nil}
   do {
    let data=try await api("/api/jobs",body:["text":text,"request_id":UUID().uuidString.lowercased()])
    guard let json=try JSONSerialization.jsonObject(with:data) as? [String:String],let id=json["id"] else{throw ConnectionError.server("No request ID from Mac.")}
    jobID=id
    if wantsStop{_ = try? await api("/api/jobs/"+id+"/cancel",body:[:]);throw CancellationError()}
    for _ in 0..<190 {
     try Task.checkCancellation()
     let job=try JSONDecoder().decode(MacJob.self,from:try await api("/api/jobs/"+id))
     if job.state=="complete" {
      reaction=job.result?.emotion ?? "happy"
      let text=job.result?.text ?? "Done 💙"
      status=text.count<=100 ? text:"Your answer is on the Mac 💙"
      return
     }
     if job.state != "running"{throw ConnectionError.server(job.error ?? "Request stopped.")}
     status=String((job.status ?? "Working on your Mac…").prefix(100))
     try await Task.sleep(nanoseconds:1_000_000_000)
    }
    throw ConnectionError.server("The Mac is taking too long. Check its connection.")
   }catch is CancellationError{status="Stop requested";reaction="idle"}
   catch{status=error.localizedDescription;reaction="concerned"}
   if let id=jobID{_ = try? await api("/api/jobs/"+id+"/cancel",body:[:])}
  }
 }
 func stop(){
  wantsStop=true;status="Stopping…"
  let active=jobID
  if active != nil{request?.cancel()}
  if let id=active{Task{_ = try? await api("/api/jobs/"+id+"/cancel",body:[:])}}
 }
 func disconnect()async {
  guard !busy else{return}
  _ = try? await api("/api/disconnect",body:[:])
  session?.invalidateAndCancel();session=nil;ticket=nil;paired=false;status="Disconnected";reaction="idle"
 }
}
