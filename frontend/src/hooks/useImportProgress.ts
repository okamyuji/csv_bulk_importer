import { useEffect, useState } from "react";
import { createConsumer, type Consumer } from "@rails/actioncable";
import { getToken } from "../lib/api";

export interface ProgressEvent {
  event: "split_started" | "chunk_completed" | "import_finalized";
  csv_import_id: number;
  total_rows?: number;
  total_chunks?: number;
  chunk_id?: number;
  chunk_index?: number;
  status?: string;
  processed_rows?: number;
  failed_rows?: number;
}

let consumer: Consumer | null = null;

function getConsumer(): Consumer {
  const token = getToken();
  if (!consumer) {
    const url = `/cable?token=${encodeURIComponent(token ?? "")}`;
    consumer = createConsumer(url);
  }
  return consumer;
}

export function useImportProgress(csvImportId: number | null) {
  const [events, setEvents] = useState<ProgressEvent[]>([]);

  useEffect(() => {
    if (csvImportId == null) return;

    const sub = getConsumer().subscriptions.create(
      { channel: "CsvImportChannel", csv_import_id: csvImportId },
      {
        received(data: ProgressEvent) {
          setEvents((prev) => [...prev, data]);
        },
      },
    );

    return () => {
      sub.unsubscribe();
    };
  }, [csvImportId]);

  return events;
}
