import Foundation

enum NOVASwiftTimetablePhoto {
    static func parse(_ text:String) throws -> (lessons:[NOVALessonDraft],estimated:Bool) {
        guard let start=text.firstIndex(of:"{"),let end=text.lastIndex(of:"}"),start<end,
              let data=String(text[start...end]).data(using:.utf8),let rows=try JSONDecoder().decode(NOVAJSON.self,from:data).object?["lessons"]?.array else{throw CocoaError(.fileReadCorruptFile)}
        func minutes(_ value:NOVAJSON?)->Int?{guard let value=value?.string else{return nil};let parts=value.split(separator:":");guard parts.count==2,let h=Int(parts[0]),let m=Int(parts[1]),(0...23).contains(h),(0...59).contains(m) else{return nil};return h*60+m}
        var lessons:[NOVALessonDraft]=[],estimated=false
        for row in rows.prefix(100){guard let o=row.object,let d=o["d"]?.integer,(1...6).contains(d),let name=o["n"]?.string,!name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{continue};var lesson=NOVALessonDraft(day:d+1);let h=max(1,min(12,o["h"]?.integer ?? 1));if let s=minutes(o["s"]),let e=minutes(o["e"]),e>s{lesson.start=s;lesson.end=e}else{estimated=true;lesson.start=480+(h-1)*60;lesson.end=lesson.start+60};lesson.subject=String(name.uppercased().prefix(14));lessons.append(lesson)}
        guard !lessons.isEmpty else{throw CocoaError(.fileReadCorruptFile)}
        return(lessons.sorted{$0.day==$1.day ? $0.start<$1.start:$0.day<$1.day},estimated)
    }
}
