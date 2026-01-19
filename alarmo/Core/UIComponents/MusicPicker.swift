import SwiftUI
import MediaPlayer

struct MusicPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: (MPMediaItem) -> Void
    
    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = false // We generally can't export cloud items easily
        picker.prompt = "Select an Alarm Sound"
        return picker
    }
    
    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let parent: MusicPicker
        
        init(_ parent: MusicPicker) {
            self.parent = parent
        }
        
        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            print("[MusicPicker] User picked \(mediaItemCollection.count) items")
            if let item = mediaItemCollection.items.first {
                parent.onPick(item)
            }
            parent.isPresented = false
        }
        
        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            print("[MusicPicker] User cancelled")
            parent.isPresented = false
        }
    }
}
