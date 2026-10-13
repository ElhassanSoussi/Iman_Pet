import Foundation

/// Alternatives come from the recognizer, never from guessed substitutions.
enum TranscriptOptions {
 static func unique(_ candidates:[String],excluding best:String)->[String]{
  var seen=Set([best.trimmingCharacters(in:.whitespacesAndNewlines)])
  return candidates.compactMap { candidate in
   let value=String(candidate.trimmingCharacters(in:.whitespacesAndNewlines).prefix(600))
   guard !value.isEmpty,seen.insert(value).inserted else{return nil}
   return value
  }.prefix(3).map{$0}
 }
}
