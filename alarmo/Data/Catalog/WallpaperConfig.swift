import Foundation

/// Static configuration for bundled wallpapers.
/// This avoids the need for runtime directory scanning, which can be fragile with Xcode folder references.
enum WallpaperConfig {
    
    struct CategoryDefinition {
        let id: String
        let title: String
        let imageNames: [String]
    }
    
    // DEFINE YOUR CATEGORIES AND IMAGES HERE
    static let categories: [CategoryDefinition] = [
        CategoryDefinition(
            id: "nature",
            title: "Nature",
            imageNames: [
                "pexels-egos68-1906658.jpg",
                "pexels-rpnickson-2486168.jpg",
                "pexels-alessio-cesario-975080-1906794.jpg",
                "pexels-philippedonn-1257860.jpg"
            ]
        ),
        CategoryDefinition(
            id: "abstract",
            title: "Abstract",
            imageNames: [
                // Add your abstract image filenames here if you have them
            ]
        )
    ]
}
