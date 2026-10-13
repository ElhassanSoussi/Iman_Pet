import SwiftUI

/// The draft remains editable after capture stops; recognizer alternatives require a tap.
struct TranscriptReview:View {
 @Binding var draft:String
 let capturing:Bool
 let finalizing:Bool
 let canSend:Bool
 let alternatives:[String]
 let send:()->Void
 let retry:()->Void
 let discard:()->Void
 var body:some View {
  VStack(alignment:.leading,spacing:10){
   HStack {
    Label(finalizing ? "Finishing your words…":capturing ? "I’m listening…":"Check what I heard",systemImage:"text.bubble")
     .font(.subheadline.bold())
    Spacer()
    Button(action:discard){Image(systemName:"xmark")}.accessibilityLabel("Discard message").disabled(capturing)
   }
   TextField("Say or type your request…",text:$draft,axis:.vertical)
    .lineLimit(2...5).textFieldStyle(.plain).accessibilityLabel("Message to send to your Mac")
    .disabled(capturing).autocorrectionDisabled()
    .onChange(of:draft){value in if value.count>600{draft=String(value.prefix(600))}}
   if !capturing {
    Text("Tap the words to correct them. Only this text will be sent.").font(.caption).foregroundStyle(.secondary)
    if !alternatives.isEmpty {
     Menu("Other words I heard"){
      ForEach(alternatives,id:\.self){value in Button(value){draft=value}}
     }.font(.caption)
    }
    HStack {
     Button("Record again",systemImage:"mic",action:retry)
     Spacer()
     Button("Send to Mac",systemImage:"arrow.up",action:send).buttonStyle(.borderedProminent)
      .disabled(!canSend || draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
    }.font(.subheadline)
   }
  }.padding(16).background(.white.opacity(0.09),in:RoundedRectangle(cornerRadius:22))
 }
}
