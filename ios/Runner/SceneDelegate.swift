import Flutter
import UIKit
import FirebaseCore
import FirebaseAuth

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    for urlContext in URLContexts {
      if Auth.auth().canHandle(urlContext.url) {
        return
      }
    }

    super.scene(scene, openURLContexts: URLContexts)
  }
}
