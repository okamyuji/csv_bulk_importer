declare module "@rails/actioncable" {
  export interface Subscription {
    unsubscribe(): void;
    perform(action: string, data?: unknown): void;
  }

  export interface ChannelParams {
    channel: string;
    [key: string]: unknown;
  }

  export interface SubscriptionHandlers<T = unknown> {
    connected?(): void;
    disconnected?(): void;
    received?(data: T): void;
    rejected?(): void;
  }

  export interface Subscriptions {
    create<T = unknown>(
      params: ChannelParams,
      handlers?: SubscriptionHandlers<T>,
    ): Subscription;
  }

  export interface Consumer {
    subscriptions: Subscriptions;
    disconnect(): void;
  }

  export function createConsumer(url?: string): Consumer;
}
