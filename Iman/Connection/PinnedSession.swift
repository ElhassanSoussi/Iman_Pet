import Foundation
import Security
import CryptoKit

/// Trust is scoped to the leaf certificate scanned from the user's Mac, never global.
final class PinnedSession:NSObject,URLSessionDelegate,URLSessionTaskDelegate {
 let ticket:PairingTicket
 init(ticket:PairingTicket){self.ticket=ticket}
 func urlSession(_ session:URLSession,didReceive challenge:URLAuthenticationChallenge,completionHandler:@escaping(URLSession.AuthChallengeDisposition,URLCredential?)->Void){
  guard challenge.protectionSpace.authenticationMethod==NSURLAuthenticationMethodServerTrust,
   challenge.protectionSpace.host==ticket.host,challenge.protectionSpace.port==ticket.port,
   let trust=challenge.protectionSpace.serverTrust,let chain=SecTrustCopyCertificateChain(trust) as? [SecCertificate],let certificate=chain.first else{completionHandler(.cancelAuthenticationChallenge,nil);return}
  let bytes=SecCertificateCopyData(certificate) as Data
  let hash=SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined()
  guard hash==ticket.pin else{completionHandler(.cancelAuthenticationChallenge,nil);return}
  SecTrustSetPolicies(trust,SecPolicyCreateSSL(true,ticket.host as CFString))
  SecTrustSetAnchorCertificates(trust,[certificate] as CFArray)
  SecTrustSetAnchorCertificatesOnly(trust,true)
  guard SecTrustEvaluateWithError(trust,nil) else{completionHandler(.cancelAuthenticationChallenge,nil);return}
  completionHandler(.useCredential,URLCredential(trust:trust))
 }
 func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
}
