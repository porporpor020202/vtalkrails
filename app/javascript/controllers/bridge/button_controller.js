import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "button"

  connect() {
    super.connect()

    const title = this.bridgeElement.bridgeAttribute("title")
    const imageName = this.bridgeElement.bridgeAttribute("image-name")

    this.send("connect", {title, imageName}, () => {
      this.bridgeElement.click()
    })
  }

  disconnect() {
    super.disconnect()

    this.send("disconnect")
  }
}
