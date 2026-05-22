import Foundation

func timeProjector(h: Int, m: Int, s: Int, from: TimeZone, to: TimeZone) -> (h: Int, m: Int, s: Int) {
    var cal = Calendar.current
    cal.timeZone = from
    
    let now = Date()
    var comps = cal.dateComponents([.year, .month, .day], from: now)
    comps.hour = h
    comps.minute = m
    comps.second = s
    
    let sourceDate = cal.date(from: comps) ?? now
    
    cal.timeZone = to
    return (
        h: cal.component(.hour, from: sourceDate),
        m: cal.component(.minute, from: sourceDate),
        s: cal.component(.second, from: sourceDate)
    )
}

let ny = TimeZone(identifier: "America/New_York")!
let london = TimeZone(identifier: "Europe/London")!

print("8 AM NY to London:")
print(timeProjector(h: 8, m: 0, s: 0, from: ny, to: london))

print("1 PM London to NY:")
print(timeProjector(h: 13, m: 0, s: 0, from: london, to: ny))
