import Foundation

/// Pure, bounded wake gate; ordinary conversation never becomes a command.
struct WakePhrase {
 private(set) var pending:String?
 mutating func update(_ transcript:String){
  let text=transcript.trimmingCharacters(in:.whitespacesAndNewlines)
  guard text.count<=650,let range=text.range(of:#"^(hi|hey|hello)\s+iman\b[\s,.!?]*"#,options:[.regularExpression,.caseInsensitive]) else{pending=nil;return}
  let tail=String(text[range.upperBound...]).trimmingCharacters(in:.whitespacesAndNewlines)
  pending=tail.isEmpty ? "Hi Iman":String(tail.prefix(600))
 }
 mutating func consume()->String?{defer{pending=nil};return pending}
 mutating func reset(){pending=nil}
}
