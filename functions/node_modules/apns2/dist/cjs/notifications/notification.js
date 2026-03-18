"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Notification = exports.Priority = exports.PushType = void 0;
const priority_js_1 = require("./constants/priority.js");
Object.defineProperty(exports, "Priority", { enumerable: true, get: function () { return priority_js_1.Priority; } });
const push_type_js_1 = require("./constants/push-type.js");
Object.defineProperty(exports, "PushType", { enumerable: true, get: function () { return push_type_js_1.PushType; } });
class Notification {
    deviceToken;
    options;
    constructor(deviceToken, options) {
        this.deviceToken = deviceToken;
        this.options = options ?? {};
    }
    get pushType() {
        return this.options.type ?? push_type_js_1.PushType.alert;
    }
    get priority() {
        return this.options.priority ?? priority_js_1.Priority.immediate;
    }
    buildApnsOptions() {
        const result = {
            aps: this.options.aps ?? {},
        };
        // Check for alert
        if (this.options.alert) {
            result.aps.alert = this.options.alert;
        }
        // Check for "silent" notification
        if (typeof this.options.contentAvailable === "boolean") {
            result.aps["content-available"] = this.options.contentAvailable ? 1 : 0;
        }
        // Check for sound
        if (typeof this.options.sound === "string" || typeof this.options.sound === "object") {
            result.aps.sound = this.options.sound;
        }
        // Check for category
        if (typeof this.options.category === "string") {
            result.aps.category = this.options.category;
        }
        // Check for badge
        if (typeof this.options.badge === "number") {
            result.aps.badge = this.options.badge;
        }
        // Check for threadId
        if (typeof this.options.threadId === "string") {
            result.aps["thread-id"] = this.options.threadId;
        }
        // Add optional message data
        for (const key in this.options.data) {
            result[key] = this.options.data[key];
        }
        // Check for mutable content
        if (typeof this.options.mutableContent === "boolean") {
            result.aps["mutable-content"] = this.options.mutableContent ? 1 : 0;
        }
        return result;
    }
}
exports.Notification = Notification;
