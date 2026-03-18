import { Notification, type NotificationOptions } from "./notification.js";
export declare class SilentNotification extends Notification {
    constructor(deviceToken: string, options?: Omit<NotificationOptions, "type" | "alert" | "priority" | "contentAvailable">);
}
