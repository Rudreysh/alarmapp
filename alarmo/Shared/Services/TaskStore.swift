import Foundation
import Combine

@MainActor
class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var selectedTaskId: UUID? = nil
    @Published var availableTags: [Tag] = []
    
    // ... (fileURL remains same)
    
    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let domainIdentifier = Bundle.main.bundleIdentifier ?? "com.alarmo.app"
        let directoryURL = appSupport.appendingPathComponent(domainIdentifier, isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        
        return directoryURL.appendingPathComponent("tasks.json")
    }()
    
    struct TaskStorePayload: Codable {
        var tasks: [TaskItem]
        var selectedTaskId: UUID?
        var availableTags: [Tag]? // Optional for backward compatibility
    }
    
    init() {
        load()
    }
    
    var selectedTask: TaskItem? {
        tasks.first(where: { $0.id == selectedTaskId })
    }
    
    func load() {
        print("[TaskStore] Loading tasks and tags from: \(fileURL.path)")
        guard let data = try? Data(contentsOf: fileURL) else {
            print("[TaskStore] No tasks file found. Adding defaults.")
            self.tasks = defaultTasks
            self.availableTags = defaultTags
            save()
            return
        }
        
        do {
            let payload = try JSONDecoder().decode(TaskStorePayload.self, from: data)
            self.tasks = payload.tasks
            self.selectedTaskId = payload.selectedTaskId
            self.availableTags = payload.availableTags ?? defaultTags
            
            // If tasks were present but list is empty (edge case), add defaults
            if tasks.isEmpty {
                self.tasks = defaultTasks
                save()
            }
            if availableTags.isEmpty {
                 self.availableTags = defaultTags
                 save()
            }
            
            print("[TaskStore] Loaded \(tasks.count) tasks and \(availableTags.count) tags.")
        } catch {
            print("[TaskStore] Error decoding tasks (schema mismatch?): \(error)")
            // Fallback: Reset to defaults if we can't read the file
            self.tasks = defaultTasks
            self.availableTags = defaultTags
            save()
        }
    }
    
    private var defaultTags: [Tag] {
        [
            Tag(name: "Work", colorHex: "3498db"), // Blue
            Tag(name: "Personal", colorHex: "e74c3c"), // Red
            Tag(name: "Health", colorHex: "2ecc71"), // Green
            Tag(name: "Study", colorHex: "f1c40f") // Yellow
        ]
    }
    
    private var defaultTasks: [TaskItem] {
        [
            TaskItem(name: "Drink water", note: "Stay hydrated!", tags: ["Health"], focusDurationMinutes: 5, isIntervalTimer: false),
            TaskItem(name: "Focus", note: "Deep work session", tags: ["Work"], focusDurationMinutes: 25, isIntervalTimer: true),
            TaskItem(name: "Reading", note: "Read a book", tags: ["Personal"], focusDurationMinutes: 30, isIntervalTimer: false),
            TaskItem(name: "Exercise", note: "Stay fit", tags: ["Health"], focusDurationMinutes: 45, isIntervalTimer: false),
            TaskItem(name: "Pomodoro", note: "Standard technique", tags: ["Work"], focusDurationMinutes: 25, isIntervalTimer: true)
        ]
    }
    
    func save() {
        let payload = TaskStorePayload(tasks: tasks, selectedTaskId: selectedTaskId, availableTags: availableTags)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
            print("[TaskStore] Saved tasks and tags.")
        } catch {
            print("[TaskStore] Error saving tasks: \(error)")
        }
    }
    
    @discardableResult
    func addTask(name: String) -> TaskItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTask = TaskItem(name: String(trimmedName.prefix(50)))
        tasks.append(newTask)
        save()
        return newTask
    }
    
    func addTag(_ tag: Tag) {
        if !availableTags.contains(where: { $0.name.lowercased() == tag.name.lowercased() }) {
            availableTags.append(tag)
            save()
        }
    }
    
    @discardableResult
    func add(task: TaskItem) -> TaskItem {
        tasks.append(task)
        save()
        return task
    }
    
    func selectTask(_ id: UUID?) {
        selectedTaskId = id
        save()
    }
    
    func deleteTask(_ id: UUID) {
        tasks.removeAll(where: { $0.id == id })
        if selectedTaskId == id {
            selectedTaskId = nil
        }
        save()
    }
    
    func isDuplicate(name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tasks.contains(where: { $0.name.lowercased() == trimmedName && !$0.isArchived })
    }
}
