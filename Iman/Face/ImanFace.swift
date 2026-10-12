import SwiftUI

struct ImanFace:View {
 let emotion:String
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var blink=false
 @State private var look:CGFloat=0
 private var kiss:Bool{emotion=="kiss"}
 var body:some View {
  GeometryReader { proxy in
   let scale=min(proxy.size.width/340,proxy.size.height/292)
   ZStack {
    Image("iman-body").resizable().scaledToFit().frame(width:340,height:292)
    eye(right:false).position(x:153,y:151)
    eye(right:true).scaleEffect(0.91).position(x:220,y:143)
    if kiss {
     Text("ε").font(.system(size:25,weight:.bold,design:.rounded)).foregroundStyle(.indigo).position(x:184,y:196)
     Image(systemName:"heart.fill").foregroundStyle(.pink).font(.system(size:28)).position(x:265,y:98)
    } else {
     Smile().stroke(Color(red:0.03,green:0.13,blue:0.3),style:StrokeStyle(lineWidth:3,lineCap:.round)).frame(width:emotion=="happy" ? 25:18,height:12).position(x:184,y:194)
    }
   }.frame(width:340,height:292).scaleEffect(scale).position(x:proxy.size.width/2,y:proxy.size.height/2)
  }.accessibilityElement(children:.ignore).accessibilityLabel("Iman, \(emotion)")
   .task {
    while !Task.isCancelled {
     do{try await Task.sleep(nanoseconds:3_600_000_000)}catch{return}
     withAnimation(.easeOut(duration:0.1)){blink=true}
     do{try await Task.sleep(nanoseconds:170_000_000)}catch{return}
     withAnimation(.easeOut(duration:0.14)){blink=false;if !reduceMotion{look=look==0 ? 2:0}}
    }
   }
 }
 private func eye(right:Bool)->some View {
  ZStack {
   Ellipse().fill(LinearGradient(colors:[.indigo,.cyan],startPoint:.top,endPoint:.bottom))
   Ellipse().fill(Color(red:0.01,green:0.025,blue:0.10)).padding(5).offset(x:look,y:emotion=="thinking" ? -4:0)
   Ellipse().fill(.white).frame(width:11,height:14).offset(x:-8+look,y:-15)
  }.frame(width:40,height:54).overlay(Ellipse().stroke(.cyan.opacity(0.7),lineWidth:2))
   .scaleEffect(x:1,y:blink || kiss || (right && emotion=="happy") ? 0.12:1)
   .animation(.easeInOut(duration:0.18),value:emotion)
 }
}
private struct Smile:Shape {
 func path(in rect:CGRect)->Path{Path{p in p.move(to:CGPoint(x:0,y:0));p.addQuadCurve(to:CGPoint(x:rect.maxX,y:0),control:CGPoint(x:rect.midX,y:rect.maxY))}}
}
