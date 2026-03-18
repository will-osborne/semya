import { Notification, Priority, PushType } from "./notification.js";
export class SilentNotification extends Notification {
    constructor(deviceToken, options = {}) {
        super(deviceToken, {
            contentAvailable: true,
            type: PushType.background,
            priority: Priority.throttled,
            ...options,
        });
    }
}
