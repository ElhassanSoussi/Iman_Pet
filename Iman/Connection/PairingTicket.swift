import Foundation

struct PairingTicket:Codable,Equatable {
 let host:String
 let port:Int
 let pin:String
 let code:String
 var origin:String{"https://\(host):\(port)"}
 init(_ raw:String)throws {
  guard let url=URLComponents(string:raw.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme=="iman",url.host=="pair",url.user==nil,url.fragment==nil else{throw ConnectionError.invalidCode}
  let items=url.queryItems ?? []
  guard items.count==4,Set(items.map(\.name))==Set(["host","port","pin","code"]) else{throw ConnectionError.invalidCode}
  let fields=Dictionary(uniqueKeysWithValues:items.map{($0.name,$0.value ?? "")})
  let host=fields["host"] ?? "",parts=host.split(separator:".",omittingEmptySubsequences:false)
  let bytes=parts.compactMap{UInt8($0)}
  guard bytes.count==4,parts.count==4,zip(parts,bytes).allSatisfy({String($0.1)==String($0.0)}),
   bytes[0]==10 || (bytes[0]==172 && (16...31).contains(bytes[1])) || (bytes[0]==192 && bytes[1]==168),
   let port=Int(fields["port"] ?? ""),(1...65535).contains(port),
   let pin=fields["pin"],pin.count==64,pin.allSatisfy({"0123456789abcdef".contains($0)}),
   let code=fields["code"],code.count==43,code.allSatisfy({$0.isASCII && ($0.isLetter || $0.isNumber || $0=="-" || $0=="_")}) else{throw ConnectionError.invalidCode}
  self.host=host;self.port=port;self.pin=pin;self.code=code
 }
}
enum ConnectionError:LocalizedError {
 case invalidCode,server(String),notPaired
 var errorDescription:String? {
  switch self {
  case .invalidCode:return "Scan a new code from Iman’s Connect iPhone window on your Mac."
  case .server(let message):return message
  case .notPaired:return "Connect to your Mac first."
  }
 }
}
