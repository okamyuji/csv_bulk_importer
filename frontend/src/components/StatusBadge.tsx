import { clsx } from "clsx";

export function StatusBadge({ status }: { status: string }) {
  const tone = clsx(
    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
    {
      "bg-slate-700 text-slate-200": status === "pending",
      "bg-sky-900/60 text-sky-200":
        status === "splitting" || status === "processing",
      "bg-emerald-900/60 text-emerald-200": status === "completed",
      "bg-amber-900/60 text-amber-200":
        status === "completed_with_errors" || status === "partially_failed",
      "bg-rose-900/60 text-rose-200": status === "failed",
    },
  );
  return <span className={tone}>{status}</span>;
}
