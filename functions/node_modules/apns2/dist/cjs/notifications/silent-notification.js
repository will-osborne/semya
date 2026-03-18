"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SilentNotification = void 0;
const notification_js_1 = require("./notification.js");
class SilentNotification extends notification_js_1.Notification {
    constructor(deviceToken, options = {}) {
        super(deviceToken, {
            contentAvailable: true,
            type: notification_js_1.PushType.background,
            priority: notification_js_1.Priority.throttled,
            ...options,
        });
    }
}
exports.SilentNotification = SilentNotification;
