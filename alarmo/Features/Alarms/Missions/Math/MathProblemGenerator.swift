import Foundation

class MathProblemGenerator {
    static func generateProblem(difficulty: MathDifficulty) -> MathProblem {
        var expression = ""
        var answer = 0
        
        switch difficulty {
        case .veryEasy:
            let a = Int.random(in: 0...9)
            let b = Int.random(in: 0...9)
            expression = "\(a)+\(b)"
            answer = a + b
            
        case .easy:
            let a = Int.random(in: 0...20)
            let b = Int.random(in: 0...20)
            expression = "\(a)+\(b)"
            answer = a + b
            
        case .normal:
            let a = Int.random(in: 10...99)
            let b = Int.random(in: 10...99)
            if Bool.random() {
                expression = "\(a)+\(b)"
                answer = a + b
            } else {
                let high = max(a, b)
                let low = min(a, b)
                expression = "\(high)-\(low)"
                answer = high - low
            }
            
        case .hard:
            let a = Int.random(in: 10...99)
            let b = Int.random(in: 10...99)
            let c = Int.random(in: 10...99)
            let ops = ["+", "-"].shuffled()
            
            var result = a
            expression = "\(a)"
            
            // term 2
            if ops[0] == "+" {
                result += b
                expression += "+\(b)"
            } else {
                result -= b
                expression += "-\(b)"
            }
            
            // term 3
            if ops[1] == "+" {
                result += c
                expression += "+\(c)"
            } else {
                // Ensure non-negative
                if result - c >= 0 {
                    result -= c
                    expression += "-\(c)"
                } else {
                    result += c
                    expression += "+\(c)"
                }
            }
            answer = result
            
        case .veryHard:
            // Format: (a×b)+c
            let a = Int.random(in: 10...99)
            let b = Int.random(in: 2...9)
            let c = Int.random(in: 0...99)
            expression = "(\(a)×\(b))+\(c)"
            answer = (a * b) + c
            
        case .superHard:
            // a: 10…199, b: 10…30, c: 0…999
            let a = Int.random(in: 10...199)
            let b = Int.random(in: 10...30)
            let c = Int.random(in: 0...999)
            expression = "(\(a)×\(b))+\(c)"
            answer = (a * b) + c
            
        case .expert:
            // a: 100…499, b: 10…50, c: 0…2000
            let a = Int.random(in: 100...499)
            let b = Int.random(in: 10...50)
            let c = Int.random(in: 0...2000)
            expression = "(\(a)×\(b))+\(c)"
            answer = (a * b) + c
            
        case .hellMode:
            // (a×b)+c OR (a×b)+c+d
            let a = Int.random(in: 100...999)
            let b = Int.random(in: 10...99)
            let c = Int.random(in: 0...9999)
            
            if Int.random(in: 0...100) < 30 {
                let d = Int.random(in: 0...999)
                expression = "(\(a)×\(b))+\(c)+\(d)"
                answer = (a * b) + c + d
            } else {
                expression = "(\(a)×\(b))+\(c)"
                answer = (a * b) + c
            }
        }
        
        return MathProblem(displayExpression: expression, correctAnswer: answer)
    }
    
    static func generateProblems(count: Int, difficulty: MathDifficulty) -> [MathProblem] {
        return (0..<count).map { _ in generateProblem(difficulty: difficulty) }
    }
}
