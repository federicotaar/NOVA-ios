import SwiftUI

struct NOVASwiftRelease:Identifiable,Equatable {
    let version:String
    let page:URL
    var id:String{version}
    static func parts(_ value:String)->[Int]?{let raw=value.hasPrefix("v") ? String(value.dropFirst()):value;let pieces=raw.split(separator:".");guard pieces.count==4 else{return nil};let nums=pieces.compactMap{Int($0)};return nums.count==4 ? nums:nil}
    static func newer(_ a:String,than b:String)->Bool{guard let aa=parts(a),let bb=parts(b) else{return false};return bb.lexicographicallyPrecedes(aa)}
    static func select(_ rows:[[String:Any]],current:String)->Self?{
        rows.compactMap{row->Self? in
            guard row["draft"] as? Bool != true,let tag=row["tag_name"] as? String,parts(tag) != nil,newer(tag,than:current),let link=row["html_url"] as? String,let page=URL(string:link),page.scheme=="https",page.host=="github.com",page.path.hasPrefix("/federicotaranudev/NOVA-ios/releases/tag/"),let assets=row["assets"] as? [[String:Any]],assets.contains(where:{asset in guard let name=asset["name"] as? String,let source=asset["browser_download_url"] as? String,let url=URL(string:source) else{return false};return name=="NOVA-\((tag.hasPrefix("v") ? String(tag.dropFirst()):tag)).ipa" && url.scheme=="https" && url.host=="github.com" && url.path.hasPrefix("/federicotaranudev/NOVA-ios/releases/download/") && (asset["size"] as? Int ?? 0)>0}) else{return nil}
            return Self(version:tag.hasPrefix("v") ? (tag.hasPrefix("v") ? String(tag.dropFirst()):tag):tag,page:page)
        }.max{newer($1.version,than:$0.version)}
    }
}
@MainActor final class NOVASwiftReleaseCheck:ObservableObject {
    @Published var newer:NOVASwiftRelease?
    private var checked=Date.distantPast
    private var loading=false
    func check() async {
        guard !loading,Date().timeIntervalSince(checked)>3600 else{return};loading=true;checked=Date();defer{loading=false}
        guard let current=Bundle.main.object(forInfoDictionaryKey:"NOVAReleaseLabel") as? String,NOVASwiftRelease.parts(current) != nil else{return}
        do{var request=URLRequest(url:URL(string:"https://api.github.com/repos/federicotaranudev/NOVA-ios/releases?per_page=30")!);request.timeoutInterval=12;request.setValue("application/vnd.github+json",forHTTPHeaderField:"Accept");let(data,response)=try await URLSession.shared.data(for:request);guard (response as? HTTPURLResponse)?.statusCode==200,let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]] else{return};newer=NOVASwiftRelease.select(rows,current:current)}catch{}
    }
}
struct NOVASwiftReleaseBanner:View {
    let release:NOVASwiftRelease
    var body:some View{VStack(alignment:.leading,spacing:6){Text("Versione non aggiornata").font(.headline);Text("Disponibile NOVA \(release.version). Questa versione continua a funzionare.").font(.footnote);Link("Apri la nuova release",destination:release.page).font(.callout.bold());Text("L'aggiornamento richiede ancora il tuo metodo di installazione. Non eliminare l'app.").font(.caption).foregroundStyle(.secondary)}.padding().frame(maxWidth:.infinity,alignment:.leading).background(.regularMaterial,in:RoundedRectangle(cornerRadius:18)).padding(.horizontal).accessibilityIdentifier("novaReleaseNotice")}
}
